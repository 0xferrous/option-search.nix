{
  description = "Example: build the AgentSpace option search site";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-options-search.url = "github:nixbld/nix-options-search";
    agentspace = {
      url = "github:shazow/agentspace";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, nix-options-search, agentspace, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      mkModuleDocs = nix-options-search.lib.mkModuleDocs { inherit pkgs; };
      mkOptionSearchSite = nix-options-search.lib.mkOptionSearchSite { inherit pkgs; };
      moduleDocs = mkModuleDocs {
        modules = [
          agentspace.inputs.microvm.nixosModules.microvm
          agentspace.inputs.home-manager.nixosModules.home-manager
          (import "${agentspace.outPath}/sandbox-qemu.nix")
        ];
        class = "nixos";
        title = "AgentSpace Sandbox";
        subtitle = "Configuration options";
        variablelistId = "agentspace-options";
        optionIdPrefix = "opt-";
        filterOption = path: _:
          builtins.length path > 0 && builtins.head path == "agentspace";
      };
    in
    {
      packages.${system}.default = mkOptionSearchSite {
        moduleDocs = moduleDocs;
        releaseName = "agentspace";
        siteTitle = "AgentSpace Option Search";
        releaseSwitchTitle = "AgentSpace Release";
        config = {
          baseURL = "https://nixbld.github.io/nix-options-search/";
          params.footer_copyright_line = "Made with ❤️ by nixbld";
        };
      };
    };
}
