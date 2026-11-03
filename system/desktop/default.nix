# PC-only: KDE Connect, the Tailscale firewall flag, the --ssh recovery path,
# and key-only OpenSSH on 2222 for agents on lenovo.
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

  # Tailscale SSH owns port 22 on the tailnet and asks for a browser check
  # every few hours, which an agent on lenovo cannot pass. OpenSSH on 2222,
  # tailnet only, takes lenovo's fleet key instead.
  services.openssh.ports = [22 2222];
  users.users.grajpap.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBnc4+4bYtx2q/y/f2k6BAh3aXyMV4m8c/V1wtprDa1p lenovo-fleet-to-dell"
  ];

  networking.firewall.interfaces.${tailnetInterface} = {
    allowedTCPPorts = [443 2222];
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
