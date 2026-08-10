{pkgs, ...}: {
  services.ollama = {
    enable = true;
    host = "127.0.0.1";
    port = 11434;
    models = "/var/lib/ollama/models";
    package = pkgs.ollama;
  };

  environment.systemPackages = with pkgs; [
    ollama
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/ollama 0755 ollama ollama -"
    "d /var/lib/ollama/models 0755 ollama ollama -"
  ];
}
