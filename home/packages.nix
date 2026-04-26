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
    pi-coding-agent
    nodejs
    bun
    (pkgs.writeShellApplication {
      name = "install-js-clis";
      runtimeInputs = [pkgs.nodejs];
      text = ''
        set -euo pipefail

        mkdir -p "$HOME/.npm-global"
        npm install -g --prefix "$HOME/.npm-global" \
          @angular/cli \
          @expo/cli \
          vite
          @react-native-community/cli \
          concurrently
      '';
    })
  ];

  home.sessionVariables.PATH = "${config.home.homeDirectory}/.npm-global/bin:$PATH";

  home.sessionPath = ["${config.home.homeDirectory}/.npm-global/bin"];
}
