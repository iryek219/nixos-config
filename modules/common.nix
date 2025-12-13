{ config, pkgs, inputs, lib, ... }:
let
  adminUser = config.system.adminUser or "root";
  libs = [ pkgs.stdenv.cc.cc.lib pkgs.gcc.cc.lib pkgs.libGL ];
  uniqueLibs = inputs.nixpkgs.lib.lists.unique (map inputs.nixpkgs.lib.getLib libs);
in
{
  # --- 1. DEFINE THE NEW OPTION PATH ---
  options.system.adminUser = lib.mkOption {
    type = lib.types.str;
    default = "root";
    description = ''
      The primary administrative user for this host, used for setting
      file ownership on secrets and other administrative tasks.
    '';
  };

  # --- 2. WRAP ALL CONFIGURATION ATTRIBUTES IN 'config' ---
  config = {
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nixpkgs.config.allowUnfree = true;

    # Ensure the Nixpkgs from your flake input can be found via the traditional <nixpkgs> path
    #nix.nixPath = [ "nixpkgs=${inputs.nixpkgs.outPath}" ];
    nix.nixPath = [ ];
    
    # This makes your flake inputs available in the registry for new-style commands
    # like `nix build nixpkgs#hello` without explicitly passing the flake input.
    nix.registry = {
      nixpkgs.flake = inputs.nixpkgs;
      # You can add other inputs here too, e.g.,
      # home-manager.flake = inputs.home-manager;
    };

    programs.nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib    # libquadmath, libfortran, libstdc++, etc
        gcc.cc.lib
        xorg.libX11
        xorg.libX11.dev
        expat
      ];
    };

    environment.sessionVariables.LD_LIBRARY_PATH = inputs.nixpkgs.lib.makeLibraryPath uniqueLibs;

    networking.networkmanager.enable = true;

    i18n.defaultLocale = "ko_KR.UTF-8";
    i18n.supportedLocales = [
      "ko_KR.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
    ];

    environment.systemPackages = with pkgs; [
      wl-clipboard
      tree
      unzip
      wget
      git gh
      gcc
      clang
      gnumake
      cmake
      pkg-config
      openssl openssl.dev
      sqlite sqlite.dev
      zlib zlib.dev
      ffmpeg-full
      yt-dlp
    ];

    environment.variables = {
      EDITOR = "vim";
    };

    environment.interactiveShellInit = ''
      [ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"
      [ -d "$HOME/.cargo/bin" ] && PATH="$HOME/.cargo/bin:$PATH"
      export PATH
    '';

    environment.localBinInPath = true;

    sops = {
      age.keyFile = "/home/${adminUser}/.config/sops/age/keys.txt";
      defaultSopsFile = ../secrets/secrets.yaml;
	  
      secrets."api-keys/google_cloud" = {
        owner = adminUser;
      };
      secrets."api-keys/gemini" = {
        owner = adminUser;
      };
      secrets."api-keys/anthropic" = {
        owner = adminUser;
      };
    };
  };
}
