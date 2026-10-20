{pkgs, ...}: let
  whisprflow = pkgs.callPackage ../../apps/whisprflow/package.nix {};
  spark-corrector = pkgs.callPackage ../../apps/spark-corrector/package.nix {};
in {
  home.packages = [
    whisprflow
    spark-corrector
  ];

  systemd.user.services.whisprflow-serve = {
    Unit = {
      Description = "WhisprFlow resident Whisper ASR daemon";
      After = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${whisprflow}/bin/whisprflow-serve";
      Environment = [
        "WHISPR_SERVE_SOCK=%t/whisper-record-v2/serve.sock"
        "WHISPER_MODEL=large-v3-turbo"
        "WHISPER_BEAM_SIZE=5"
        "WHISPER_DUAL=1"
        "WHISPER_MIN_SCORE=-0.47"
        "WHISPER_VAD=1"
        "WHISPER_LANGS=pl,en"
        "WHISPER_LOG_PATH=%h/.local/share/whisper-record-v2/whisper.log"
        "WHISPER_FAILED_DIR=%h/.local/share/whisper-record-v2/failed"
      ];
      EnvironmentFile = "-%h/.config/whisprflow/serve.env";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = ["default.target"];
  };
}
