{...}: {
  imports = [
    ./system.nix
    ./hardening.nix
    ./network.nix
    ./nix.nix
    ./users.nix
    ./bootloader.nix
    ./storage.nix
  ];
}
