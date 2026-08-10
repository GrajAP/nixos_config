{...}: {
  imports = [
    ./ollama.nix
    ./kvm.nix
    ./tts.nix
    ./vision.nix
    ./hearing.nix
    ./memory.nix
    ./heartbeat.nix
    ./permissions.nix
    ./service.nix
  ];
}
