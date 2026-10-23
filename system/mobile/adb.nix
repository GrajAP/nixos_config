{
  pkgs,
  lib,
  ...
}: let
  connectPoco = pkgs.writeShellApplication {
    name = "connect-poco";
    runtimeInputs = with pkgs; [android-tools scrcpy];
    text = ''
      serial="100.110.155.84:5555"

      adb connect "$serial"
      if ! adb -s "$serial" get-state >/dev/null 2>&1; then
        echo "Nie mogę połączyć z POCO ($serial). Sprawdź, czy telefon jest online w Tailscale." >&2
        exit 1
      fi

      if [[ -n "''${DISPLAY:-}''${WAYLAND_DISPLAY:-}" ]]; then
        exec scrcpy --serial="$serial"
      fi

      echo "POCO połączony przez ADB: $serial"
      echo "Na komputerze z ekranem uruchom: scrcpy --serial=$serial"
    '';
  };
in {
  # ===========================================================================
  # ADB (fleet-wide)
  #
  # Every NixOS machine drives the phones (fleet/pixel.md, fleet/poco.md), so
  # this lives in system/mobile and is imported by every host. The heavy
  # Android SDK/emulator stack next door (./default.nix) is PC-only.
  #
  # Two constraints shape this:
  #
  # - programs.adb.enable is package-only on 25.11 and removed outright in
  #   nixpkgs >= 26.05 (systemd 258 does uaccess there); lenovo is on stable and
  #   the desktops on unstable, so the option cannot be set in a shared module.
  #   Keep pkgs.android-tools here and drop the option.
  # - uaccess ACLs only bind to a local seat session, so the lenovo (headless,
  #   driven over SSH) path used to open the device with MODE="0666". Group
  #   ownership on adbusers works the same from SSH and is not world-writable.
  # ===========================================================================

  environment.systemPackages = [
    pkgs.android-tools
    pkgs.scrcpy
    connectPoco
  ];

  users.groups.adbusers = {};

  services.udev.extraRules = lib.mkAfter ''
    # Fleet phones over USB. Group access instead of mode 0666 so an adb session
    # works headless over SSH (no seat, no uaccess ACL) without making the
    # device world-writable.
    #   2717 = Xiaomi/POCO X4 Pro (tethered to lenovo)
    #   18d1 = Google, Pixel 9a (docked ad hoc)
    SUBSYSTEM=="usb", ATTR{idVendor}=="2717", MODE="0660", GROUP="adbusers", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0660", GROUP="adbusers", TAG+="uaccess"
  '';
}
