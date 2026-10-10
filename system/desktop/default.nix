# PC-only conveniences that are not tied to the desktop stack.
#
# This module used to be system/sync, and it used to host Nextcloud here. That
# is gone: calendar, tasks and notes live on lenovo, which is always on, so the
# phone can sync whatever state this machine is in. See
# hosts/lenovo/modules/nextcloud.nix for where that is now.
#
# What is left is deliberately unrelated to either: KDE Connect for the phone,
# and the Tailscale firewall flag plus the --ssh recovery path.
{
  config,
  pkgs,
  ...
}: let
  tailnetInterface = config.services.tailscale.interfaceName;
in {
  environment.systemPackages = with pkgs; [
    kdePackages.kdeconnect-kde
  ];

  networking.firewall.interfaces.${tailnetInterface} = {
    allowedTCPPorts = [443];
    # KDE Connect's fixed port range.
    allowedTCPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
    allowedUDPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
  };

  services.tailscale = {
    openFirewall = true;
    # Tailscale SSH is the recovery path before an OpenSSH authorized key is
    # installed.
    extraSetFlags = ["--ssh"];
  };
}
