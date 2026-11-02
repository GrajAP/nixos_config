# PC-only: KDE Connect, and the Tailscale firewall flag plus the --ssh
# recovery path.
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
