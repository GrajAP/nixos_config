{...}: {
  imports = [
    ./system.nix
    ./hardening.nix
    ./network.nix
    ./nix.nix
    ./performance.nix
    ./users.nix
    ./bootloader.nix
  ];
}
