{
  description = "Hwan's Infrastructure Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-wsl, home-manager, sops-nix, ... }@inputs:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];

      mkSystem = { hostname, system, modules, wsl ? false, hmUser }: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; }; 
        modules = [
          ./modules/common.nix
          ./hosts/${hostname}
          
          sops-nix.nixosModules.sops

          {
            nixpkgs.config.allowUnfree = true;
          }
          
          home-manager.nixosModules.home-manager

          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs hostname; };
            home-manager.users.${hmUser} = import ./home/default.nix;
          }
        ] ++ modules
          ++ (if wsl then [ nixos-wsl.nixosModules.default ./modules/wsl.nix ] else []);
      };
    in {
      nixosConfigurations = {
        p-wsl = mkSystem {
          hostname = "p-wsl";
          system = "x86_64-linux";
          wsl = true;
          hmUser = "hwan";
          modules = []; 
        };

        oci-arm = mkSystem {
          hostname = "oci-arm";
          system = "aarch64-linux";
          hmUser = "hwan";
          modules = [];
        };
        
        h-tuf = mkSystem {
          hostname = "h-tuf";
          system = "x86_64-linux";
          hmUser = "hwan";
          modules = [];
        };

        h-pc = mkSystem {
          hostname = "h-pc";
          system = "x86_64-linux";
          hmUser = "hwan";
          modules = [];
        };
      };

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
    };
}
