# HP ProLiant MicroServer N40L: headless file server at home.
# Replaces the Debian 9 install described in ~/work/n40l/N40L-runbook.md.
# Jobs: serve /srv/wd8t over SMB on the LAN and tailnet, snapshot it nightly
# onto /srv/wd14t, run a few Docker containers (Gitea, Trac) from
# /srv/wd8t/n40l-home/docker-compose.yml.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  vars = import ./vars.nix;

  # Nightly hardlink snapshot of snapSrc onto snapDst/snap/<date>, keeping the
  # newest snapKeep. Same design as the Debian cron script, with the fixes from
  # runbook-review.md item 3: rsync into a .partial directory, accept exit 24
  # (files vanished while copying), and only then rename and move `latest`.
  snapScript = pkgs.writeShellApplication {
    name = "snap-wd8t";
    runtimeInputs = with pkgs; [coreutils findutils rsync util-linux];
    text = ''
      SRC=${vars.snapSrc}
      DST=${vars.snapDst}
      KEEP=${toString vars.snapKeep}

      # Refuse to run unless both disks are really mounted; otherwise the
      # "backup" lands on the root disk.
      mountpoint -q "''${SRC%/}" && mountpoint -q "$DST" \
        || { echo "disks not mounted, aborting" >&2; exit 1; }

      today=$(date +%F)
      if [ -e "$DST/snap/$today" ]; then
        echo "$today exists, nothing to do"; exit 0
      fi
      mkdir -p "$DST/snap"

      link=()
      [ -e "$DST/latest" ] && link=(--link-dest="$DST/latest")

      set +e
      rsync -aHAX --delete --stats "''${link[@]}" "$SRC" "$DST/snap/$today.partial/"
      rc=$?
      set -e
      # 24 = some files vanished during the copy: routine on a live share.
      if [ "$rc" -ne 0 ] && [ "$rc" -ne 24 ]; then
        echo "rsync failed with $rc; leaving $today.partial for inspection" >&2
        exit "$rc"
      fi

      mv "$DST/snap/$today.partial" "$DST/snap/$today"
      ln -sfn "$DST/snap/$today" "$DST/latest"

      # prune: lexical order of YYYY-MM-DD is chronological
      ls -1d "$DST"/snap/????-??-?? | head -n -"$KEEP" | xargs -r rm -rf
      echo "snapshot $today done (rsync exit $rc)"
    '';
  };
in {
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../modules/oci-containers.nix # docker + hwan in the docker group
  ];

  system.stateVersion = "26.11";
  system.adminUser = vars.username;

  # ---------------------------------------------------------------- boot ---
  # Legacy BIOS. disko adds the EF02 partition's disk to boot.loader.grub.devices.
  boot.loader.grub.enable = true;
  boot.initrd.systemd.enable = true;
  boot.tmp.cleanOnBoot = true;

  # Chipset watchdog (sp5100_tco, loaded in hardware-configuration.nix):
  # reboot if PID 1 stops petting it. Replaces Debian's watchdog daemon.
  systemd.settings.Manager = {
    RuntimeWatchdogSec = "30s";
    RebootWatchdogSec = "10m";
  };

  # ------------------------------------------------ lean, headless server ---
  # common.nix turns these on for every host; a 2-core Turion from 2011 with
  # 7.7 GB does not need them.
  virtualisation.incus.enable = lib.mkForce false;
  networking.networkmanager.enable = lib.mkForce false; # plain DHCP on enp2s0
  documentation.enable = false;
  # Keep the box responsive while nix builds something locally.
  nix.settings = {
    max-jobs = 1;
    cores = 2;
  };

  # common.nix declares API-key secrets decrypted with the admin's age key,
  # which does not live on this server. Drop them here. To enable secrets
  # later: add this host's key (ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub)
  # to .sops.yaml, run `sops updatekeys secrets/secrets.yaml`, remove this line.
  sops.secrets = lib.mkForce {};

  # ------------------------------------------------------------ identity ---
  networking.hostName = vars.hostname;
  time.timeZone = vars.timezone;

  # Files on the data disks are owned hwan:users (1000:100); keep both ids.
  users.users.${vars.username} = {
    isNormalUser = true;
    uid = 1000;
    group = "users";
    description = vars.description;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = vars.sshKeys;
    # Console password: set once after install with `passwd` (users stay
    # mutable so a physical login is possible without a hash in the repo).
  };

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

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # ---------------------------------------------------------- data disks ---
  # By label, never /dev/sdX. nofail + 10 s timeout: a dead disk means a
  # missing share, not a boot stuck in emergency mode (runbook ground rules).
  fileSystems."/srv/wd8t" = {
    device = "/dev/disk/by-label/WD8T";
    fsType = "ext4";
    options = ["defaults" "nofail" "x-systemd.device-timeout=10"];
  };
  fileSystems."/srv/wd14t" = {
    device = "/dev/disk/by-label/WD14T";
    fsType = "ext4";
    options = ["defaults" "nofail" "x-systemd.device-timeout=10"];
  };

  # SMART monitoring of all drives; the 8 TB has 75k+ power-on hours.
  services.smartd = {
    enable = true;
    autodetect = true;
    notifications = {
      wall.enable = true;
      mail.enable = false;
    };
  };

  # ------------------------------------------------------------- network ---
  services.tailscale.enable = true;
  networking.firewall = {
    enable = true;
    trustedInterfaces = ["tailscale0"];
    allowedUDPPorts = [config.services.tailscale.port];
    # Docker publishes Gitea (8222/8280), adminer (8282), pgadmin (8281) and
    # Trac (9022/9080) itself, bypassing this firewall; listed for the record.
    allowedTCPPorts = [8222 8280 8281 8282 9022 9080];
  };

  # mDNS: n40l.local for the LAN.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  # --------------------------------------------------------------- samba ---
  # Same policy as the Debian smb.conf: one share, one user, SMB2+, no
  # NetBIOS, LAN + tailnet only. After install: `sudo smbpasswd -a hwan`.
  services.samba = {
    enable = true;
    openFirewall = true;
    nmbd.enable = false;
    winbindd.enable = false;
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = "n40l";
        "server role" = "standalone server";
        "server min protocol" = "SMB2_02";
        "disable netbios" = "yes";
        "smb ports" = "445";
        "hosts allow" = "127. 192.168.2. 100.64.0.0/10 fd7a:115c:a1e0::/48";
        "hosts deny" = "ALL";
        security = "user";
        "map to guest" = "never";
        "log level" = "1";
      };
      wd8t = {
        comment = "WD8T data";
        path = "/srv/wd8t";
        "valid users" = vars.username;
        "read only" = "no";
        browseable = "yes";
        "create mask" = "0664";
        "directory mask" = "2775";
        # Keep the boot-disk exports (credentials, DB dumps) off the share
        # (runbook-review.md item 8).
        "veto files" = "/n40l-home/";
      };
    };
  };
  # WS-Discovery so Windows shows the N40L under Network.
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  # ----------------------------------------------------- nightly snapshot ---
  systemd.services.snap-wd8t = {
    description = "Nightly hardlink snapshot of ${vars.snapSrc} onto ${vars.snapDst}";
    unitConfig.RequiresMountsFor = [vars.snapSrc vars.snapDst];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe snapScript;
      Nice = 10;
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 7;
    };
  };
  systemd.timers.snap-wd8t = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 03:30:00";
      Persistent = true; # catch up if the box was off at 03:30
    };
  };

  # ------------------------------------------------------------- docker ---
  # Gitea/Trac are not declared here on purpose: they are legacy containers
  # restored by hand from /srv/wd8t/n40l-home (docker-compose.yml, trac-run.sh,
  # docker-images.tgz). See N40L-runbook.md Phase 6 and runbook-review.md item 2.
  environment.systemPackages = with pkgs; [
    docker-compose
    rsync
    tmux
    smartmontools
    lm_sensors
    hdparm
    pciutils
    ethtool
    cifs-utils
    snapScript
  ];
}
