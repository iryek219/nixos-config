{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.nix-openclaw.homeManagerModules.openclaw
  ];

  programs.openclaw = {
    # Path to managed documents directory
    documents = /home/hwan/code/openclaw-local/documents;

    config = {
      gateway = {
        mode = "local";
        auth = {
          # Gateway authentication token
          token = "xcV3qOFmoXlqU8rsIgimxfMwImFF9X4z";
        };
      };

      channels.telegram = {
        # Path to Telegram bot token file
        tokenFile = "/home/hwan/.secrets/telegram-bot-token";
        # Your Telegram user ID from @userinfobot
        allowFrom = [1078515864];
        groups = {
          "*" = {requireMention = true;};
        };
      };
    };

    instances.default = {
      enable = true;
      plugins = [];
    };

    # Enable first-party plugins
    firstParty = {
      summarize.enable = true;
      oracle.enable = true;
    };
  };

  # Add WantedBy to enable auto-start on login
  systemd.user.services.openclaw-gateway.Install.WantedBy = ["default.target"];
}
