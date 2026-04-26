{
  lib,
  pkgs,
  ...
}: {
  xdg.configFile."Ferdium/recipes/gmail/index.js" = {
    force = true;
    text = ''
      module.exports = Ferdium =>
        class Gmail extends Ferdium {
          overrideUserAgent() {
            return window.navigator.userAgent
              .replaceAll(/(Ferdium|Electron)\/\S+ \([^)]+\)/g, "")
              .trim();
          }
        };
    '';
  };

  home.sessionVariables = {
    ELECTRON_EXTRA_LAUNCH_ARGS = "--disable-gpu=1";
  };
}
