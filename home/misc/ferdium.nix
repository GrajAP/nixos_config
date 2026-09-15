{lib, ...}: let
  discordDarkmodeCss = ./ferdium-discord-darkmode.css;
  gmailDarkmodeCss = ./ferdium-gmail-darkmode.css;
in {
  home.activation.ferdiumCatppuccin = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Ferdium syncs recipes on startup and overwrites darkmode.css files.
    # Re-inject catppuccin CSS into recipe darkmode.css so Ferdium loads it
    # when dark mode is enabled. Must be re-run after Ferdium updates recipes.
    recipes_dir="$HOME/.config/Ferdium/recipes"

    inject_catppuccin() {
      recipe_dir="$recipes_dir/$1"
      css_file="$2"
      if [ -d "$recipe_dir" ] && [ -f "$css_file" ]; then
        mkdir -p "$recipe_dir"
        cp "$css_file" "$recipe_dir/darkmode.css"
      fi
    }

    inject_catppuccin discord ${discordDarkmodeCss}
    inject_catppuccin gmail ${gmailDarkmodeCss}
  '';
}
