{
  description = "Public Nix building blocks for module option docs and option search sites";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-25_11.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager-25_11.url = "github:nix-community/home-manager/release-25.11";
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ethereumNix = {
      url = "github:nix-community/ethereum.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agentspace = {
      url = "github:shazow/agentspace";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-25_11, home-manager, home-manager-25_11, impermanence, ethereumNix, agentspace, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      pkgs25 = nixpkgs-25_11.legacyPackages.${system};

      mkModuleDocs = import ./lib/mkModuleDocs.nix;
      mkOptionSearchSite = import ./lib/mkOptionSearchSite.nix;
      mkNamespaceFilter = import ./lib/mkNamespaceFilter.nix { inherit pkgs; };
      mkSvelteFrontend = import ./lib/mkSvelteFrontend.nix;
      mkOptionsData = import ./lib/mkOptionsData.nix;
      mkMergeOptionsData = import ./lib/mkMergeOptionsData.nix;

      nixosModulesUnstable = import (pkgs.path + "/nixos/modules/module-list.nix");
      nixosModules25 = import (pkgs25.path + "/nixos/modules/module-list.nix");

      docsNixosUnstable = (mkModuleDocs { inherit pkgs; }) {
        modules = nixosModulesUnstable;
        class = "nixos";
      };

      docsNixos25 = (mkModuleDocs { pkgs = pkgs25; }) {
        modules = nixosModules25;
        class = "nixos";
      };

      homeManagerOptionsUnstable = "${home-manager.packages.${system}.docs-json}/share/doc/home-manager/options.json";
      homeManagerOptions25 = "${home-manager-25_11.packages.${system}.docs-json}/share/doc/home-manager/options.json";

      docsImpermanenceUnstable = (mkModuleDocs { inherit pkgs; }) {
        modules = [ impermanence.nixosModules.impermanence ];
        class = "nixos";
        # Impermanence reuses the NixOS module system, so filter to its own option tree.
        filterOption = mkNamespaceFilter {
          includeNamespaces = [
            [ "environment" "persistence" ]
            [ "home" "persistence" ]
          ];
        };
      };

      docsEthereumNixUnstable = (mkModuleDocs { inherit pkgs; }) {
        modules = [ ethereumNix.nixosModules.default ];
        class = "nixos";
        # ethereum.nix ships many NixOS modules; keep only the ethereum.* subtree.
        filterOption = mkNamespaceFilter {
          includeNamespaces = [ [ "services" "ethereum" ] ];
        };
      };

      docsAgentSpaceUnstable = (mkModuleDocs { inherit pkgs; }) {
        modules = [
          agentspace.inputs.microvm.nixosModules.microvm
          agentspace.inputs.home-manager.nixosModules.home-manager
          (import "${agentspace.outPath}/sandbox-qemu.nix")
        ];
        class = "nixos";
        filterOption = path: _:
          builtins.length path > 0 && builtins.head path == "agentspace";
      };

      dataNixosUnstable = (mkOptionsData { inherit pkgs; }) {
        moduleDocs = docsNixosUnstable;
        releaseName = "unstable";
        sourceName = "NixOS";
      };

      dataNixos25 = (mkOptionsData { inherit pkgs; }) {
        moduleDocs = docsNixos25;
        releaseName = "25.11";
        sourceName = "NixOS";
      };

      dataHomeManagerUnstable = (mkOptionsData { inherit pkgs; }) {
        optionsJSONFile = homeManagerOptionsUnstable;
        releaseName = "unstable";
        sourceName = "Home Manager";
      };

      dataHomeManager25 = (mkOptionsData { inherit pkgs; }) {
        optionsJSONFile = homeManagerOptions25;
        releaseName = "25.11";
        sourceName = "Home Manager";
      };

      dataImpermanenceUnstable = (mkOptionsData { inherit pkgs; }) {
        moduleDocs = docsImpermanenceUnstable;
        releaseName = "unstable";
        sourceName = "Impermanence";
      };

      dataEthereumNixUnstable = (mkOptionsData { inherit pkgs; }) {
        moduleDocs = docsEthereumNixUnstable;
        releaseName = "unstable";
        sourceName = "ethereum.nix";
      };

      dataAgentSpaceUnstable = (mkOptionsData { inherit pkgs; }) {
        moduleDocs = docsAgentSpaceUnstable;
        releaseName = "unstable";
        sourceName = "AgentSpace";
      };


      svelteFrontend = (mkSvelteFrontend { inherit pkgs; }) {
        npmDepsHash = "sha256-MiK7O2dV35Ro1shjtrcnRinVS/31yKGTl5Jlfg+Po+M=";
        basePath = "/";
        optionsDatasets = [ ];
      };

      svelteFrontendWithData = (mkSvelteFrontend { inherit pkgs; }) {
        npmDepsHash = "sha256-MiK7O2dV35Ro1shjtrcnRinVS/31yKGTl5Jlfg+Po+M=";
        basePath = "/";
        optionsDatasets = [
          { source = "NixOS"; version = "unstable"; path = "${dataNixosUnstable}/options-unstable.json"; }
          { source = "NixOS"; version = "25.11"; path = "${dataNixos25}/options-25.11.json"; }
          { source = "Home Manager"; version = "unstable"; path = "${dataHomeManagerUnstable}/options-unstable.json"; }
          { source = "Home Manager"; version = "25.11"; path = "${dataHomeManager25}/options-25.11.json"; }
          { source = "Impermanence"; version = "unstable"; path = "${dataImpermanenceUnstable}/options-unstable.json"; }
          { source = "ethereum.nix"; version = "unstable"; path = "${dataEthereumNixUnstable}/options-unstable.json"; }
          { source = "AgentSpace"; version = "unstable"; path = "${dataAgentSpaceUnstable}/options-unstable.json"; }
        ];
      };

      svelteFrontendWithDataPages = (mkSvelteFrontend { inherit pkgs; }) {
        npmDepsHash = "sha256-MiK7O2dV35Ro1shjtrcnRinVS/31yKGTl5Jlfg+Po+M=";
        basePath = "/nix-options-search/";
        optionsDatasets = [
          { source = "NixOS"; version = "unstable"; path = "${dataNixosUnstable}/options-unstable.json"; }
          { source = "NixOS"; version = "25.11"; path = "${dataNixos25}/options-25.11.json"; }
          { source = "Home Manager"; version = "unstable"; path = "${dataHomeManagerUnstable}/options-unstable.json"; }
          { source = "Home Manager"; version = "25.11"; path = "${dataHomeManager25}/options-25.11.json"; }
          { source = "Impermanence"; version = "unstable"; path = "${dataImpermanenceUnstable}/options-unstable.json"; }
          { source = "ethereum.nix"; version = "unstable"; path = "${dataEthereumNixUnstable}/options-unstable.json"; }
          { source = "AgentSpace"; version = "unstable"; path = "${dataAgentSpaceUnstable}/options-unstable.json"; }
        ];
      };

      serveSvelteFrontend = pkgs.writeShellApplication {
        name = "serve-svelte-frontend";
        runtimeInputs = [ pkgs.static-web-server ];
        text = ''
          exec static-web-server --root ${svelteFrontendWithData} --port 4445
        '';
      };
    in
    {
      lib = {
        mkModuleDocs = mkModuleDocs;
        mkOptionSearchSite = mkOptionSearchSite;
        mkNamespaceFilter = mkNamespaceFilter;
        mkSvelteFrontend = mkSvelteFrontend;
        mkOptionsData = mkOptionsData;
        mkMergeOptionsData = mkMergeOptionsData;
      };

      packages.${system} = {
        svelte-frontend = svelteFrontend;
        svelte-frontend-with-data = svelteFrontendWithData;
        svelte-frontend-with-data-pages = svelteFrontendWithDataPages;
        serve-svelte-frontend = serveSvelteFrontend;
      };

      apps.${system}.serve-svelte-frontend = {
        type = "app";
        program = "${serveSvelteFrontend}/bin/serve-svelte-frontend";
      };

      formatter.${system} = pkgs.nixfmt;
    };
}
