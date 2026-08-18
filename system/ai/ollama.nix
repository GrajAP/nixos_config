{
  pkgs,
  lib,
  ...
}: let
  ollamaPackage = pkgs.ollama-vulkan;

  qwen38Modelfile = ./qwen3.8.modelfile;
  qwen38AliasScript = pkgs.writeShellScript "ollama-qwen38-alias" ''
    set -euo pipefail
    export OLLAMA_HOST="127.0.0.1:11434"

    for _ in $(seq 1 60); do
      if ${lib.getExe pkgs.curl} -sf "http://$OLLAMA_HOST/" >/dev/null; then
        break
      fi
      sleep 1
    done

    if ! ${lib.getExe pkgs.curl} -sf "http://$OLLAMA_HOST/" >/dev/null; then
      echo "ollama-qwen38-alias: ollama API not ready, skipping alias creation"
      exit 0
    fi

    if ! ${lib.getExe ollamaPackage} list | grep -q 'Qwen3.8-27B-GGUF:Q4_K_M'; then
      echo "ollama-qwen38-alias: base model not pulled yet, skipping alias creation"
      exit 0
    fi

    ${lib.getExe ollamaPackage} create qwen3.8 -f ${qwen38Modelfile}
  '';
in {
  services.ollama = {
    enable = true;
    host = "127.0.0.1";
    port = 11434;
    modelsDir = "/var/lib/ollama/models";
    package = ollamaPackage;
    environmentVariables = {
      OLLAMA_NUM_PARALLEL = "1";
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_FLASH_ATTENTION = "1";
      # Codex needs ~51k tokens for its tool schema; keep KV cache bounded on 8 GB VRAM.
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
          # Refresh the local alias whenever the daemon restarts.
          ExecStartPost = qwen38AliasScript;
        };
      };
    };

    tmpfiles.rules = [
      "d /var/lib/ollama 0755 ollama ollama -"
      "d /var/lib/ollama/models 0755 ollama ollama -"
    ];
  };

  environment.systemPackages = [
    ollamaPackage
  ];
}
