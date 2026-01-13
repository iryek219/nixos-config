{ config, pkgs, lib, ... }:
{
  wsl.enable = true;
  wsl.defaultUser = "hwan";
  wsl.usbip.enable = true;

  # NetworkManager and wpa_supplicant are not needed in WSL and cause activation failures
  networking.networkmanager.enable = lib.mkForce false;
  networking.wireless.enable = lib.mkForce false;
}
