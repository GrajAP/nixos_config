{
  pkgs,
  lib,
  ...
}: let
  qwen38Modelfile = ./qwen3.8.modelfile;
  qwen38AliasScript = pkgs.writeShellScript "ollama-qwen38-alias" ''
    set -euo pipefail
    export OLLAMA_HOST="127.0.0.1:11434"
    if ! ${lib.getExe pkgs.curl} -sf "http://$OLLAMA_HOST/" >/dev/null; then
      exit 0
    fi
    if ! ${lib.getExe pkgs.ollama} list | grep -q 'Qwen3.8-27B-GGUF:Q4_K_M'; then
      echo "ollama-qwen38-alias: base model not pulled yet, skipping alias creation"
      exit 0
    fi
    ${lib.getExe pkgs.ollama} create qwen3.8 -f ${qwen38Modelfile}
  '';
in {
  services.ollama = {
    enable = true;
    host = "127.0.0.1";
    port = 11434;
    modelsDir = "/var/lib/ollama/models";
    package = pkgs.ollama-vulkan;
    environmentVariables = {
      OLLAMA_NUM_PARALLEL = "1";
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_FLASH_ATTENTION = "1";
      # Match the qwen3.8 alias ctx cap; avoids oversized daemon reservations.
      OLLAMA_CONTEXT_LENGTH = "65536";
      OLLAMA_KEEP_ALIVE = "30m";
      OLLAMA_KV_CACHE_TYPE = "q8_0";
    };
  };

  systemd = {
    services = {
      ollama-qwen38-alias = {
        description = "Create qwen3.8 Ollama alias for Codex OSS";
        after = ["ollama.service"];
        requires = ["ollama.service"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = qwen38AliasScript;
        };
      };

      ollama = {
        serviceConfig = {
          CPUAffinity = lib.concatStringsSep "," (map toString (lib.range 0 23));
          Nice = -10;
          IOSchedulingClass = "realtime";
          IOSchedulingPriority = 0;
        };
      };
    };

    tmpfiles.rules = [
      "d /var/lib/ollama 0755 ollama ollama -"
      "d /var/lib/ollama/models 0755 ollama ollama -"
    ];
  };

  environment.systemPackages = with pkgs; [
    ollama
  ];
}
