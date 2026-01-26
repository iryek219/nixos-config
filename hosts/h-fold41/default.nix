{
  config,
  lib,
  pkgs,
  ...
}: {
  # Termux-specific system configuration
  
  # Ensure we have some basic tools in the system profile
  environment.packages = with pkgs; [
    openssh
  ];

  # Backup etc files when they collide with Nix managed ones
  environment.etcBackupExtension = ".bak";

  # Read the changelog before changing this value
  system.stateVersion = "24.05";

  # Set the hostname environment variable as a workaround
  environment.sessionVariables = {
    HOSTNAME = "h-fold41";
  };

  # Android integration settings
  android-integration = {
    termux-open.enable = true;
    termux-setup-storage.enable = true;
    termux-reload-settings.enable = true;
  };
}
