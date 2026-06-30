{config, ...}: let
  browser = ["helium.desktop"];
  heliumProfilePath = "${config.home.homeDirectory}/.config/net.imput.helium/Default";

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
    "video/*" = ["mpv.dekstop"];
    "image/*" = ["imv.desktop"];
    "application/json" = browser;
    "application/pdf" = ["org.pwmt.zathura.desktop.desktop"];
  };
in {
  xdg.configFile."applications/helium.desktop".text = ''
    [Desktop Entry]
    Name=Helium
    GenericName=Web Browser
    Comment=Privacy-focused web browser
    Exec=helium --profile-path="${heliumProfilePath}"
    Terminal=false
    Type=Application
    Categories=Network;WebBrowser;
    MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;
  '';

  xdg = {
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
    mimeApps.enable = true;
    mimeApps.associations.added = associations;
    mimeApps.defaultApplications = associations;
  };
}
