{pkgs, ...}: {
  home.packages = with pkgs; [
    udev
    nemo
    easyeffects
    rnnoise-plugin
    rnnoise
    krita

    # AI coding harnesses
    aider-chat
    gemini-cli
    cc-switch
    antigravity-cli

    # Hyprland's Home Manager package places its portal descriptor in the
    # user profile, which takes precedence over the system portal directory.
    # Keep GTK's descriptor beside it so file chooser requests can be routed.
    xdg-desktop-portal-gtk
  ];
}
