{
  description = "TypeScript dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
  in {
    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        packages = with pkgs; [
          nodejs # current LTS; runs .ts directly via built-in type stripping
          pnpm
          typescript
          typescript-language-server
          prettier
        ];

        shellHook = ''
          echo "node $(node --version) | pnpm $(pnpm --version) | tsc $(tsc --version | cut -d' ' -f2)"
        '';
      };
    });

    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
