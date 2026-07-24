{pkgs, ...}: let
  presenceNotifier = pkgs.callPackage ../../apps/presence-notifier/package.nix {};
in {
  home.packages = [presenceNotifier];

  xdg.configFile."presence-notifier/secrets.env.example".text = ''
    # Token bota, nigdy token prywatnego konta Discord.
    DISCORD_BOT_TOKEN=
    # Opcjonalnie ogranicza obserwację do jednego serwera. Puste oznacza
    # wszystkie serwery współdzielone z obserwowaną osobą.
    DISCORD_GUILD_ID=
    DISCORD_PRESENCE_USER_ID=
    DISCORD_PRESENCE_LABEL=orixx10
    # Opcjonalnie inny odbiorca. Puste oznacza obserwowaną osobę.
    DISCORD_PRESENCE_RECIPIENT_ID=

    STEAM_WEB_API_KEY=
    # Zalecany 64-bitowy Steam ID:
    STEAM_USER_ID=
    # Alternatywnie nazwa występująca w /id/nazwa w adresie profilu:
    STEAM_VANITY_NAME=Mikuskins
    STEAM_LABEL=Mikuskins
    # Discord ID osoby znanej na Steam jako Mikuskins.
    STEAM_DISCORD_RECIPIENT_ID=

    MESSAGE_TEXT=gramy?
    MESSAGE_COOLDOWN_SECONDS=21600
    STEAM_POLL_SECONDS=60
    DRY_RUN=false
  '';

  systemd.user.services.presence-notifier = {
    Unit = {
      Description = "Discord and Steam presence notifier";
      Documentation = "file://${presenceNotifier}/share/presence-notifier/README.md";
      Wants = ["network-online.target"];
      After = [
        "network-online.target"
        "graphical-session.target"
      ];
      PartOf = ["graphical-session.target"];
      ConditionPathExists = "%h/.config/presence-notifier/secrets.env";
    };
    Service = {
      Type = "simple";
      ExecStart = "${presenceNotifier}/bin/presence-notifier";
      EnvironmentFile = "%h/.config/presence-notifier/secrets.env";
      Restart = "on-failure";
      RestartSec = 10;
      StateDirectory = "presence-notifier";
      StateDirectoryMode = "0700";
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
    };
    Install.WantedBy = ["graphical-session.target"];
  };
}
