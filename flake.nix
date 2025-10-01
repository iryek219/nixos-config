{
  description = "NixOS System Configuration Flake";

  inputs = {
    # Define nixpkgs as an input, pinning it to a specific branch/commit
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; 
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
  };

  outputs = { self, nixpkgs, nixos-wsl, ... }: {
    nixosConfigurations."pluto-msi-laptop" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      
      modules = [
        nixos-wsl.nixosModules.default 
        {
          system.stateVersion = "25.05";
          wsl.enable = true;
          wsl.defaultUser = "hwan";
        }
        ./configuration.nix
      ];
    };
  };
}
