{
  pkgs,
  config,
  ...
}: {
  home.packages = [pkgs.tofi];
  xdg.configFile."tofi/config".text = ''
    anchor = center
    width = 360
    height = 120
    horizontal = false
    font-size = 11
    prompt-text = "Run "
    font = monospace
    ascii-input = false
    late-keyboard-init = true
    result-spacing = 6
    corner-radius = 14
    border-width = 2
    outline-width = 2
    padding-top = 14
    padding-bottom = 14
    padding-left = 18
    padding-right = 14
    selection-background-corner-radius = 10
    selection-background-padding = 5,6
    min-input-width = 120
    outline-color = ${config.lib.stylix.colors.withHashtag.base0D}
    border-color = ${config.lib.stylix.colors.withHashtag.base0D}
    background-color = ${config.lib.stylix.colors.withHashtag.base00}ee
    text-color = ${config.lib.stylix.colors.withHashtag.base05}
    selection-color = ${config.lib.stylix.colors.withHashtag.base05}
    selection-background = ${config.lib.stylix.colors.withHashtag.base0D}33
  '';
}