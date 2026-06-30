{...}: {
  imports = [
    # Core interaction and productivity tools
    ./communication.nix
    ./productivity.nix
    ./mobile.nix

    # Development and media tooling
    ./development.nix
    ./bass.nix

    # Voice and gaming workflows
    ./voice.nix
    ./gaming.nix
  ];
}
