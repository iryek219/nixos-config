{
  description = "Python dev environment (uv)";

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
          # Default python3 is the one Hydra fully caches; pinning an older
          # pythonNN here forces local builds on aarch64 (see microduck_rl).
          python312
          uv
          ruff
          basedpyright
        ];

        # uv must reuse the Nix interpreter, never a downloaded one: wheels and
        # stdenv.cc.cc need to come from the same nixpkgs.
        UV_PYTHON_DOWNLOADS = "never";
        UV_PYTHON_PREFERENCE = "only-system";

        shellHook = ''
          export UV_PYTHON="$(command -v python3)"
          echo "python $(python3 --version | cut -d' ' -f2) | uv $(uv --version | cut -d' ' -f2) | ruff $(ruff --version | cut -d' ' -f2)"
        '';
      };
    });

    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
