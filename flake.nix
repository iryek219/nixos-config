{
  description = "Hwan's Infrastructure Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    codex-cli-nix.url = "github:sadjow/codex-cli-nix";
    opencode-flake.url = "github:aodhanhayter/opencode-flake";

    nix-openclaw = {
      url = "github:openclaw/nix-openclaw";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0.1";
  };

  outputs = {
    self,
    nixpkgs,
    nixos-wsl,
    home-manager,
    sops-nix,
    codex-cli-nix,
    nix-on-droid,
    ...
  } @ inputs: let
    forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"];

    mkSystem = {
      hostname,
      system,
      modules,
      wsl ? false,
      hmUser,
      overlays ? [],
      hmModules ? [],
    }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs;};
        modules =
          [
            ./modules/common.nix
            ./hosts/${hostname}

            sops-nix.nixosModules.sops

            {
              nixpkgs.config.allowUnfree = true;
              nixpkgs.overlays = overlays;
            }

            home-manager.nixosModules.home-manager

            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-backup";
              home-manager.extraSpecialArgs = {inherit inputs hostname;};
              home-manager.users.${hmUser} = {
                imports = [./home/default.nix] ++ hmModules;
              };
            }
          ]
          ++ modules
          ++ (
            if wsl
            then [nixos-wsl.nixosModules.default ./modules/wsl.nix]
            else []
          );
      };
  in {
    nixosConfigurations = {
      p-wsl = mkSystem {
        hostname = "p-wsl";
        system = "x86_64-linux";
        wsl = true;
        hmUser = "hwan";
        modules = [];
        overlays = [inputs.nix-openclaw.overlays.default];
        hmModules = [./home/openclaw.nix];
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
        modules = [inputs.determinate.nixosModules.default];
        overlays = [inputs.nix-openclaw.overlays.default];
        hmModules = [./home/openclaw.nix];
      };

      h-pc = mkSystem {
        hostname = "h-pc";
        system = "x86_64-linux";
        hmUser = "hwan";
        modules = [inputs.determinate.nixosModules.default];
      };
    };

    nixOnDroidConfigurations = {
      h-fold41 = nix-on-droid.lib.nixOnDroidConfiguration {
        pkgs = import nixpkgs {
          system = "aarch64-linux";
          overlays = [
            (final: prev: {
              # Add any overlays here if needed
            })
          ];
          config.allowUnfree = true;
        };
        modules = [
          ./hosts/h-fold41/default.nix
          {
            _module.args = {
              inherit inputs;
              hostname = "h-fold41";
            };
          }
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit inputs;
              hostname = "h-fold41";
            };
            home-manager.config = import ./home/default.nix;
          }
        ];
        home-manager-path = home-manager.outPath;
      };
      h-fold42 = nix-on-droid.lib.nixOnDroidConfiguration {
        pkgs = import nixpkgs {
          system = "aarch64-linux";
          overlays = [
            (final: prev: {
              # Add any overlays here if needed
            })
          ];
          config.allowUnfree = true;
        };
        modules = [
          ./hosts/h-fold42/default.nix
          {
            _module.args = {
              inherit inputs;
              hostname = "h-fold42";
            };
          }
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit inputs;
              hostname = "h-fold42";
            };
            home-manager.config = import ./home/default.nix;
          }
        ];
        home-manager-path = home-manager.outPath;
      };
    };

    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
