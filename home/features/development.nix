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
      antigravity
      github-desktop
      libreoffice-fresh
      nextcloud-client
      rnote
      pnpm
      bun
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
}
