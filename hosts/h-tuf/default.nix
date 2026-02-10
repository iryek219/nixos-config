{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];

  system.stateVersion = "25.05";
  system.adminUser = "hwan";
  networking.hostName = "h-tuf";

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";

  users.users.hwan = {
    isNormalUser = true;
    description = "Hyunghwan Shin";
    extraGroups = ["networkmanager" "wheel" "dialout" "uucp"];
    group = "hwan";
    packages = with pkgs; [
      #  thunderbird
    ];
  };
  users.groups.hwan = {};

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    anki
    gparted
    google-chrome
    kdePackages.okular
    zoom-us
    dejavu_fonts
    noto-fonts
    noto-fonts-cjk-sans
  ];

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ko_KR.UTF-8";
    LC_IDENTIFICATION = "ko_KR.UTF-8";
    LC_MEASUREMENT = "ko_KR.UTF-8";
    LC_MONETARY = "ko_KR.UTF-8";
    LC_NAME = "ko_KR.UTF-8";
    LC_NUMERIC = "ko_KR.UTF-8";
    LC_PAPER = "ko_KR.UTF-8";
    LC_TELEPHONE = "ko_KR.UTF-8";
    LC_TIME = "ko_KR.UTF-8";
  };
  i18n.inputMethod = {
    enable = true;
    type = "ibus";
    ibus = {
      engines = with pkgs.ibus-engines; [hangul];
    };
  };

  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.xserver.xkb = {
    layout = "kr";
    variant = "kr104";
  };

  services.printing.enable = true;

  services.logind.settings.Login.HandleLidSwitch = "ignore";

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };
}
