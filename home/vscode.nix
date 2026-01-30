{pkgs, ...}: {
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
        "editor.fontFamily" = "JetBrainsMono Nerd Font";
        "terminal.integrated.fontFamily" = "JetBrainsMono Nerd Font";

        "workbench.colorTheme" = "Dracula Theme";
      };
      extensions = with pkgs.vscode-extensions; [
        vscodevim.vim
        bbenoist.nix # Nix language
        mhutchie.git-graph # Git visualization
        eamodio.gitlens # Git Super-charged
        yzhang.markdown-all-in-one

        ms-python.python
        ms-python.vscode-pylance

        elmtooling.elm-ls-vscode
        ms-vscode.cpptools
        rust-lang.rust-analyzer
        golang.go
        dbaeumer.vscode-eslint # javascript/TypeScript linting
        esbenp.prettier-vscode

        dracula-theme.theme-dracula
      ];
    };
  };
}
