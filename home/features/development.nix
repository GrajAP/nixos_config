{
  pkgs,
  config,
  ...
}: {
  home = {
    packages = with pkgs; [
      electron
      postman
      libreoffice-stable
      nextcloud-client
      rnote
      pnpm
      bun
      antigravity-ide
      opencode
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
}
