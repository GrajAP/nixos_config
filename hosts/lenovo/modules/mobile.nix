_: {
  # ===========================================================================
  # MOBILE / ADB
  #
  # The POCO X4 Pro test phone is permanently attached over USB and driven
  # from SSH sessions (fleet/poco.md). Two constraints shape this:
  #
  # - programs.adb.enable is package-only on 25.11 and removed outright in
  #   nixpkgs >= 26.05 (systemd 258 does uaccess there); when bumping the
  #   channel, drop the option and keep pkgs.android-tools.
  # - uaccess ACLs only bind to a local seat session. This box is headless, so
  #   SSH sessions would never get the ACL — the udev rule below opens the
  #   device mode instead.
  # ===========================================================================

  programs.adb.enable = true;

  services.udev.extraRules = ''
    # Xiaomi/POCO (idVendor 2717): let the grajpap user drive adb over SSH.
    SUBSYSTEM=="usb", ATTR{idVendor}=="2717", MODE="0666"
  '';
}
