# nix-options-search

Reusable Nix building blocks for:

- `lib.mkModuleDocs`
- `lib.mkOptionSearchSite`
- `lib.mkNamespaceFilter`
- examples under `./examples`

## Usage

```nix
{
  inputs.nix-options-search.url = "github:nixbld/nix-options-search";

  outputs = { nixpkgs, nix-options-search, ... }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    mkModuleDocs = nix-options-search.lib.mkModuleDocs { inherit pkgs; };
    mkOptionSearchSite = nix-options-search.lib.mkOptionSearchSite { inherit pkgs; };
    mkNamespaceFilter = nix-options-search.lib.mkNamespaceFilter;
    docs = mkModuleDocs {
      modules = [ ./module.nix ];
      class = "nixos";
      filterOption = mkNamespaceFilter {
        includeNamespaces = [ "myNamespace" ];
      };
    };
  in {
    packages.x86_64-linux.site = mkOptionSearchSite {
      moduleDocs = docs;
      releaseName = "my-project";
    };
  };
}
```
