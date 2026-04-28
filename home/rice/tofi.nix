{
  pkgs,
  config,
  ...
}: {
  home.packages = [pkgs.tofi pkgs.qalculate-gtk];
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
    corner-radius = 10
    border-width = 2
    padding = 14,18
    margin = 18
    min-input-width = 120
    background-color = ${config.lib.stylix.colors.withHashtag.base00}ee
    border-color = ${config.lib.stylix.colors.withHashtag.base0D}
    text-color = ${config.lib.stylix.colors.withHashtag.base05}
    selection-color = ${config.lib.stylix.colors.withHashtag.base05}
    selection-background = ${config.lib.stylix.colors.withHashtag.base0D}33
    drun-launch = true
    math-backend = qalc
    enable-calculation = true
  '';
}
