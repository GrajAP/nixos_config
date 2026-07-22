{...}: {
  imports = [
    # Communication and development tools
    ./communication.nix
    ./development.nix
    ./presence-notifier.nix

    # Media tooling
    ./bass.nix

    # Voice and gaming workflows
    ./voice.nix
    ./gaming.nix
  ];
}
