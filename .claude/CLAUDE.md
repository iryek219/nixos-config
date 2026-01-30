# NixOS Configuration Management

This documentation is for the `claude code` agent to understand and manage the NixOS configuration in this repository.

## Project Overview

This repository contains a multi-host NixOS configuration using **Nix Flakes**. It manages system configurations (`modules/common.nix`, `hosts/`), user environments via **Home Manager** (`home/`), and secrets via **sops-nix**.

## Directory Structure

*   **`flake.nix`**: The entry point. Defines inputs (nixpkgs, home-manager, sops-nix, etc.) and outputs (system configurations).
*   **`hosts/`**: Host-specific configurations.
    *   `h-tuf`: Primary x86_64 workstation/laptop.
    *   `p-wsl`: WSL2 environment.
    *   `oci-arm`: ARM64 Oracle Cloud instance. Headless.
    *   `h-pc`: Secondary x86_64 machine.
    *    h-fold41 : nix-droid on Android. Headless. systemd is not available.
    *    h-fold42 : nix-droid on Android. Headless. systemd is not available.
*   **`modules/`**: Shared NixOS modules.
    *   `common.nix`: Base configuration applied to all hosts (users, system packages, nix settings).
    *   `wsl.nix`: Specific settings for WSL environments.
*   **`home/`**: Home Manager configurations.
    *   `default.nix`: Main user configuration (packages, shell aliases, git, starship, etc.).
*   **`secrets/`**: Encrypted secrets.
    *   `secrets.yaml`: The SOPS encrypted file.
*   **`rebuild.sh`**: Helper script to apply configurations.

## Management Commands

### Rebuilding the System

To apply changes to the current host or a specific target:

```bash
# Using the helper script
./rebuild.sh <hostname>

# Manual command
sudo nixos-rebuild switch --flake ".#<hostname>" --impure
```
*Note: `--impure` is often required if looking up absolute paths or variables not strictly in the flake.*

### Managing Secrets

Secrets are managed with `sops`. To edit secrets:

```bash
sops secrets/secrets.yaml
```

*   **Keys**: usage depends on `~/.config/sops/age/keys.txt`.
*   **Configuration**: See `.sops.yaml` for encryption rules and key groups.

### Updating Dependencies

To update flake inputs (nixpkgs, home-manager, etc.):

```bash
nix flake update
```

### Garbage Collection

To clean up old generations:

```bash
nix-collect-garbage -d
```

## Development Guidelines

1.  **User Packages**: Add to `home/default.nix` under `home.packages`.
2.  **System Packages**: Add to `modules/common.nix` under `environment.systemPackages`.
3.  **Host-Specifics**: Edit `hosts/<hostname>/default.nix` or `hosts/<hostname>/hardware-configuration.nix`.
4.  **New Host**:
    *   Create `hosts/<new-host>/`.
    *   Generate hardware config: `nixos-generate-config --show-hardware-config > hosts/<new-host>/hardware-configuration.nix`.
    *   Create `hosts/<new-host>/default.nix` importing the hardware config.
    *   Add the host to `nixosConfigurations` in `flake.nix`.

## Notes for Claude Code Agent

*   **Read-First**: Always read `flake.nix` and `modules/common.nix` before making sweeping changes.
*   **Respect Host Capability**: Some hosts are headless - 'oci-arm', 'h-fold41', and 'h-fold42'). Some don't have systemd - 'h-fold41' and 'h-fold42'. Respect each host's capabilities when modifying the config.
*   **Safety**: When editing `secrets.yaml`, ensure you have the correct `sops` environment or ask the user to handle the encryption part if you cannot invoke the editor directly (usually `sops` opens `$EDITOR`).
*   **Verification**: After editing `.nix` files, `nix fmt` (or `alejandra` if configured) is good practice, and `nixos-rebuild dry-build` can verify syntax without applying.
