# option-search.nix

Reusable Nix building blocks for:

- `lib.mkModuleDocs`
- `lib.mkOptionSearchSite`
- `lib.mkNamespaceFilter`
- examples under `./examples`

## Usage

```nix
{
  inputs.option-search.url = "github:0xferrous/option-search.nix";

  outputs = { nixpkgs, option-search, ... }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    mkModuleDocs = option-search.lib.mkModuleDocs { inherit pkgs; };
    mkOptionSearchSite = option-search.lib.mkOptionSearchSite { inherit pkgs; };
    mkNamespaceFilter = option-search.lib.mkNamespaceFilter;
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
