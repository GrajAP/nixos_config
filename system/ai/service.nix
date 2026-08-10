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
  ]);
in {
  options.services.jarvis = {
    enable = lib.mkEnableOption "JARVIS AI Assistant";

    user = lib.mkOption {
      type = lib.types.str;
      default = "grajpap";
      description = "User to run JARVIS as";
    };

    projectDir = lib.mkOption {
      type = lib.types.path;
      default = /home/grajpap/dev/JARVIS;
      description = "Path to JARVIS project directory";
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
        WorkingDirectory = toString config.services.jarvis.projectDir;
        ExecStart = "${jarvisPython}/bin/python3 ${config.services.jarvis.projectDir}/main.py";
        Restart = "always";
        RestartSec = 10;

        SupplementaryGroups = ["audio" "video" "input" "libvirtd" "docker"];

        NoNewPrivileges = false;
        ProtectSystem = false;
        ProtectHome = false;

        LimitNOFILE = 65536;
        LimitNPROC = 4096;

        Environment = [
          "PYTHONPATH=${config.services.jarvis.projectDir}"
          "JARVIS_CONFIG=${config.services.jarvis.projectDir}/config/jarvis.yaml"
          "HOME=/home/${config.services.jarvis.user}"
          "USER=${config.services.jarvis.user}"
        ];
      };

      wantedBy = ["multi-user.target"];
    };

    systemd.tmpfiles.rules = [
      "d /mnt/HDD/jarvis 0755 grajpap users -"
      "d /mnt/HDD/jarvis/models 0755 grajpap users -"
      "d /mnt/HDD/jarvis/chromadb 0755 grajpap users -"
      "d /mnt/HDD/jarvis/vms 0755 grajpap users -"
      "d /tmp/jarvis 0755 grajpap users -"
      "d /tmp/jarvis/tts 0755 grajpap users -"
      "d /tmp/jarvis/frames 0755 grajpap users -"
    ];
  };
}
