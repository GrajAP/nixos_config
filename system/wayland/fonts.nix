# {pkgs, ...}: {
#   fonts = {
#     packages = with pkgs; [
#       # --- UI ---------------------------------------------------------
#       inter # modern sans for desktop
#       noto-fonts-color-emoji
#       material-icons
#       material-design-icons
#       roboto
#       work-sans
#       comic-neue
#       source-sans
#       twemoji-color-font
#       comfortaa
#       inter
#       lato
#       lexend
#       jost
#       dejavu_fonts
#       noto-fonts
#       noto-fonts-cjk-sans
#       noto-fonts-color-emoji
#       # --- Coding -----------------------------------------------------
#       (nerd-fonts.jetbrains-mono.overrideAttrs {
#         # “big” variant = glyphs + ligatures
#         variant = "full";
#       })
#       # Extra coding font (optional)
#       nerd-fonts.fira-code
#     ];
#     enableDefaultPackages = false;
#     fontconfig = {
#       defaultFonts = {
#         monospace = [
#           "JetBrainsMono Nerd Font"
#           "JetBrainsMono"
#           "Noto Color Emoji"
#         ];
#         sansSerif = ["Inter" "Noto Color Emoji"];
#         serif = ["Noto Serif" "Noto Color Emoji"];
#         emoji = ["Noto Color Emoji"];
#       };
#     };
#   };
# }
{pkgs, ...}: let
  inherit (builtins) attrValues;
in {
  environment.sessionVariables.FREETYPE_PROPERTIES = "cff:no-stem-darkening=0 autofitter:no-stem-darkening=0";
  fonts = {
    packages =
      attrValues {
        inherit
          (pkgs)
          material-icons
          material-design-icons
          roboto
          roboto-mono
          roboto-slab
          roboto-serif
          work-sans
          comic-neue
          source-sans
          twemoji-color-font
          comfortaa
          inter
          lato
          lexend
          jost
          dejavu_fonts
          noto-fonts
          noto-fonts-cjk-sans
          noto-fonts-color-emoji
          ;
      }
      ++ [
        pkgs.nerd-fonts.jetbrains-mono
        pkgs.maple-mono.NF
      ];

    enableDefaultPackages = false;

    # this fixes emoji stuff
    fontconfig = {
      defaultFonts = {
        monospace = [
          "Maple Mono NF"
          "Noto Color Emoji"
        ];
        sansSerif = [
          "Lexend"
          "Noto Color Emoji"
        ];
        serif = [
          "Noto Serif"
          "Noto Color Emoji"
        ];
        emoji = ["Noto Color Emoji"];
      };
    };
  };
}
