{
  config,
  pkgs,
  ...
}: {
  system.stateVersion = "25.05";
  system.adminUser = "hwan";
  networking.hostName = "p-wsl";

  users.users.hwan = {
    extraGroups = ["dialout" "uucp"];
  };
}
