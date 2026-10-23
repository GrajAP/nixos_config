{pkgs, ...}: let
  pocoAdbTcpip = pkgs.writeShellScriptBin "poco-adb-tcpip" ''
    set -eu

    adb=${pkgs.android-tools}/bin/adb
    serial=5e2a2672b38f

    # The POCO stays attached to Lenovo over USB. Android clears adbd's TCP
    # listener when it reboots, so restore it only when the authorized USB
    # transport is present and the listener is not already enabled.
    state="$($adb -s "$serial" get-state 2>/dev/null || true)"
    [ "$state" = device ] || exit 0

    port="$($adb -s "$serial" shell getprop service.adb.tcp.port 2>/dev/null | tr -d '\r')"
    [ "$port" = 5555 ] && exit 0

    echo "Enabling POCO ADB TCP on port 5555"
    $adb -s "$serial" tcpip 5555
  '';
in {
  # Android drops adb tcpip mode on reboot. The always-on Lenovo USB connection
  # lets us restore it without rooting the phone or asking someone to replug it.
  systemd.services.poco-adb-tcpip = {
    description = "Restore POCO ADB over TCP after Android reboot";
    serviceConfig = {
      Type = "oneshot";
      User = "grajpap";
      Group = "adbusers";
      Environment = "HOME=/home/grajpap";
      ExecStart = "${pocoAdbTcpip}/bin/poco-adb-tcpip";
      TimeoutStartSec = 30;
    };
  };

  systemd.timers.poco-adb-tcpip = {
    description = "Keep POCO ADB over Tailscale available";
    wantedBy = ["multi-user.target"];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "30s";
      Unit = "poco-adb-tcpip.service";
    };
  };
}
