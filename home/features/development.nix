{
  pkgs,
  config,
  ...
}: let
  t3code = pkgs.callPackage ../../apps/t3code/package.nix {};
in {
  home = {
    packages = with pkgs; [
      electron
      postman
      github-desktop
      libreoffice-fresh
      nextcloud-client
      rnote
      pnpm
      bun
      antigravity
      t3code.desktop
      t3code.notify
      (pkgs.writeShellApplication {
        name = "install-js-clis";
        runtimeInputs = [pkgs.bun];
        text = ''
          set -euo pipefail

          mkdir -p "$HOME/.bun-global"
          bun install -g --prefix "$HOME/.bun-global" \
            @angular/cli \
            @expo/cli \
            vite \
            @react-native-community/cli \
            concurrently
        '';
      })
    ];

    sessionVariables.PATH = "${config.home.homeDirectory}/.bun-global/bin:$PATH";

    sessionPath = ["${config.home.homeDirectory}/.bun-global/bin"];
  };

  systemd.user = {
    services.t3code-update = {
      Unit.Description = "Download the newest T3 Code nightly desktop build";
      Service = {
        Type = "oneshot";
        ExecStart = "${t3code.update}/bin/t3code-update";
      };
    };
    timers.t3code-update = {
      Unit.Description = "Keep T3 Code on the latest nightly";
      Timer = {
        OnStartupSec = "2min";
        OnUnitActiveSec = "30min";
        Persistent = true;
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
