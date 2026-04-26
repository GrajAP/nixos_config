{
  pkgs,
  config,
  inputs,
  ...
}: {
  home.packages = [
    inputs.anyrun.packages.${pkgs.stdenv.system}.anyrun-with-all-plugins
  ];

  xdg.configFile."anyrun/config.ron".text = ''
    Config(
      x: Fraction(0.5),
      y: Fraction(0.02),
      width: Absolute(800),
      height: Absolute(1),
      hide_icons: false,
      ignore_exclusive_zones: false,
      layer: Top,
      hide_plugin_info: false,
      close_on_click: true,
      show_results_immediately: true,
      max_entries: None,
      plugins: [
        "libapplications.so",
        "libactions.so",
        #"libwebsearch.so", # slow - causes hang
        "librink.so",
        "libkidex.so",
        #"libshell.so", # can be slow
        "libtranslate.so",
        "libnix_run.so",
        "librandr.so",
      ],
    )
  '';

  xdg.configFile."anyrun/websearch.ron".text = ''
    Config(
      prefix: "",
      engines: [
        DuckDuckGo,
        Custom(
          name: "YouTube",
          url: "youtube.com/results?search_query={}",
        ),
        Custom(
          name: "ChatGPT",
          url: "chat.openai.com/?q={}",
        ),
        Custom(
          name: "Claude",
          url: "claude.ai/search?q={}",
        ),
        Custom(
          name: "Perplexity",
          url: "perplexity.ai/?q={}",
        ),
        Custom(
          name: "Gemini",
          url: "gemini.google.com/chat?q={}",
        ),
        Custom(
          name: "T3 Chat",
          url: "t3.chat/new?q={}",
        ),
      ],
    )
  '';

  xdg.configFile."anyrun/rink.ron".text = ''
    Config(
      prefix: "",
    )
  '';

  xdg.configFile."anyrun/kidex.ron".text = ''
    Config(
      prefix: "/",
    )
  '';

  xdg.configFile."anyrun/style.css".text = ''
    @define-color accent ${config.lib.stylix.colors.withHashtag.base0D};
    @define-color bg ${config.lib.stylix.colors.withHashtag.base00};
    @define-color fg ${config.lib.stylix.colors.withHashtag.base05};
    @define-color border ${config.lib.stylix.colors.withHashtag.base0D};
    @define-color highlight ${config.lib.stylix.colors.withHashtag.base01};

    window {
      background: transparent;
    }

    box.main {
      padding: 0px 0 8px 0;
      margin: 0px 12px 12px 12px;
      border-radius: 14px;
      border: 2px solid @border;
      background-color: ${config.lib.stylix.colors.withHashtag.base00}ee;
    }

    text {
      min-height: 28px;
      padding: 0px 12px 8px 12px;
      border-radius: 8px;
      color: @fg;
      font-family: "JetBrains Mono Nerd Font", "JetBrains Mono", monospace;
      font-size: 13px;
      caret-color: @accent;
    }

    text:focus {
      border: 1px solid @accent;
    }

    box.plugin.info {
      min-width: 200px;
      padding: 4px 8px;
      margin-bottom: 4px;
    }

    label.plugin.info {
      font-size: 9px;
      font-weight: 600;
      color: @accent;
      text-transform: uppercase;
      letter-spacing: 0.8px;
    }

    list.plugin {
      background-color: transparent;
    }

    box.match {
      margin: 2px 4px;
      border-radius: 6px;
    }

    box.match:hover {
      background-color: ${config.lib.stylix.colors.withHashtag.base01}40;
    }

    label.match {
      color: @fg;
      padding: 6px 10px;
      font-size: 12px;
    }

    label.match.description {
      font-size: 10px;
      color: @dim;
    }

    .match {
      background: transparent;
      border-radius: 6px;
    }

    .match:selected {
      border-left: 3px solid @accent;
      background-color: @highlight;
    }

    box.plugin:first-child {
      margin-top: 6px;
    }

    scrollbar {
      background-color: transparent;
      width: 6px;
    }

    scrollbar slider {
      background-color: @dim;
      border-radius: 3px;
    }

    scrollbar slider:hover {
      background-color: @accent;
    }
  '';
}
