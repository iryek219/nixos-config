{ config, pkgs, inputs, lib, ... }:
let
  adminUser = config.system.adminUser or "root";
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

    i18n.defaultLocale = "ko_KR.UTF-8";
    i18n.supportedLocales = [
      "ko_KR.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
    ];

    environment.systemPackages = with pkgs; [
      tree 
      vim 
      wget 
      git gh 
      uv
      rustup 
      gcc 
      pkg-config cmake
      openssl openssl.dev 
      zlib zlib.dev 
      sqlite sqlite.dev
    ];

    environment.variables = {
      EDITOR = "vim";
      GEMINI_MODEL="gemini-2.5-pro";
    };

    environment.interactiveShellInit = ''
      [ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"
      [ -d "$HOME/.cargo/bin" ] && PATH="$HOME/.cargo/bin:$PATH"
      export PATH
      export CARGO_HOME="$HOME/.cargo"
      export RUSTUP_HOME="$HOME/.rustup"

      if [ "$(whoami)" = "${adminUser}" ]; then
        export GEMINI_API_KEY="$(cat /run/secrets/api_keys/gemini)"
        export ANTHROPIC_API_KEY="$(cat /run/secrets/api_keys/anthropic)"
        export GOOGLE_CLOUD_PROJECT="$(cat /run/secrets/api_keys/google_cloud)"
      fi
    '';

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
