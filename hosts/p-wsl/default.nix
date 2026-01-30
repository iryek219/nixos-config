{
  config,
  pkgs,
  ...
}: {
  system.stateVersion = "25.05";
  system.adminUser = "hwan";
  networking.hostName = "p-wsl";

  users.users.hwan = {
    extraGroups = ["dialout" "uucp"];
  };

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];

  fonts.fontconfig = {
    defaultFonts = {
      serif = ["Noto Serif CJK KR" "Noto Serif"];
      sansSerif = ["Noto Sans CJK KR" "Noto Sans"];
      monospace = ["Noto Sans Mono CJK KR" "Noto Sans Mono"];
      emoji = ["Noto Color Emoji"];
    };
  };
}
