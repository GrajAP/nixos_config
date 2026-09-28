{
  lib,
  heavy,
  ...
}: {
  imports =
    [
      # Communication and development tools
      ./communication.nix
      ./development.nix

      # Media tooling
      ./bass.nix

      # Voice workflows
      ./voice.nix
    ]
    ++ lib.optionals heavy [
      # Gaming workflows — fleet.heavy.enable, set per host
      ./gaming.nix
    ];
}
