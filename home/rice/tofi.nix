{
  pkgs,
  config,
  ...
}: {
  home.packages = [pkgs.tofi];
  xdg.configFile."tofi/config".text = ''
    anchor = center
    width = 360
    height = 300
    horizontal = false
    font-size = 11
    prompt-text = "Run "
    font = JetBrainsMono Nerd Font
    ascii-input = false
    late-keyboard-init = true
    result-spacing = 6
    corner-radius = 14
    border-width = 2
    padding-top = 14
    padding-bottom = 14
    padding-left = 18
    padding-right = 14
    selection-background-corner-radius = 10
    selection-background-padding = 5,6
    min-input-width = 120
    background-color = ${config.lib.stylix.colors.withHashtag.base00}ee
    border-color = ${config.lib.stylix.colors.withHashtag.base0D}
    text-color = ${config.lib.stylix.colors.withHashtag.base05}
    selection-color = ${config.lib.stylix.colors.withHashtag.base05}
    selection-background = ${config.lib.stylix.colors.withHashtag.base0D}33
    drun-launch = true
  '';
}
