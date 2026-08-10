{pkgs, ...}: {
  services.ollama = {
    enable = true;
    host = "127.0.0.1";
    port = 11434;
    models = "/mnt/HDD/jarvis/models";
    package = pkgs.ollama;
  };

  environment.systemPackages = with pkgs; [
    ollama
  ];
}
