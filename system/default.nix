{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    (discord.override {
      withVencord = true;
    })
  ];
  imports = [
    ./wayland
    ./core
    ./mobile
  ];
}
