# This file is intentionally a hard error until the real hardware
# configuration is harvested from the dell laptop itself.
#
# Run this ON the dell (at its console), then copy the result here:
#
#   sudo nixos-generate-config --show-hardware-config > /tmp/hardware-configuration.nix
#   scp /tmp/hardware-configuration.nix <this repo>/hosts/dell/
#
# Do not invent these values by copying hosts/grajpap or hosts/lenovo. A wrong
# root device means a system that builds cleanly and then fails to activate,
# which leaves the laptop unbootable.
_: {
  nixpkgs.hostPlatform = throw ''
    hosts/dell/hardware-configuration.nix has not been filled in yet.

    Harvest it on the dell itself:
      sudo nixos-generate-config --show-hardware-config > /tmp/hardware-configuration.nix

    then copy it to hosts/dell/hardware-configuration.nix in this repo and run
    `rebuild --check`.

    Until then nix flake check fails on nixosConfigurations.dell, on purpose.
    Nothing else in the fleet is affected.
  '';
}
