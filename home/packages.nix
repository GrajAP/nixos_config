{
  config,
  pkgs,
  ...
}: {
  nixpkgs.config.allowUnfree = true;
  home.packages = with pkgs; [
    qbittorrent
    electron
    udev
    nemo
    steam
    bun
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

  home.sessionVariables.PATH = "${config.home.homeDirectory}/.bun-global/bin:$PATH";

  home.sessionPath = ["${config.home.homeDirectory}/.bun-global/bin"];
}
