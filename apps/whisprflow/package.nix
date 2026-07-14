{
  lib,
  pkgs,
}: let
  whisperPython = pkgs.python3.withPackages (ps: [
    ps.faster-whisper
  ]);
  whisprflow = pkgs.writeShellApplication {
    name = "whisprflow";
    excludeShellChecks = ["SC2016"];
    runtimeInputs = with pkgs; [
      alsa-utils
      coreutils
      findutils
      gawk
      gdk-pixbuf
      glib
      gnugrep
      gnused
      gtk3
      hyprland
      jq
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
      + builtins.readFile ./whisprflow;
  };
in
  pkgs.symlinkJoin {
    name = "whisprflow-cli-0.1.0";
    paths = [whisprflow];
    postBuild = ''
      ln -s whisprflow "$out/bin/whisper-record-v2"
    '';
    meta = {
      description = "Push-to-talk local Whisper dictation with review and correction learning";
      homepage = "https://github.com/grajpap/nixos_config";
      license = lib.licenses.mit;
      mainProgram = "whisprflow";
      platforms = lib.platforms.linux;
    };
  }
