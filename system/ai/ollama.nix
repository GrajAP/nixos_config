{pkgs, ...}: {
  services.ollama = {
    enable = true;
    host = "127.0.0.1";
    port = 11434;
    modelsDir = "/var/lib/ollama/models";
    package = pkgs.ollama-rocm;
    rocmOverrideGfx = "8.0.3";
    environmentVariables = {
      OLLAMA_NUM_PARALLEL = "4";
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_NUM_CTX = "131072";
      HSA_OVERRIDE_GFX_VERSION = "8.0.3";
      OLLAMA_KEEP_ALIVE = "5m";
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
