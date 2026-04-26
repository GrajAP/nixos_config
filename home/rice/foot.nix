{pkgs, ...}: {
  programs.foot = {
    enable = true;
    server.enable = false;
    settings = {
      main = {
        app-id = "foot";
        title = "foot";
        locked-title = "no";
        term = "xterm-256color";
        vertical-letter-offset = "0";
        pad = "12x21 center";
        resize-delay-ms = 100;
        selection-target = "primary";
        box-drawings-uses-font-glyphs = "no";
        dpi-aware = "no";
        bold-text-in-bright = "no";
        word-delimiters = ",│`|:\"'()[]{}<>";
      };
      cursor = {
        style = "beam";
        beam-thickness = 2;
      };
      scrollback = {
        lines = 10000;
        multiplier = 3;
      };

      bell = {
        urgent = "yes";
        notify = "yes";
        command = "${pkgs.libnotify} 'bell'";
        command-focused = "no";
      };
      url = {
        launch = "xdg-open \${url}";
        label-letters = "sadfjklewcmpgh";
        osc8-underline = "url-mode";
      };
      mouse = {
        hide-when-typing = "yes";
      };
      key-bindings = {
        show-urls-launch = "Control+Shift+u";
        unicode-input = "Control+Shift+i";
      };

      search-bindings = {
        cursor-home = "Control+A";
      };
      mouse-bindings = {
        selection-override-modifiers = "Shift";
        primary-paste = "BTN_MIDDLE";
        select-begin = "BTN_LEFT";
        select-begin-block = "Control+BTN_LEFT";
        select-extend = "BTN_RIGHT";
        select-extend-character-wise = "Control+BTN_RIGHT";
        select-word = "BTN_LEFT-2";
        select-word-whitespace = "Control+BTN_LEFT-2";
        #select-row = "BTN_LEFT-3";
      };
    };
  };
}
