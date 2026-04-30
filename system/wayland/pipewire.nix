{...}: {
  hardware = {
    enableAllFirmware = true;
  };
  services = {
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      wireplumber = {
        enable = true;
        extraConfig = {
          "60-ee-default-source" = {
            "monitor.alsa" = [
              {
                matches = [{node.name = "easyeffects_source";}];
                actions = {
                  update-props = {
                    "session.priority" = 99;
                  };
                };
              }
            ];
          };
        };
      };
      pulse. enable = true;
      jack.enable = true;
    };
    pulseaudio.support32Bit = true;
  };
}
