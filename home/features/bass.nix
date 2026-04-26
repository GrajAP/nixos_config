{pkgs, ...}: {
  home.packages = with pkgs; [
    guitarix
    crosspipe
    calf
  ];
}
