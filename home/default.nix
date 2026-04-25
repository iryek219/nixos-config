{
  config,
  pkgs,
  inputs,
  hostname,
  ...
}: {
  imports =
    [
      inputs.sops-nix.homeManagerModules.sops
    ]
    ++ (
      if builtins.elem hostname ["h-tuf"]
      then [./vscode.nix]
      else []
    );

  home.stateVersion = "25.05";
  home.packages = with pkgs;
    [
      git
      gh
      ripgrep
      fd
      psmisc    # This provides 'fuser'
      lsof


      guile
      nerd-fonts.jetbrains-mono # font for emacs in WSL2
      adwaita-icon-theme # for emacs cursor in WSL2

      python3
      ruff # fask linter/formatter replacing flake8/black/isort
      #black            # alternative
      pyright # python LSP server
      nixfmt # Nix formatter

      nodejs_20

      #julia
      rustup
      rustlings
      bun
      exercism
      age
      sops
      gemini-cli
      claude-code
      arduino-cli

      # hledger - plain text accounting
      hledger
      hledger-ui
      hledger-web
      (writeShellScriptBin "doom" "CHEMACS_PROFILE=doom exec ${pkgs.emacs30-pgtk}/bin/emacs \"$@\"")
      (writeShellScriptBin "emacs-nox" "CHEMACS_PROFILE=vanilla exec ${pkgs.emacs30-pgtk}/bin/emacs -nw \"$@\"")
      (writeShellScriptBin "doom-nox" "CHEMACS_PROFILE=doom exec ${pkgs.emacs30-pgtk}/bin/emacs -nw \"$@\"")
    ]
    ++ (
      if ! (builtins.elem hostname ["h-fold41" "h-fold42"])
      then [
        fh
        telegram-desktop
      ]
      else []
    )
    ++ (
      if pkgs.system == "x86_64-linux"
      then [
        inputs.codex-cli-nix.packages.${pkgs.system}.default
        inputs.opencode-flake.packages.${pkgs.system}.default
      ]
      else []
    )
    ++ (
      if builtins.elem hostname ["h-tuf" "p-wsl"]
      then [
        arduino-ide
        inkscape
        audacity
      ]
      else []
    );

  fonts.fontconfig.enable = true; # Doom Emacs (Optional)

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.starship = {
    enable = true;
    
    # Optional: Customize the look (presets available online)
    settings = {
      add_newline = false; # Don't print a new line at the start
      
      # Example: Tweaking the git module to show the branch in green
      git_branch = {
        style = "bold #ff9900";
        symbol = "🌱 ";
      };
    };
  };

  # --- VIM CONFIG ---
  programs.vim = {
    enable = true;
    defaultEditor = true;
    #package = pkgs.vim;
    settings = {
      tabstop = 2;
      shiftwidth = 2;
      expandtab = true;
    };
    extraConfig = ''
      set clipboard=unnamedplus
      set number
      set mouse=a
    '';
  };

  # --- EMACS CONFIG ---
  services.emacs.enable = false;
  programs.emacs = {
    enable = true;
    #package = pkgs.emacs;       # defaults to GTK + X
    #package = pkgs.emacs-nox;  # terminal
    # Doom Emacs 성능을 위해 native-comp 기능이 있는 버전 추천
    # nox를 원하면 pkgs.emacs30-nox 등을 써도 되지만, Doom은 기본 패키지를 더 권장
    package = pkgs.emacs30-pgtk;
    # 중요: extraConfig와 extraPackages는 모두 삭제
    # 설정 관리는 Chemacs2와 각 Emacs 프로필이 담당
  };

  programs.tmux = {
    enable = true;
    shell = "${pkgs.bash}/bin/bash";
    terminal = "screen-256color";
    historyLimit = 100000;
    plugins = with pkgs; [
      tmuxPlugins.better-mouse-mode
      tmuxPlugins.catppuccin
      {
        plugin = tmuxPlugins.resurrect;
        extraConfig = "set -g @resurrect-strategy-nvim 'session'";
      }
      {
        plugin = tmuxPlugins.continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '60' # minutes
        '';
      }
    ];
    extraConfig = ''
      set -g mouse on
      set -g automatic-rename off
      set -g allow-rename off
      # bind  c  new-window      -c "#{pane_current_path}"
      # bind  %  split-window -h -c "#{pane_current_path}"
      # bind '"' split-window -v -c "#{pane_current_path}"
    '';
  };

  # --- SHELL ALIASES ---
  programs.bash = {
    enable = true;
    enableCompletion = false;
    shellAliases = {
      # 프로필별 실행 명령어

      ec = "emacsclient -t -a \"\"";
      ll = "ls -alh";
      l = "ls -l";
      glmcode = "ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic ANTHROPIC_AUTH_TOKEN=$(cat \"/run/secrets/api-keys/zai\") API_TIMEOUT_MS=3000000 claude --settings $HOME/.claude/settings-glm.json";
    };
  };

  # Chemacs2 프로필 설정 파일 생성 (Nix로 관리하면 편합니다)
  home.file.".emacs-profiles.el".text = ''
    (
     ("default" . ((user-emacs-directory . "~/.emacs-configs/vanilla-emacs")))
     ("doom"    . ((user-emacs-directory . "~/.emacs-configs/doom-emacs")
                   (env . (("DOOMDIR" . "~/.config/doom")))))
     ("vanilla" . ((user-emacs-directory . "~/.emacs-configs/vanilla-emacs")))
    )
  '';

  # Chemacs2 installation
  home.file.".emacs.d".source = "${pkgs.chemacs2}/share/site-lisp/chemacs2";

  # No escape sequence with arrow keys in Guile repl
  home.file.".guile".text = ''
    (use-modules (ice-9 readline))
    (activate-readline)
  '';

  home.file.".ssh/config".text = ''
    Host oci-arm
      HostName 193.123.224.61
      User hwan
      IdentityFile ~/.ssh/oci-arm
      StrictHostKeyChecking accept-new
  '';

  home.file.".claude/settings-glm.json".text = ''
    {
      "env": {
        "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.5-air",
        "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.7",
        "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-4.7"
      }
    }
  '';

  #home.file.".config/exercism/user.json".text =
  # builtins.toJSON {
  #    apibaseurl = "https://api.exercism.org/v1";
  #    token = builtins.readFile config.sops.secrets.exercism-token.path;
  #    workspace = "${config.home.homeDirectory}/learn/Exercism";
  #  };

  # --- SECRETS (SOPS) ---
  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = ../secrets/secrets.yaml;

    secrets.oci-arm-key = {
      path = "${config.home.homeDirectory}/.ssh/oci-arm";
      mode = "0400";
    };

    secrets.exercism-token = {
      path = "${config.home.homeDirectory}/.secrets/exercism";
      mode = "0400";
    };
  };

  sops.templates."exercism-user.json" = {
    # Where the resulting config file should be placed
    path = "${config.home.homeDirectory}/.config/exercism/user.json";

    # The content of the file.
    # sops-nix will replace the placeholder with the actual secret at runtime.
    content = builtins.toJSON {
      apibaseurl = "https://api.exercism.org/v1";
      token = config.sops.placeholder.exercism-token;
      workspace = "${config.home.homeDirectory}/learn/Exercism";
    };
  };

  home.sessionVariables = {
    CARGO_HOME = "$HOME/.cargo";
    RUSTUP_HOME = "$HOME/.rustup";
    GEMINI_MODEL = "gemini-3-pro-preview";
  };

  programs.bash.initExtra = ''
    if [ -f "/run/secrets/api-keys/gemini" ]; then
      export GEMINI_API_KEY=$(cat "/run/secrets/api-keys/gemini")
    fi
    if [ -f "/run/secrets/api-keys/google_cloud" ]; then
      export GOOGLE_CLOUD_PROJECT=$(cat "/run/secrets/api-keys/google_cloud")
    fi
    if [ -f "/run/secrets/api-keys/anthropic" ]; then
      export ANTHROPIC_API_KEY=$(cat "/run/secrets/api-keys/anthropic")
    fi
    if [ -f "/run/secrets/api-keys/zai" ]; then
      export ZAI_API_KEY=$(cat "/run/secrets/api-keys/zai")
    fi

    # Auto-start logic
    if [[ $- == *i* ]] && [[ -z "$TMUX" ]] && [[ "$TERM_PROGRAM" != "vscode" ]]; then
      ${if builtins.elem hostname ["h-fold41" "h-fold42"]
        then "cd ~/.config/nix-on-droid 2>/dev/null || true"
        else "cd ~/etc/nixos 2>/dev/null || cd /etc/nixos 2>/dev/null || true"}

      if command -v tmux &> /dev/null; then
        tmux new-session -A -s main
      fi
    fi
  '';
}
