{
  lib,
  unstablePkgs,
  ...
}: {
  # ===========================================================================
  # NETWORK: TAILSCALE, MDNS, CADDY, FIREWALL
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # Tailscale: the primary way this box is reached.
  #
  # `client` mode only -- this host consumes an exit node, it does not route for
  # the tailnet. Source from the rolling channel; 25.11 ships a version old
  # enough to miss current client behaviour.
  # ---------------------------------------------------------------------------
  services = {
    tailscale = {
      enable = true;
      package = unstablePkgs.tailscale;
      useRoutingFeatures = "client";
    };

    # ---------------------------------------------------------------------------
    # mDNS: lenovo.local on the home LAN
    # ---------------------------------------------------------------------------
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = false; # UDP 5353 is allowed explicitly below
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
    };

    # ---------------------------------------------------------------------------
    # Caddy
    #
    # All three hosts are plain HTTP by design: on the LAN there is no name to get
    # a certificate for, and on the tailnet tailscale-serve above terminates TLS.
    # ---------------------------------------------------------------------------
    caddy = {
      enable = true;
      virtualHosts = {
        "http://" = {
          extraConfig = "reverse_proxy localhost:3001";
        };
        "http://lenovo.local" = {
          extraConfig = "reverse_proxy localhost:3001";
        };
        "http://homenest.local" = {
          extraConfig = "reverse_proxy localhost:3001";
        };
      };
    };
  };

  # ---------------------------------------------------------------------------
  # Real HTTPS on the tailnet
  #
  # Caddy cannot obtain a certificate for a `*.ts.net` name on its own, but the
  # tailnet can, and `tailscale serve` can publish Caddy's listener with a valid
  # certificate. This is what makes
  #     https://lenovo.tail138448.ts.net/
  # work from any enrolled device, with no port 443 opened on the LAN.
  #
  # Verified working: returns 200 with a valid LE certificate.
  #
  # Requires HTTPS enabled for the tailnet in the Tailscale admin console. If it
  # is not, this unit fails once at boot and logs the reason; nothing else is
  # affected.
  # ---------------------------------------------------------------------------
  systemd.services.tailscale-serve = {
    description = "Publish Caddy over HTTPS on the tailnet (MagicDNS + real cert)";
    wantedBy = ["multi-user.target"];
    after = [
      "network-online.target"
      "tailscaled.service"
      "caddy.service"
    ];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe' unstablePkgs.tailscale "tailscale"} serve --bg --https=443 http://127.0.0.1:80";
      ExecStop = "${lib.getExe' unstablePkgs.tailscale "tailscale"} serve --https=443 off";
      TimeoutStartSec = 60;
    };
  };

  # ---------------------------------------------------------------------------
  # Firewall
  #
  # Reachability, in full:
  #   tailscale0  trusted -- every port, by design (it is the admin path)
  #   LAN         TCP 22 (key-only) and TCP 80 (Caddy -> HomeNest)
  #   everything else on the LAN is refused and logged
  #
  # Two changes from before:
  #
  #  1. Port 80 was never in allowedTCPPorts, so all three Caddy vhosts were
  #     unreachable from the LAN. The comments claimed otherwise. Now open.
  #
  #  2. `docker0` was in trustedInterfaces, which accepted *all* traffic from
  #     every container: any container could bind any port and reach the home
  #     network. Removed. Containers reach the internet and the LAN through
  #     Docker's own FORWARD policy; to reach the *host* they need a port
  #     published here explicitly.
  #
  # Port 3001 is deliberately *not* opened. Caddy is the only way in, so TLS
  # termination and logging stay in one place.
  # ---------------------------------------------------------------------------
  networking.firewall = {
    enable = true;
    trustedInterfaces = ["tailscale0"];
    checkReversePath = "loose"; # required for Docker's NAT to work
    # Refused connections are already logged by the firewall's own log-refuse
    # rule (chain nixos-fw-log-refuse); there is no option to turn that on.
    allowedTCPPorts = [
      22 # SSH, key-only
      80 # Caddy -> HomeNest
    ];
    allowedUDPPorts = [
      5353 # mDNS
    ];
  };

  # Tailscale's own UDP port is added automatically by the tailscale module.
}
