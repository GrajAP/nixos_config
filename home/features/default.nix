{...}: {
  imports = [
    # Communication and development tools
    ./communication.nix
    ./development.nix

    # Media tooling
    ./bass.nix

    # Voice and gaming workflows
    ./voice.nix
    ./gaming.nix
  ];
}
