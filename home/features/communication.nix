{
  pkgs,
  inputs,
  ...
}: {
  home.packages = with pkgs; [
    ferdium
    signal-desktop
    inputs.helium-browser.packages."${pkgs.stdenv.hostPlatform.system}".helium
  ];
}
