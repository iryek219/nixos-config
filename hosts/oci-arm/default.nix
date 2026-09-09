{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  vars = import ./vars.nix;
  # tailscale from the fresher nixpkgs input (see flake.nix).
  tailscalePkg = inputs.nixpkgs-fresh.legacyPackages.${pkgs.stdenv.hostPlatform.system}.tailscale;
in {
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../modules/oci-containers.nix
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

  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/a807f76b-afbb-4cc3-9391-e135033ff165";
    fsType = "ext4";
    options = ["defaults" "nofail"];
  };

  systemd.tmpfiles.rules = [
    "d /mnt/data 0755 hwan users -"
    # Incus dir storage pool source (must exist and be empty before first init).
    "d /mnt/data/incus 0711 root root -"
    # /bin/bash compat shim for third-party scripts with #!/bin/bash shebangs
    # (e.g. Discourse's d/* dev scripts).
    "L+ /bin/bash - - - - /run/current-system/sw/bin/bash"
  ];

  virtualisation.docker.daemon.settings.data-root = "/mnt/data/docker";
  systemd.services.docker.unitConfig.RequiresMountsFor = "/mnt/data";

  # Keep Incus instance/image storage on the roomy /mnt/data (sdb) instead of the
  # tight root disk. Applied once by incus-preseed.service after incusd starts.
  virtualisation.incus.preseed = {
    storage_pools = [
      {
        name = "default";
        driver = "dir";
        config.source = "/mnt/data/incus";
      }
    ];
    networks = [
      {
        name = "incusbr0";
        type = "bridge";
        config = {
          "ipv4.address" = "auto";
          "ipv6.address" = "none";
        };
      }
    ];
    profiles = [
      {
        name = "default";
        devices = {
          eth0 = {
            name = "eth0";
            type = "nic";
            network = "incusbr0";
          };
          root = {
            path = "/";
            type = "disk";
            pool = "default";
          };
        };
      }
    ];
  };
  # incusd (and thus preseed) must not start before /mnt/data is mounted.
  systemd.services.incus.unitConfig.RequiresMountsFor = "/mnt/data";

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
    awscli2
  ];

  # --- PostgreSQL 16 + TimescaleDB ---
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16.withPackages (p: [p.timescaledb]);
    settings.shared_preload_libraries = "timescaledb";
    ensureDatabases = ["stockeye"];
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

  # --- Redis ---
  services.redis.servers.stockeye = {
    enable = true;
    port = 6379;
  };

  # --- StockEye Backend (FastAPI on :8000) ---
  systemd.services.stockeye-backend = {
    description = "StockEye Backend";
    wantedBy = ["multi-user.target"];
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
      Environment = [
        "PYTHONPATH=."
        "LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib"
      ];
      ExecStart = "${pkgs.uv}/bin/uv run uvicorn app.main:app --host 0.0.0.0 --port 8006";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  # --- StockEye Frontend (Vite on :5173) ---
  systemd.services.stockeye-frontend = {
    description = "StockEye Frontend";
    # Disabled 2026-09-09: `pnpm dev` crash-loops (pnpm ENOENT). Unit stays
    # defined for manual `systemctl start`; restore wantedBy to re-enable.
    wantedBy = [];
    after = ["network.target"];
    path = [pkgs.bash pkgs.nodejs_20];
    serviceConfig = {
      Type = "simple";
      User = "hwan";
      WorkingDirectory = "/home/hwan/dev/stockeye2/frontend";
      ExecStart = "${pkgs.pnpm}/bin/pnpm dev";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  # --- Tailscale ---
  # Private access to loopback-only dev services from the tailnet without
  # republishing Docker ports. Login once with `sudo tailscale up`.
  # Direct UDP (41641) is not opened in the firewall or the OCI security list,
  # so peers connect via DERP relays; fine for a dev instance.
  services.tailscale = {
    enable = true;
    package = tailscalePkg;
  };

  # Publish the Discourse dev container (Rails/Ember on :3000, mail catcher
  # on :8025) on the tailnet as plain HTTP on the same ports:
  #   http://oci-arm:3000  and  http://oci-arm:8025
  # `tailscale serve` terminates inside tailscaled, so nothing is bound on
  # 0.0.0.0 and no firewall port is opened. The config persists in tailscaled
  # state; re-applying on boot keeps it declarative. Rails must allow the
  # tailnet hostnames via RAILS_DEVELOPMENT_HOSTS (see d/boot_dev -e ...).
  systemd.services.tailscale-serve-discourse = {
    description = "Expose Discourse dev ports on the tailnet via tailscale serve";
    wantedBy = ["multi-user.target"];
    after = ["tailscaled.service"];
    requires = ["tailscaled.service"];
    path = [config.services.tailscale.package pkgs.jq];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Serve config is only accepted once the node is logged in.
      for _ in $(seq 1 60); do
        state=$(tailscale status --json 2>/dev/null | jq -r .BackendState || true)
        [ "$state" = "Running" ] && break
        sleep 2
      done
      if [ "$state" != "Running" ]; then
        echo "tailscale not logged in (state: ''${state:-unknown}); run 'sudo tailscale up' then restart this unit" >&2
        exit 0
      fi
      tailscale serve --bg --http=3000 http://127.0.0.1:3000
      tailscale serve --bg --http=8025 http://127.0.0.1:8025
    '';
  };

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
    };
  };

  # Disable autologin.
  services.getty.autologinUser = null;

  services.nginx = {
    enable = false;

    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    virtualHosts."recallodyssey.com" = {
      forceSSL = true;

      sslCertificate = "/etc/ssl/certs/recallodyssey.pem";
      sslCertificateKey = "/etc/ssl/private/recallodyssey.key";

      locations."/" = {
        #proxyPass = "http://127.0.0.1:5173"; # stockeye
        proxyPass = "http://127.0.0.1:3000"; # recall odyssey
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
