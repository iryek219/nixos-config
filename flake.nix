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

    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0.1";

    windmill.url = "path:/mnt/data/team-odyssey/infra/nixos/windmill"; # or git+ssh as appropriate
    #windmill-drill.url = "path:/home/hwan/dev/team-odyssey/infra/nixos/windmill"; # or git+ssh as appropriate
  };

  outputs = {
    self,
    nixpkgs,
    nixos-wsl,
    home-manager,
    sops-nix,
    codex-cli-nix,
    nix-on-droid,
    windmill,
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
            if hostname == "oci-arm"
            then
              [
                 windmill.nixosModules.windmill
                 ({ config, lib, ... }: {
                   sops.secrets."windmill/env" = {
                     path = "/run/keys/windmill.env";
                     owner = "root";
                     group = "root";
                     mode = "0400";
                     restartUnits = [
                       "docker-windmill_db.service"
                       "docker-windmill_server.service"
                     ] ++ lib.genList
                       (i: "docker-windmill_worker_${toString i}.service")
                       config.services.windmillStack.workerCount;
                   };
                   sops.secrets."windmill/backups_env" = {
                     path = "/run/keys/windmill-backups.env";
                     owner = "root";
                     group = "root";
                     mode = "0400";
                   };
                   sops.secrets."windmill/audit_mirror_env" = {
                     path = "/run/keys/windmill-audit-mirror.env";
                     owner = "root";
                     group = "root";
                     mode = "0400";
                   };

                   services.windmillStack = {
                     enable = true;
                     domain = "windmill.recallodyssey.com";
                     workspaceUid = 1000;     # output of `id -u`
                     workspaceGid = 100;      # NixOS users group
                     environmentFile = config.sops.secrets."windmill/env".path;
                     tlsCertFile = "/etc/ssl/certs/recallodyssey.pem";
                     tlsKeyFile = "/etc/ssl/private/recallodyssey.key";
                     backupS3 = {
                       bucket = "recall-odyssey-backups";
                       endpoint = "https://s3.us-west-004.backblazeb2.com";
                       prefix = "db/";
                       retentionDays = 30;
                       credentialsFile = config.sops.secrets."windmill/backups_env".path;
                     };
                     auditMirror = {
                       bucket = "recall-odyssey-backups";
                       endpoint = "https://s3.us-west-004.backblazeb2.com";
                       prefix = "audit/";
                       retentionDays = 30;
                       credentialsFile = config.sops.secrets."windmill/audit_mirror_env".path;
                     };
                   };
                 })
              ]
            else []
          )
          ++ (
            if hostname == "h-tuf"
            then
              [
                 inputs.windmill-drill.nixosModules.windmill
                 {
                   services.windmillStack = {
                     enable = true;
                     domain = "drill.local";
                     environmentFile = "/run/keys/windmill.env";
                   };
                 }
              ]
            else []
          )
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
        modules = [inputs.determinate.nixosModules.default];
      };

      oci-arm = mkSystem {
        hostname = "oci-arm";
        system = "aarch64-linux";
        hmUser = "hwan";
        modules = [inputs.disko.nixosModules.disko];
      };

      h-tuf = mkSystem {
        hostname = "h-tuf";
        system = "x86_64-linux";
        hmUser = "hwan";
        modules = [inputs.determinate.nixosModules.default];
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
