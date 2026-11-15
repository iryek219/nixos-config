# Hand-written for the HP ProLiant MicroServer N40L from the running Debian
# system (lsmod / lspci), because nixos-generate-config cannot run there.
# After booting the NixOS installer, compare with:
#   nixos-generate-config --no-filesystems --show-hardware-config
# Filesystems are declared by disko (disk-config.nix) and default.nix.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # AMD SB820M southbridge: AHCI SATA, OHCI/EHCI USB.
  boot.initrd.availableKernelModules = ["ahci" "ohci_pci" "ehci_pci" "usb_storage" "usbhid" "sd_mod"];
  boot.initrd.kernelModules = [];
  # k10temp: CPU temperature; sp5100_tco: the chipset hardware watchdog
  # (Debian ran the watchdog daemon against it; NixOS uses systemd's instead).
  boot.kernelModules = ["kvm-amd" "k10temp" "sp5100_tco"];
  boot.extraModulePackages = [];

  # Broadcom NetXtreme (tg3) on PCI 02:00.0 -> predictable name enp2s0.
  networking.useDHCP = lib.mkDefault true;

  # AMD Turion II Neo N40L: x86-64 baseline only (no SSSE3/SSE4.1/SSE4.2/AVX).
  # nixpkgs' x86_64-linux binaries target that baseline, so the cache works;
  # third-party binaries built for newer CPUs (claude-code, codex) will not run.
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
