{
  config,
  pkgs,
  ...
}: let
  browser = ["helium.desktop"];
  mail = ["proton-mail.desktop"];
  heliumProfilePath = "${config.home.homeDirectory}/.config/net.imput.helium/Default";
  protonMailHandler = pkgs.writeShellApplication {
    name = "proton-mail-handler";
    runtimeInputs = [pkgs.jq];
    text = ''
      uri="''${1:-mailto:}"
      case "$uri" in
        mailto:*) ;;
        *)
          echo "proton-mail-handler: expected a mailto URI" >&2
          exit 2
          ;;
      esac

      encoded_uri="$(jq -nr --arg uri "$uri" '$uri | @uri')"
      exec helium \
        --profile-path="${heliumProfilePath}" \
        "https://mail.proton.me/inbox/#mailto=$encoded_uri"
    '';
  };

  associations = {
    "text/html" = browser;
    "x-scheme-handler/http" = browser;
    "x-scheme-handler/https" = browser;
    "x-scheme-handler/ftp" = browser;
    "x-scheme-handler/about" = browser;
    "x-scheme-handler/unknown" = browser;
    "application/x-extension-htm" = browser;
    "application/x-extension-html" = browser;
    "application/x-extension-shtml" = browser;
    "application/xhtml+xml" = browser;
    "application/x-extension-xhtml" = browser;
    "application/x-extension-xht" = browser;

    "audio/*" = ["mpv.desktop"];
    "video/*" = ["mpv.desktop"];
    "image/*" = ["imv.desktop"];
    "application/json" = browser;
    "application/pdf" = browser;

    "x-scheme-handler/mailto" = mail;
    "x-scheme-handler/protonpass" = ["proton-pass.desktop"];

    "inode/directory" = ["nemo.desktop"];
    "application/x-bittorrent" = ["org.qbittorrent.qBittorrent.desktop"];
    "x-scheme-handler/magnet" = ["org.qbittorrent.qBittorrent.desktop"];

    "application/msword" = ["writer.desktop"];
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = ["writer.desktop"];
    "application/vnd.ms-excel" = ["calc.desktop"];
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = ["calc.desktop"];
    "application/vnd.ms-powerpoint" = ["impress.desktop"];
    "application/vnd.openxmlformats-officedocument.presentationml.presentation" = ["impress.desktop"];
    "application/vnd.oasis.opendocument.text" = ["writer.desktop"];
    "application/vnd.oasis.opendocument.spreadsheet" = ["calc.desktop"];
    "application/vnd.oasis.opendocument.presentation" = ["impress.desktop"];
  };
in {
  xdg = {
    dataFile = {
      "applications/helium.desktop".text = ''
        [Desktop Entry]
        Name=Helium
        GenericName=Web Browser
        Comment=Privacy-focused web browser
        Exec=helium --profile-path="${heliumProfilePath}" %U
        Icon=helium
        Terminal=false
        Type=Application
        Categories=Network;WebBrowser;
        MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;
      '';
      # Proton's web app accepts the percent-encoded mailto URI in this URL's fragment.
      "applications/proton-mail.desktop".text = ''
        [Desktop Entry]
        Name=Proton Mail
        GenericName=Email Client
        Comment=Compose email with Proton Mail in Helium
        Exec=${protonMailHandler}/bin/proton-mail-handler %u
        Icon=helium
        Terminal=false
        Type=Application
        Categories=Network;Email;
        MimeType=x-scheme-handler/mailto;
      '';
    };
    userDirs = {
      enable = true;
      setSessionVariables = true;
      documents = "$HOME/other";
      download = "$HOME/download";

      music = "$HOME/music";
      pictures = "$HOME/pics";
      desktop = "$HOME/other";
      publicShare = "$HOME/other";
      templates = "$HOME/other";
    };
    mimeApps = {
      enable = true;
      associations.added = associations;
      defaultApplications = associations;
    };
  };
}
