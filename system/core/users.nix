{
  config,
  pkgs,
  ...
}: {
  programs.zsh.enable = true;
  users = {
    mutableUsers = true;
    users = {
      grajpap = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "docker"
          "systemd-journal"
          "audio"
          "plugdev"
          "storage"
          "video"
          "input"
          "networkmanager"
          "adbusers"
        ];
        uid = 1000;
        shell =
          if config.services.greetd.enable
          then pkgs.zsh
          else pkgs.bash;
      };
    };
  };
}
