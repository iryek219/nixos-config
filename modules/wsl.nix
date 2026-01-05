{ config, pkgs, ... }:
{
  wsl.enable = true;
  wsl.defaultUser = "hwan";
  wsl.usbip.enable = true;
}
