
{
  description = "Python dev environment";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux"; 
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        # 1. We provide uv here
        packages = [
          pkgs.python312
          pkgs.uv
        ];

        # 2. We expose necessary C libraries to the environment
        # This fixes issues where 'pip build' fails to find headers
        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
          pkgs.stdenv.cc.cc
          pkgs.zlib
          # Add other libs here if a specific python package needs them (e.g. pkgs.glib)
        ];

        # 3. Environment variables to help tools play nice
        shellHook = ''
          # Optional: helpful message
          echo $(uv --version)
          echo "Python $(python --version)"

          export UV_PYTHON_DOWNLOADS=never

          echo 
          echo "Important:"
          echo "   UV venv should use the same python compiler as the one this flake declares"
          echo "   This is to ensure that python packages and stdenv.cc.cc are from the same Nix pkgs."
          echo "   The python downloaded from internet may not have been compiled against the same version of glibc or libstdc++so.6(pkgs.stdenv.cc.cc) from Nix pkgs"
          echo "Create venv with"
          echo "   uv venv --python \$(which python)"
          echo
        '';
      };
    };
}
