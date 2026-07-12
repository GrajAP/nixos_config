{
  pkgs,
  inputs,
  ...
}: {
  home.packages = with pkgs; [
    ferdium
    proton-pass
    signal-desktop
    inputs.helium-browser.packages."${pkgs.stdenv.hostPlatform.system}".helium
  ];
}
