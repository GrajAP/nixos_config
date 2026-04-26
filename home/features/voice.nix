{pkgs, ...}: let
  lib = pkgs.lib;
  whisperPython = pkgs.python3.withPackages (ps: [
    ps.faster-whisper
    ps.pygobject3
    ps.sounddevice
  ]);
  whisperRecord = pkgs.writeShellApplication {
    name = "whisper-record-v2";
    excludeShellChecks = ["SC2016"];
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gdk-pixbuf
      glib
      gnugrep
      gnused
      gtk3
      hyprland
      libnotify
      pango
      pipewire
      procps
      pulseaudio
      systemd
      wl-clipboard
      wtype
      yad
      ydotool
      whisperPython
    ];
    text =
      ''
        export GI_TYPELIB_PATH="${lib.makeSearchPath "lib/girepository-1.0" [
          pkgs.gtk3
          pkgs.glib
          pkgs.gdk-pixbuf
          pkgs.pango
          pkgs.harfbuzz
        ]}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
        export XDG_DATA_DIRS="${lib.makeSearchPath "share" [
          pkgs.gtk3
          pkgs.gsettings-desktop-schemas
          pkgs.hicolor-icon-theme
          pkgs.adwaita-icon-theme
        ]}''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
      ''
      + builtins.readFile ../scripts/whisper-record-v2;
  };
in {
  home.packages = [
    whisperRecord
    (pkgs.writeShellScriptBin "whisper-python" ''
      exec ${whisperPython}/bin/python3 "$@"
    '')
  ];
}
