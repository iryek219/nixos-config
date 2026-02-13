# NixOS Configuration Management

This documentation is for the `claude code` agent to understand and manage the NixOS configuration in this repository.

## Project Overview

This repository contains a multi-host NixOS configuration using **Nix Flakes**. It manages system configurations (`modules/common.nix`, `hosts/`), user environments via **Home Manager** (`home/`), and secrets via **sops-nix**.

## Directory Structure

```
/etc/nixos/
├── flake.nix                    # Main entry point
├── flake.lock                   # Lock file for inputs
├── rebuild.sh                   # Helper script for rebuilding
├── .sops.yaml                   # SOPS encryption configuration
├── hosts/                       # Host-specific configurations
│   ├── h-tuf/                   # Primary workstation (x86_64, GUI)
│   ├── p-wsl/                   # WSL2 environment (x86_64, headless)
│   ├── oci-arm/                 # Oracle Cloud ARM instance (aarch64, headless)
│   ├── h-fold41/                # Android nix-on-droid (aarch64, no systemd)
│   ├── h-fold42/                # Android nix-on-droid (aarch64, no systemd)
│   └── h-pc/                    # (EMPTY - defined in flake.nix but not implemented)
├── modules/                     # Shared NixOS modules
│   ├── common.nix               # Base config for all hosts
│   └── wsl.nix                  # WSL-specific overrides
├── home/                        # Home Manager configurations
│   ├── default.nix              # Main user config (shared)
│   ├── vscode.nix               # VSCode config (h-tuf only)
│   └── openclaw.nix             # OpenClaw config (h-tuf only)
├── secrets/
│   └── secrets.yaml             # SOPS-encrypted secrets
├── outsiders/                   # Development environments
│   ├── Python/flake.nix         # Python dev shell
│   ├── Rust/                    # Rust dev environment
│   ├── openclaw/install.txt     # OpenClaw setup instructions
│   └── home/                    # Home directory experiments
└── .claude/
    ├── CLAUDE.md                # This documentation
    └── nix-on-droid.md          # Nix-on-droid setup guide
```

## Hosts

| Host | Architecture | GUI | systemd | State Version | Notes |
|------|-------------|-----|---------|---------------|-------|
| **h-tuf** | x86_64 | GNOME | Yes | 25.05 | Primary workstation, AMD CPU, Determinate Nix |
| **p-wsl** | x86_64 | No | Yes | 25.05 | WSL2, default user: hwan |
| **oci-arm** | aarch64 | No | Yes | 24.11 | Oracle Cloud, immutable users, SSH-only auth |
| **h-fold41** | aarch64 | No | No | 24.05 | Samsung Galaxy Fold-4, nix-on-droid |
| **h-fold42** | aarch64 | No | No | 24.05 | Samsung Galaxy Fold-4, nix-on-droid |
| **h-pc** | x86_64 | - | - | - | **Planned but not implemented** (in flake.nix only) |

### Host Details

#### h-tuf (Primary Workstation)
- UEFI boot with systemd-boot
- GNOME desktop with GDM display manager
- IBus with Hangul engine (Korean input)
- Keyboard layout: kr/kr104
- PipeWire audio with ALSA/Pulse support
- Lid close behavior: ignores lid close (prevents sleep on lid close)
- Determinate Nix module enabled
- OpenClaw integration: nix-openclaw overlay, Telegram bot gateway
- Packages: Anki, Gparted, Chrome, Okular, Zoom

#### p-wsl (WSL2)
- WSL module with USBIP enabled
- NetworkManager/wireless disabled (incompatible)
- CJK fonts (Noto Sans/Serif CJK KR)
- Packages: arduino-ide, inkscape, audacity, wslu
- **Note**: OpenClaw disabled due to WSL2 build issues (pnpm deps hang)

#### oci-arm (Oracle Cloud)
- Immutable users (`mutableUsers = false`)
- Disko disk management (GPT, VFAT boot, ext4 root)
- SSH key authentication only (passwords disabled)
- Passwordless sudo for admin user
- Variables in `hosts/oci-arm/vars.nix`

#### h-fold41 / h-fold42 (Android)
- nix-on-droid framework
- Android integration: termux-open, termux-setup-storage
- No systemd (use nix-on-droid commands)
- Shares `home/default.nix` with other hosts

## Flake Inputs

| Input | Source | Purpose |
|-------|--------|---------|
| `nixpkgs` | nixos-unstable | Core packages |
| `nixos-wsl` | nix-community/NixOS-WSL | WSL support |
| `home-manager` | nix-community/home-manager | User environments |
| `sops-nix` | Mic92/sops-nix | Secrets management |
| `nix-on-droid` | nix-community/nix-on-droid (24.05) | Android support |
| `determinate` | DeterminateSystems/determinate | Determinate Nix (h-tuf) |
| `nix-openclaw` | github:openclaw/nix-openclaw | OpenClaw AI assistant (h-tuf only) |
| `codex-cli-nix` | sadjow/codex-cli-nix | Codex CLI (x86_64 only) |
| `opencode-flake` | aodhanhayter/opencode-flake | Opencode tool (x86_64 only) |

## Modules

### common.nix
Applied to all NixOS hosts. Configures:
- **Nix settings**: Flakes enabled, automatic weekly GC, 256MB download buffer
- **nix-ld**: Enabled with comprehensive library set (libstdc++, libGL, X11, etc.)
- **LD_LIBRARY_PATH**: Includes libstdc++, libquadmath, libfortran, libGL, X11, openssl
- **Networking**: NetworkManager (disabled in WSL)
- **Locales**: Korean primary (ko_KR.UTF-8), English support
- **System packages**: gcc, clang, cmake, openssl, sqlite, ffmpeg-full, yt-dlp, etc.
- **sops-nix secrets**: API keys (google_cloud, gemini, anthropic, zai)
- **Option**: `system.adminUser` (default: "root")

### wsl.nix
WSL-specific overrides:
- Enables WSL mode with default user "hwan"
- Enables USBIP
- Disables NetworkManager and wireless

## Home Manager

### home/default.nix
Shared user configuration applied to most hosts.

**Home Manager settings:**
- Backup file extension: `hm-backup` (handles file conflicts on rebuild)

**Conditional behavior:**
- VSCode config: h-tuf only
- OpenClaw config: h-tuf only (p-wsl: disabled due to WSL2 build issues)
- Desktop apps (telegram-desktop, fh): Excluded from h-fold41/h-fold42
- x86_64-only packages: codex-cli-nix, opencode-flake
- h-tuf/p-wsl specific: arduino-ide, inkscape, audacity
- nodejs_20: Excluded on h-tuf (OpenClaw provides its own Node.js)

**Key packages:**
- Development: git, gh, ripgrep, fd, nixfmt, python3, rustup, bun
- AI tools: gemini-cli, claude-code
- Editor: emacs30-pgtk with Chemacs2 (profiles: default, doom, vanilla)

**Programs configured:**
- **Direnv**: nix-direnv enabled
- **Starship**: Custom prompt (no newline, git branch styling)
- **Vim**: Default editor (tabstop: 2, clipboard: unnamedplus, mouse)
- **Tmux**: Plugins (catppuccin, resurrect, continuum), 100k history, mouse
- **Bash**: Bash completion DISABLED (prevents progcomp errors), aliases (ec, ll, glmcode), auto-tmux on login (except VSCode/nix-on-droid)

**Session variables:**
- CARGO_HOME, RUSTUP_HOME: `~/.cargo`, `~/.rustup`
- GEMINI_MODEL: `gemini-3-pro-preview`
- API keys loaded from `/run/secrets/` at shell init

**SSH config:**
- oci-arm: 193.123.224.61 (user: hwan, key: ~/.ssh/oci-arm)

**GLM model support:**
- Custom Claude settings via `~/.claude/settings-glm.json`
- Maps haiku → glm-4.5-air, sonnet → glm-4.7, opus → glm-4.7
- Access via `glmcode` alias (uses ZAI API endpoint)

**Exercism integration:**
- SOPS template creates `~/.config/exercism/user.json`
- Token from `sops.secrets.exercism-token`
- Workspace: `~/learn/Exercism`

### home/vscode.nix (h-tuf only)
- VIM mode with relative line numbers
- Tab size: 2, format on save
- Font: JetBrainsMono Nerd Font
- Theme: Dracula
- Extensions: VIM, Nix, Python, Rust, Go, GitLens, etc.

### home/openclaw.nix (h-tuf only)
OpenClaw AI assistant gateway configuration:
- **Integration**: nix-openclaw homeManagerModule
- **Documents**: `/home/hwan/code/openclaw-local/documents`
- **Plugins**: bundledPlugins (summarize, oracle)
- **SOPS**: Anthropic API key via sops template
- **Systemd service**: openclaw-gateway auto-starts on user login (WantedBy: default.target)
- **Telegram bot**: Configured for remote access (bot token: `~/.secrets/telegram-bot-token`)
- **Config**: Custom JSON at `~/.openclaw/my-config.json` (gateway auth token, Telegram settings)
- **Environment**: ANTHROPIC_API_KEY from sops, custom config path via OPENCLAW_CONFIG_PATH

## Secrets

Managed with **sops-nix** using age encryption.

**Age key location:** `~/.config/sops/age/keys.txt`

**secrets.yaml contents:**
- `oci-arm-key`: SSH private key for oci-arm
- `exercism-token`: Exercism API token
- `api-keys/google_cloud`: Google Cloud project credentials
- `api-keys/gemini`: Google Gemini API key
- `api-keys/anthropic`: Anthropic API key
- `api-keys/zai`: ZAI API key (custom endpoint)

**To edit secrets:**
```bash
sops secrets/secrets.yaml
```

## Management Commands

### Rebuilding

```bash
# NixOS hosts (h-tuf, p-wsl, oci-arm)
./rebuild.sh <hostname>
# or: sudo nixos-rebuild switch --flake ".#<hostname>" --impure

# nix-on-droid hosts (h-fold41, h-fold42)
nix-on-droid switch --flake ".#<hostname>"
```

### Other Commands

```bash
# Update flake inputs
nix flake update

# Garbage collection
nix-collect-garbage -d

# Verify syntax without applying
nixos-rebuild dry-build --flake ".#<hostname>"

# Format nix files (uses alejandra formatter)
nix fmt
```

## Development Environments (outsiders/)

### Python (outsiders/Python/)
```bash
cd outsiders/Python && nix develop
uv venv --python $(which python)
```

### Rust (outsiders/Rust/)
Uses Fenix for stable Rust toolchain with cargo-deny, cargo-edit, cargo-watch, rust-analyzer.

### OpenClaw (outsiders/openclaw/)
Setup documentation in `install.txt`:
1. Install Determinate Nix
2. Create ~/code/openclaw-local flake with documents directory
3. Create Telegram bot via @BotFather and get chat ID from @userinfobot
4. Set up secrets (bot token at `~/.secrets/telegram-bot-token`, Anthropic API key via sops)
5. Rebuild system configuration with `./rebuild.sh h-tuf`
6. Verify: openclaw-gateway service running, bot responds to messages

## Recent Changes

**Latest commits:**
- `75ba39c` (2026-02-13): Configure Anthropic API key via sops-nix for OpenClaw
- `ab76607`: Prevent sleep on lid close (h-tuf), repair openclaw-gateway config
- `ec60fff`: Add home-manager backupFileExtension ("hm-backup") for file conflicts
- `bfa48d2`: Enable auto-start of openclaw-gateway systemd service

## Development Guidelines

1. **User Packages**: Add to `home/default.nix` under `home.packages`
2. **System Packages**: Add to `modules/common.nix` under `environment.systemPackages`
3. **Host-Specifics**: Edit `hosts/<hostname>/default.nix`
4. **New Host**:
   - Create `hosts/<new-host>/` directory
   - Generate hardware config: `nixos-generate-config --show-hardware-config > hosts/<new-host>/hardware-configuration.nix`
   - Create `hosts/<new-host>/default.nix` importing hardware config
   - Add to `nixosConfigurations` in `flake.nix`

## Notes for Claude Code Agent

- **Read-First**: Always read `flake.nix` and `modules/common.nix` before sweeping changes
- **Respect Host Capabilities**:
  - Headless: oci-arm, h-fold41, h-fold42
  - No systemd: h-fold41, h-fold42
  - x86_64-only packages exist (check conditionals in home/default.nix)
- **Architecture-aware**: Some packages are x86_64-only (codex-cli-nix, opencode-flake)
- **Secrets Safety**: Cannot edit encrypted files directly; ask user to run `sops secrets/secrets.yaml`
- **Verification**: Run `nix fmt` (uses alejandra, not nixfmt) after editing .nix files; use `nixos-rebuild dry-build` to verify
- **h-pc Note**: Defined in flake.nix but not implemented (no hosts/h-pc/ directory exists)
- **h-tuf Specifics**:
  - Has OpenClaw integration with Telegram bot (openclaw-gateway service)
  - GLM models available via custom settings file (`~/.claude/settings-glm.json`)
  - Node.js excluded (OpenClaw provides its own)
  - Lid close ignored (prevents sleep)
- **Home Manager**: Uses "hm-backup" extension for file conflict handling
