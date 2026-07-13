{pkgs, ...}: {
  home.packages = [
    (pkgs.writeShellApplication {
      name = "bcn";
      runtimeInputs = with pkgs; [bluez coreutils fuzzel gawk libnotify gnused];
      text = builtins.readFile ./bcn;
    })
    (pkgs.writeShellScriptBin "katana-switch" (builtins.readFile ./katana-switch))
  ];
}
