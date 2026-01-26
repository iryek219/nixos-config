{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  myVscode =
    pkgs.vscode-with-extensions.override {
      vscode = pkgs.vscode;

      # nixpkgs에 이미 있는 확장은 이렇게
      vscodeExtensions = with pkgs.vscode-extensions; [
        rust-lang.rust-analyzer
        tamasfe.even-better-toml
        serayuzgur.crates
        vadimcn.vscode-lldb
      ];
    };
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    rustup          # rustup만 두고 rustc/cargo는 rustup이 설치
    #myVscode
    #lldb
    pkg-config      # (옵션) 네이티브 의존성 자주 쓰면
    openssl         # (옵션) 예: openssl-sys
    cmake clang     # (옵션) C/C++ 빌드 필요 시
  ];

  shellHook = ''
    export PATH="$HOME/.cargo/bin:$PATH"
    export CARGO_HOME="$HOME/.cargo"
    export RUSTUP_HOME="$HOME/.rustup"
    if ! command -v rustc >/dev/null; then
      echo "[rustup] 최초 1회:  rustup default stable"
    fi
    echo ">>> Entered Rust dev shell."
  '';
}
