{...}: {
  programs = {
    wlogout = {
      enable = true;
      layout = [
        {
          label = "lock";
          action = "hyprlock";
          text = "Lock (l)";
          keybind = "l";
        }
        {
          label = "hibernate";
          action = "systemctl hibernate";
          text = "Hibernate (k)";
          keybind = "k";
        }
        {
          label = "shutdown";
          action = "systemctl poweroff";
          text = "Shutdown (j)";
          keybind = "j";
        }
        {
          label = "reboot";
          action = "systemctl reboot";
          text = "Reboot (h)";
          keybind = "h";
        }
      ];
    };
    hyprlock = {
      enable = true;
    };
  };
}
