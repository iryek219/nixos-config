{ config, pkgs, inputs, ... }:

{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  home.stateVersion = "25.05";
  home.packages = with pkgs; [ 
                        julia
                        rustup
                        uv
                        nodejs_20  # pin version to avoid accidental upgrade
                        ripgrep
                        fd
			exercism 
			guile 
			age 
			sops 
                        gemini-cli
                        claude-code
		       ];

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

  # --- VSCode CONFIG ---
  programs.vscode = {
    enable = true;

    profiles.default = {
      userSettings = {
        "vscode-vim.enable" = true;
        "editor.lineNumbers" = "relative"; #VIM style
        "editor.renderWhitespace" = "all";
        "editor.tabSize" = 2;
        "editor.formatOnSave" = true;

        "workbench.colorTheme" = "Dracula Theme";
      };
      extensions = with pkgs.vscode-extensions; [
        vscodevim.vim
        bbenoist.nix               # Nix language
        mhutchie.git-graph         # Git visualization
        eamodio.gitlens            # Git Super-charged
        yzhang.markdown-all-in-one 

        ms-python.python
        ms-python.vscode-pylance

        elmtooling.elm-ls-vscode
        ms-vscode.cpptools
        rust-lang.rust-analyzer
        golang.go
        dbaeumer.vscode-eslint     # javascript/TypeScript linting
        esbenp.prettier-vscode

        dracula-theme.theme-dracula
      ];
    };
  };
  

  # --- EMACS CONFIG ---
  services.emacs.enable = true; 
  programs.emacs = {
    enable = true;
    #package = pkgs.emacs;       # defaults to GTK + X
    package = pkgs.emacs-nox;  # terminal
    extraPackages = epkgs: [ epkgs.geiser epkgs.paredit ];
    extraConfig = ''
      (add-hook 'emacs-lisp-mode-hook 'paredit-mode)
      (add-hook 'lisp-mode-hook 'paredit-mode)
      (add-hook 'scheme-mode-hook 'paredit-mode)
      (add-hook 'clojure-mode-hook 'paredit-mode)
      
      ;; Geiser Setup
      (setq geiser-default-implementations '((scheme . guile)))
      (add-hook 'scheme-mode-hook 'geiser-mode)
      (define-key geiser-mode-map (kbd "C-c C-r") 'geiser-restart)
    '';
  };

  # --- SHELL ALIASES ---
  programs.bash = {
    enable = true;
    shellAliases = {
      emacsnox = "emacs -nw";
      ec = "emacsclient -t -a \"\"";
      ll = "ls -alh";
      l = "ls -l";
    };
  };

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

  home.file.".ssh/config".text = ''
    Host oci-arm
      HostName 193.123.224.61
      User ubuntu
      IdentityFile ~/.ssh/oci-arm
      StrictHostKeyChecking accept-new
  '';

  home.file.".config/exercism/user.json".text =
   builtins.toJSON {
      apibaseurl = "https://api.exercism.org/v1";
      token = builtins.readFile config.sops.secrets.exercism-token.path;
      workspace = "${config.home.homeDirectory}/learn/Exercism";
    };

  home.sessionVariables = {
    CARGO_HOME = "$HOME/.cargo";
    RUSTUP_HOME = "$HOME/.rustup";

    GEMINI_MODEL = "gemini-2.5-pro";
    GEMINI_API_KEY = builtins.readFile "/run/secrets/api-keys/gemini";
    ANTHROPIC_API_KEY = builtins.readFile "/run/secrets/api-keys/anthropic";
    GOOGLE_CLOUD_PROJECT = builtins.readFile "/run/secrets/api-keys/google_cloud";
  };
}
