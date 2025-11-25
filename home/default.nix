{ config, pkgs, inputs, ... }:

{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  home.stateVersion = "25.05";
  home.packages = with pkgs; [ 
			exercism 
			guile 
			age 
			sops 
		       ];

  # --- EMACS CONFIG ---
  services.emacs.enable = true; 
  programs.emacs = {
    enable = true;
    package = pkgs.emacs;
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
    };
    
    secrets.exercism-token = {
      path = "${config.home.homeDirectory}/.secrets/exercism";
    };
  };

  home.file.".ssh/config".text = ''
    Host oci-arm
      HostName 193.123.224.61
      User ubuntu
      IdentityFile ~/.ssh/oci-arm
      StrictHostKeyChecking accept-new
  '';

  home.file.".config/exercism/user.json".text = ''
    {
      "apibaseurl": "https://api.exercism.org/v1",
      "token": "$(cat ${config.sops.secrets.exercism-token.path})",
      "workspace": "/home/hwan/learn/Exercism"
    }
  '';
}
