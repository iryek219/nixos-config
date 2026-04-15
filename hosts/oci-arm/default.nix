{
  config,
  lib,
  pkgs,
  ...
}: let
  vars = import ./vars.nix;
in {
  imports = [
    ./hardware-configuration.nix
    "${builtins.fetchTarball "https://github.com/nix-community/disko/archive/v1.11.0.tar.gz"}/module.nix"
    ./disk-config.nix
  ];

  system.adminUser = "hwan";

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
    initrd.systemd.enable = true;
  };

  systemd.targets.multi-user.enable = true;

  networking.hostName = vars.hostname;
  networking.networkmanager.enable = true;

  time.timeZone = vars.timezone;
  i18n.defaultLocale = vars.locale;

  users = {
    mutableUsers = false;
    users.${vars.username} = {
      isNormalUser = true;
      extraGroups = ["networkmanager" "wheel"];
      openssh.authorizedKeys.keys = [vars.sshKey];
    };
  };

  # Enable passwordless sudo.
  security.sudo.extraRules = [
    {
      users = [vars.username];
      commands = [
        {
          command = "ALL";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  environment.systemPackages = with pkgs; [
    uv
    nodejs_22
    pnpm
  ];

  # --- PostgreSQL 16 + TimescaleDB ---
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16.withPackages (p: [ p.timescaledb ]);
    settings.shared_preload_libraries = "timescaledb";
    ensureDatabases = [ "stockeye" ];
    ensureUsers = [
      {
        name = "stockeye";
        ensureDBOwnership = true;
      }
    ];
    # Trust local connections so the app can connect with password from .env
    authentication = pkgs.lib.mkOverride 10 ''
      local all all trust
      host  all all 127.0.0.1/32 trust
      host  all all ::1/128      trust
    '';
  };

  # Set the stockeye user password after PostgreSQL starts
  systemd.services.postgresql.postStart = pkgs.lib.mkAfter ''
    $PSQL -c "ALTER USER stockeye WITH PASSWORD 'stockeye_dev';"
  '';

  # --- Redis ---
  services.redis.servers.stockeye = {
    enable = true;
    port = 6379;
  };

  # --- StockEye Backend (FastAPI on :8000) ---
  systemd.services.stockeye-backend = {
    description = "StockEye Backend";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network.target"
      "postgresql.service"
      "redis-stockeye.service"
    ];
    requires = [
      "postgresql.service"
      "redis-stockeye.service"
    ];
    serviceConfig = {
      Type = "simple";
      User = "hwan";
      WorkingDirectory = "/home/hwan/dev/stockeye2/backend";
      EnvironmentFile = "/home/hwan/dev/stockeye2/.env";
      Environment = "PYTHONPATH=.";
      ExecStart = "${pkgs.uv}/bin/uv run uvicorn app.main:app --host 0.0.0.0 --port 8000";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  # --- StockEye Frontend (Vite on :5173) ---
  systemd.services.stockeye-frontend = {
    description = "StockEye Frontend";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "simple";
      User = "hwan";
      WorkingDirectory = "/home/hwan/dev/stockeye2/frontend";
      ExecStart = "${pkgs.pnpm}/bin/pnpm dev";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # Disable autologin.
  services.getty.autologinUser = null;

  services.nginx = {
    enable = true;

    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    virtualHosts."ggumgrim.kr" = {
      forceSSL = true;

      sslCertificate = "/etc/ssl/certs/cloudflare-ggumgrim.pem";
      sslCertificateKey = "/etc/ssl/private/cloudflare-ggumgrim.key";

      locations."/" = {
        proxyPass = "http://127.0.0.1:5173";
        proxyWebsockets = true;
      };
    };
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [22 80 443];
  # networking.firewall.allowedUDPPorts = [ ... ];

  # Disable documentation for minimal install.
  documentation.enable = false;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.11"; # Did you read the comment?
}
