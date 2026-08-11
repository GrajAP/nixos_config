{
  pkgs,
  config,
  lib,
  ...
}: let
  jarvisPython = pkgs.python3.withPackages (ps: [
    ps.opencv4
    ps.pillow
    ps.numpy
    ps.requests
    ps.faster-whisper
    ps.pyaudio
    ps.sounddevice
    ps.chromadb
    ps.psutil
    ps.pyyaml
    ps.aiohttp
    ps.websockets
    ps.silero-vad
    ps.beautifulsoup4
    ps.lxml
  ]);

  jarvisWrapper = pkgs.writeShellApplication {
    name = "jarvis";
    runtimeInputs = [
      jarvisPython
      pkgs.coreutils
      pkgs.pipewire
      pkgs.pulseaudio
      pkgs.alsa-utils
      pkgs.piper-tts
      pkgs.grim
      pkgs.ydotool
      pkgs.wtype
      pkgs.wl-clipboard
    ];
    text = ''
      export PYTHONPATH="/home/grajpap/dev/JARVIS:$PYTHONPATH"
      export PATH="${pkgs.pipewire}/bin:${pkgs.pulseaudio}/bin:$PATH"
      exec python3 /home/grajpap/dev/JARVIS/main.py "$@"
    '';
  };
in {
  options.services.jarvis = {
    enable = lib.mkEnableOption "JARVIS AI Assistant";

    user = lib.mkOption {
      type = lib.types.str;
      default = "grajpap";
      description = "User to run JARVIS as";
    };
  };

  config = lib.mkIf config.services.jarvis.enable {
    systemd.services.jarvis = {
      description = "JARVIS - Always-on AI Assistant";
      after = ["network.target" "ollama.service"];
      wants = ["ollama.service"];

      serviceConfig = {
        Type = "simple";
        User = config.services.jarvis.user;
        Group = "users";
        WorkingDirectory = "/home/grajpap/dev/JARVIS";
        ExecStart = "${jarvisWrapper}/bin/jarvis";
        Restart = "always";
        RestartSec = 10;

        SupplementaryGroups = ["audio" "video" "input" "libvirtd" "docker"];

        NoNewPrivileges = false;
        ProtectSystem = false;
        ProtectHome = false;

        LimitNOFILE = 65536;
        LimitNPROC = 4096;

        Environment = [
          "PYTHONPATH=/home/grajpap/dev/JARVIS"
          "JARVIS_CONFIG=/home/grajpap/dev/JARVIS/config/jarvis.yaml"
          "HOME=/home/grajpap"
          "USER=grajpap"
          "XDG_RUNTIME_DIR=/run/user/1000"
          "PIPEWIRE_RUNTIME_DIR=/run/user/1000"
          "PYTHONUNBUFFERED=1"
        ];
      };

      wantedBy = ["multi-user.target"];
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/jarvis 0755 grajpap users -"
      "d /var/lib/jarvis/chromadb 0755 grajpap users -"
      "d /var/lib/jarvis/vms 0755 grajpap users -"
      "d /tmp/jarvis 0755 grajpap users -"
      "d /tmp/jarvis/tts 0755 grajpap users -"
      "d /tmp/jarvis/frames 0755 grajpap users -"
      "d /tmp/jarvis/screenshots 0755 grajpap users -"
      "d /tmp/jarvis/browser 0755 grajpap users -"
    ];
  };
}
