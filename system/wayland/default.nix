{pkgs, ...}: {
  imports = [./fonts.nix ./kanata.nix ./pipewire.nix ./services.nix];
  environment.etc."greetd/environments".text = ''
    Hyprland (UWSM)
  '';

  environment = {
    variables = {
      _JAVA_AWT_WM_NONEREPARENTING = "1";
      GDK_BACKEND = "wayland,x11";
      ANKI_WAYLAND = "1";
      DIRENV_LOG_FORMAT = "";
      QT_AUTO_SCREEN_SCALE_FACTOR = "1";
      QT_QPA_PLATFORM = "wayland;xcb";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      MOZ_ENABLE_WAYLAND = "1";
      XDG_SESSION_TYPE = "wayland";
      SDL_VIDEODRIVER = "wayland";
      CLUTTER_BACKEND = "wayland";
    };
  };
  xdg.portal = {
    enable = true;
    config.common.default = ["hyprland" "gtk"];
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
    ];
  };
  programs.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    withUWSM = true;
  };
}
