{
  pkgs,
  lib,
  ...
}: {
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
      OLLAMA_CONTEXT_LENGTH = "131072";
      OLLAMA_KEEP_ALIVE = "30m";
      OLLAMA_KV_CACHE_TYPE = "q8_0";
    };
  };

  systemd.services.ollama = {
    serviceConfig = {
      CPUAffinity = lib.concatStringsSep "," (map toString (lib.range 0 23));
      Nice = -10;
      IOSchedulingClass = "realtime";
      IOSchedulingPriority = 0;
    };
  };

  environment.systemPackages = with pkgs; [
    ollama
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/ollama 0755 ollama ollama -"
    "d /var/lib/ollama/models 0755 ollama ollama -"
  ];
}
