{
  programs.satty = {
    enable = true;
    settings = {
      general = {
        fullscreen = false;
        early-exit = true;
        corner-roundness = 12;
        initial-tool = "brush";
        copy-command = "wl-copy";
        annotation-size-factor = 2;
        output-filename = "~/pics/screenshot-%Y-%m-%d_%H:%M:%S.png";
        save-after-copy = true;
        actions-on-enter = ["save-to-file" "exit"];
        actions-on-escape = ["exit"];
        no-window-decoration = true;
        brush-smooth-history-size = 10;
      };
      font = {
        family = "Roboto";
        style = "Regular";
      };
      color-palette = {
        palette = [
          "#00ffff"
          "#a52a2a"
          "#dc143c"
          "#ff1493"
          "#ffd700"
          "#008000"
        ];
      };
    };
  };
}
