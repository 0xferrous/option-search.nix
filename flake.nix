{
  description = "Public Nix building blocks for module option docs and option search sites";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      lib = {
        mkModuleDocs = import ./lib/mkModuleDocs.nix;
        mkOptionSearchSite = import ./lib/mkOptionSearchSite.nix;
        mkNamespaceFilter = import ./lib/mkNamespaceFilter.nix { inherit pkgs; };
      };

      formatter.x86_64-linux = pkgs.nixfmt;
    };
}
