{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: let
  adminUser = config.system.adminUser or "root";
  libs = [pkgs.stdenv.cc.cc.lib pkgs.gcc.cc.lib pkgs.libGL];
  uniqueLibs = inputs.nixpkgs.lib.lists.unique (map inputs.nixpkgs.lib.getLib libs);
in {
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
    nix.settings = {
      experimental-features = ["nix-command" "flakes"];
      # 버퍼를 128MB(또는 더 크게 512MB)로 늘립니다. 단위는 바이트입니다.
      download-buffer-size = 512 * 1024 * 1024;
    };

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "delete-older-than 7d";
    };

    nixpkgs.config.allowUnfree = true;

    # Ensure the Nixpkgs from your flake input can be found via the traditional <nixpkgs> path
    # keep nix.nixPath pointed at the flake's nixpkgs even on a fully-flake-driven system — it's a cheap compatibility shim for third-party tooling that still speaks channel-Nix.
    nix.nixPath = ["nixpkgs=${inputs.nixpkgs.outPath}"];

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
        stdenv.cc.cc.lib # libquadmath, libfortran, libstdc++, etc
        gcc.cc.lib
        xorg.libX11
        xorg.libX11.dev
        expat
        libGL
      ];
    };

    environment.sessionVariables.LD_LIBRARY_PATH = inputs.nixpkgs.lib.makeLibraryPath uniqueLibs;

    environment.sessionVariables.PKG_CONFIG_PATH = lib.concatStringsSep ":" [
      "/run/current-system/sw/lib/pkgconfig"
      "/run/current-system/sw/share/pkgconfig"
    ];

    networking.networkmanager.enable = true;

    # Incus container/VM manager (all NixOS hosts; nix-on-droid hosts don't import this module).
    # Incus requires nftables rather than iptables.
    virtualisation.incus.enable = true;
    networking.nftables.enable = true;
    # Allow hwan to manage Incus without root (merges with per-host extraGroups).
    users.users.hwan.extraGroups = ["incus-admin"];

    i18n.defaultLocale = "ko_KR.UTF-8";
    i18n.supportedLocales = [
      "ko_KR.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
    ];

    environment.etc."ssl/cert.pem".source = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

    environment.systemPackages = with pkgs; [
      usbutils
      wl-clipboard
      tree
      zip
      unzip
      wget
      curl
      dnsutils
      jq
      protobuf
      gcc
      clang
      gnumake
      cmake
      pkg-config
      openssl
      openssl.dev
      sqlite
      sqlite.dev
      zlib
      zlib.dev
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
      secrets."api-keys/zai" = {
        owner = adminUser;
      };
    };
  };
}
