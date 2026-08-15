{pkgs, ...}: {
  services.ollama = {
    enable = true;
    host = "127.0.0.1";
    port = 11434;
    modelsDir = "/var/lib/ollama/models";
    package = pkgs.ollama;
  };

  environment.systemPackages = with pkgs; [
    ollama
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/ollama 0755 ollama ollama -"
    "d /var/lib/ollama/models 0755 ollama ollama -"
  ];

  systemd.services.ollama-pull-qwen3 = {
    description = "Pull Qwen 3 8B model into Ollama";
    after = ["ollama.service"];
    wants = ["ollama.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "pull-qwen3" ''
        until ${pkgs.curl}/bin/curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1; do
          sleep 2
        done
        ${pkgs.ollama}/bin/ollama pull qwen3:8b
      '';
    };
  };
}
