{ config, pkgs, ... }:
{
  wsl.enable = true;
  wsl.defaultUser = "hwan";

  # nix-ld is usually needed for WSL to run binaries like VSCode Server
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    gcc.cc.lib
    xorg.libX11
    xorg.libX11.dev
    expat
    libGL
  ];
}
