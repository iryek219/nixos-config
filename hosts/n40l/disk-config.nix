# Root disk layout for the N40L (BIOS firmware, no UEFI).
# GPT with a 1 MiB BIOS-boot partition lets GRUB boot legacy BIOS from GPT.
# Only the disk named here is touched; the WD data disks are not listed and
# are physically removed during the install.
{
  disko.devices.disk.main = {
    type = "disk";
    device = (import ./vars.nix).bootDisk;
    content = {
      type = "gpt";
      partitions = {
        boot = {
          priority = 1;
          size = "1M";
          type = "EF02"; # BIOS boot partition (GRUB core image)
        };
        swap = {
          priority = 2;
          size = "8G"; # matches the 7.9 GB swap Debian had; RAM is 7.7 GB
          content.type = "swap";
        };
        root = {
          priority = 3;
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            mountOptions = ["noatime"];
          };
        };
      };
    };
  };
}
