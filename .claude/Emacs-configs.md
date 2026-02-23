# Emacs Configuration Structure

This document describes the Emacs configuration setup using Chemacs2 to manage multiple profiles (Doom and Vanilla).

## Directory Overview

| Path | Purpose | Managed By |
|------|---------|------------|
| `~/.emacs.d` | Chemacs2 bootstrap | Home Manager (Nix symlink) |
| `~/.emacs-profiles.el` | Chemacs2 profile definitions | Home Manager (Nix symlink) |
| `~/.emacs-configs/doom-emacs` | Doom Emacs framework | Manual (git clone) |
| `~/.emacs-configs/vanilla-emacs` | Vanilla Emacs config | Manual |
| `~/.config/doom` | Doom user configuration (DOOMDIR) | Manual |

## How It Works

1. **Home Manager** manages `~/.emacs.d` and `~/.emacs-profiles.el` as symlinks to the Nix store
2. **Chemacs2** (bootstrapped from `~/.emacs.d`) reads `~/.emacs-profiles.el` to determine available profiles
3. **Profiles** point to actual Emacs configurations in `~/.emacs-configs/`
4. **Doom Emacs** uses `~/.config/doom` as DOOMDIR for user customization

## Profile Configuration

From `~/.emacs-profiles.el`:

```elisp
(
 ("default" . ((user-emacs-directory . "~/.emacs-configs/vanilla-emacs")))
 ("doom"    . ((user-emacs-directory . "~/.emacs-configs/doom-emacs")
               (env . (("DOOMDIR" . "~/.config/doom")))))
 ("vanilla" . ((user-emacs-directory . "~/.emacs-configs/vanilla-emacs")))
)
```

- **default**: Launches vanilla Emacs
- **doom**: Launches Doom Emacs with DOOMDIR set
- **vanilla**: Alias for vanilla Emacs

## Usage

```bash
# Launch default profile (vanilla)
emacs

# Launch specific profile
emacs --with-profile doom
emacs --with-profile vanilla
```

## Directory Details

### ~/.emacs-configs/doom-emacs (~212M)

The Doom Emacs framework installation. Contains:
- `bin/` - Doom CLI tools (`doom sync`, `doom upgrade`, etc.)
- `lisp/` - Core Doom lisp code
- `modules/` - Doom modules

### ~/.emacs-configs/vanilla-emacs (~17M)

Vanilla Emacs configuration. Contains:
- `init.el` - Main configuration
- `elpa/` - Installed packages
- `eln-cache/` - Native compilation cache

### ~/.config/doom (~24K)

Doom user configuration (DOOMDIR). Contains:
- `init.el` - Module selection
- `config.el` - Personal configuration
- `packages.el` - Additional packages

## Maintenance

### Doom Emacs

```bash
# Sync packages after editing init.el or packages.el
~/.emacs-configs/doom-emacs/bin/doom sync

# Upgrade Doom
~/.emacs-configs/doom-emacs/bin/doom upgrade
```

### Home Manager

Chemacs2 bootstrap is managed by Home Manager. Changes to profile configuration require editing `home/default.nix` and rebuilding:

```bash
./rebuild.sh h-tuf
```
