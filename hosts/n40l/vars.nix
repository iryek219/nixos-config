{
  hostname = "n40l";
  username = "hwan";
  description = "Hyunghwan Shin";
  timezone = "Asia/Seoul";

  # Root/boot disk: the 80 GB Intel SSD. Stable by-id name so the installer can
  # never pick a data disk by accident (the two WD data disks are pulled during
  # the install anyway; see N40L-runbook.md, Phase 6).
  bootDisk = "/dev/disk/by-id/ata-INTEL_SSDSA2M080G2GC_CVPO937101BL080BGN";

  # Keys that were in /home/hwan/.ssh/authorized_keys on the Debian install.
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAQ649mDk9QE96wzY94aGmbGZjV704KQ6qpapFEgKTeG hwan.shin@gmail.com"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDRALqOzUy3c5DtXwUHrgJoWeuTTbVMDZJKpKjdE7p+HP2JRnvfLvj1bc0nlAY5KVKTzqwYEWFa0IvzrCJUgeG2dGbm0QBDQM8hWi/QozmueZ0b5tq/V+m2e6kL7fzFSGvMdrgeQUDERhv32FlmTzW8EUlZVu8Vh/mhBsgD30y/Tyg4f4LPQ4wTZ84dc4TbazODOEseOMUfNTMSNNJSodaqwTWLgJJUutrTodW/4SygrvMoOmGEjmYAEGeaDQSc9iFB520KpqUUMN10948R66FtqkCTxdBf8ddIUFLjnAoTrYKOz9jp2V3yc+cid5Xcic21qWGWs97GhTRHlD9xwuVj u0_a127@localhost"
  ];

  # Nightly hardlink snapshots: SRC is the live share, DST receives snap/<date>.
  # Role swap (runbook, Open decisions): swap these two and the Samba share path.
  snapSrc = "/srv/wd8t/";
  snapDst = "/srv/wd14t";
  snapKeep = 14;

  # Nightly copy of the Docker volumes (on the SSD) onto WD8T, just before the
  # snapshot. Under n40l-home, so Samba vetoes it: it holds password hashes.
  dockerBackupDst = "/srv/wd8t/n40l-home/docker-volumes";
}
