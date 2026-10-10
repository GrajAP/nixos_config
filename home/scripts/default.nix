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
    (pkgs.writeShellApplication {
      name = "update-userstyles";
      runtimeInputs = with pkgs; [nix coreutils python3 gnugrep];
      text = builtins.readFile ./update-userstyles;
    })
    (pkgs.writeShellApplication {
      name = "eduroam";
      runtimeInputs = with pkgs; [networkmanager gnugrep gawk];
      text = builtins.readFile ./eduroam;
    })
    (pkgs.writeShellScriptBin "katana-switch" (builtins.readFile ./katana-switch))
    (pkgs.writeShellApplication {
      name = "herdr-launch";
      runtimeInputs = with pkgs; [coreutils gnugrep herdr libnotify];
      text = builtins.readFile ./herdr-launch;
    })
  ];
}
