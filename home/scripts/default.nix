{pkgs, ...}: {
  home.packages = [
    (pkgs.writeShellApplication {
      name = "bcn";
      runtimeInputs = with pkgs; [bluez coreutils fuzzel gawk libnotify gnused];
      text = builtins.readFile ./bcn;
    })
    (pkgs.writeShellApplication {
      name = "loc";
      runtimeInputs = [pkgs.tokei];
      text = builtins.readFile ./loc;
    })
    (pkgs.writeShellScriptBin "katana-switch" (builtins.readFile ./katana-switch))
  ];
}
