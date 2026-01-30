# Nix-on-Droid Integration

This configuration enables [Nix-on-Droid](https://github.com/nix-community/nix-on-droid) on two Samsung Galaxy Fold-4 devices (`h-fold41`, `h-fold42`).

## Setup Details

### 1. Flake Input
Added `nix-on-droid` to `flake.nix` inputs:
```nix
nix-on-droid = {
  url = "github:nix-community/nix-on-droid/release-24.05";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.home-manager.follows = "home-manager";
};
```
*   **Version**: Locked to `release-24.05` (consistent with system state version).
*   **Dependencies**: Follows the flake's global `nixpkgs` and `home-manager` to ensure version consistency across all hosts.

### 2. Output Configuration
Added `nixOnDroidConfigurations` to `flake.nix`:
*   **Host Name**: `h-fold4`
*   **System**: `aarch64-linux`
*   **Shared Config**: Reuses `home/default.nix` so the user environment (shell, vim, git, etc.) is identical to desktop/WSL.
*   **Host Specifics**: Imports `hosts/h-fold4/default.nix`.

### 3. Host File (`hosts/h-fold4/default.nix`)
Basic system settings for the Android environment:
*   **Packages**: `vim`, `git`, `openssh`.
*   **State Version**: `24.05`.
*   **Android Integration**: Enables `termux-open`, `termux-setup-storage`, and `termux-reload-settings`.

## Installation Guide (On Device)

1.  **Install App**: Get **Nix-on-Droid** from F-Droid.
2.  **Bootstrap**:
    ```bash
    nix-on-droid bootstrap
    ```
3.  **Setup Config**:
    Clone this repository to the expected location (or link it):
    ```bash
    mkdir -p ~/.config
    git clone <your-repo-url> ~/.config/nixpkgs
    ```
4.  **Apply**:
    ```bash
    nix-on-droid switch --flake ~/.config/nixpkgs#h-fold4
    ```

## Maintenance

*   **Updating**: Run `nix flake update` in the repo root to update `nix-on-droid` along with other inputs.
*   **Channels**: Not required. Flakes handle all dependency versions.
