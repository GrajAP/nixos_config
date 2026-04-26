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
          "gitea"
          "docker"
          "systemd-journal"
          "vboxusers"
          "audio"
          "plugdev"
          "storage"
          "disk"
          "wireshark"
          "video"
          "input"
          "lp"
          "networkmanager"
          "power"
          "nix"
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
