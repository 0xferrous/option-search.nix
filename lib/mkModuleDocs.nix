{ pkgs, lib ? pkgs.lib }:
{
  modules,
  class ? "nixos",
  revision ? "local",
  title ? "Options",
  subtitle ? "Configuration options",
  includeModuleSystemOptions ? false,
  filterOption ? (path: node: true),
  optionIdPrefix ? "opt-",
  variablelistId ? "options",
  manpageUrls ? pkgs.writeText "manpage-urls.json" "{}",
  transformOptions ? (opt: opt),
  specialArgs ? { },
  system ? pkgs.stdenv.hostPlatform.system,
}:
let
  scrubDerivations =
    prefixPath: attrs:
    let
      scrubDerivation =
        name: value:
        let
          pkgAttrName = prefixPath + "." + name;
        in
        if lib.isAttrs value then
          scrubDerivations pkgAttrName value
          // lib.optionalAttrs (lib.isDerivation value) {
            outPath = "\${${pkgAttrName}}";
          }
        else
          value;
    in
    lib.mapAttrs scrubDerivation attrs;

  scrubbedPkgs = scrubDerivations "pkgs" pkgs;

  eval =
    if class == "nixos" then
      import (pkgs.path + "/nixos/lib/eval-config.nix") {
        inherit lib pkgs system modules;
        specialArgs = specialArgs // {
          pkgs = scrubbedPkgs;
          pkgs_i686 = { };
        };
      }
    else
      lib.evalModules {
        inherit modules class;
        specialArgs = specialArgs // {
          pkgs = scrubbedPkgs;
          pkgs_i686 = { };
        };
      };

  allOptions =
    if includeModuleSystemOptions
    then eval.options
    else builtins.removeAttrs eval.options [ "_module" ];

  isOptionLeaf = value:
    lib.isAttrs value
    && (
      value ? type
      || value ? declarations
      || value ? description
      || value ? default
      || value ? example
      || value ? readOnly
      || value ? loc
    );

  filterOptionNode =
    path: value:
    if filterOption path value then
      if lib.isAttrs value && !isOptionLeaf value then
        let
          children = lib.filterAttrs (name: child: (filterOptionNode (path ++ [ name ]) child) != null) value;
        in
        if children == { } then null else children
      else
        value
    else
      null;

  options = lib.filterAttrs (_: value: value != null) (lib.mapAttrs (name: value: filterOptionNode [ name ] value) allOptions);

  optionsDocs = pkgs.buildPackages.nixosOptionsDoc {
    inherit options revision variablelistId optionIdPrefix;
    transformOptions = opt: transformOptions opt;
  };

  optionsMarkdown = pkgs.writeText "options.md" ''
    # ${title} {#ch-options}

    ## ${subtitle}

    ```{=include=} options
    id-prefix: ${optionIdPrefix}
    list-id: ${variablelistId}
    source: ${optionsDocs.optionsJSON}/share/doc/nixos/options.json
    ```
  '';
in
{
  inherit optionsDocs optionsMarkdown;
  optionsJSON = optionsDocs.optionsJSON;

  html = pkgs.runCommand "module-options-html"
    {
      nativeBuildInputs = [ pkgs.nixos-render-docs ];
    }
    ''
      mkdir -p $out
      nixos-render-docs manual html \
        --manpage-urls ${manpageUrls} \
        --revision ${revision} \
        ${optionsMarkdown} \
        $out/index.xhtml
    '';
}
