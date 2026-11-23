_: {
  # ===========================================================================
  # DNS: a local resolver that asks public resolvers itself
  #
  # tailscaled used to own /etc/resolv.conf and forward every query to the
  # router. On 2026-11-23 a 6 s Ethernet link flap left it with no upstream, and
  # the host and its containers resolved nothing for 10 hours, until tailscaled
  # was restarted by hand. Now systemd-resolved owns resolv.conf: it asks the
  # servers below and the router's DHCP one in parallel, and Tailscale only
  # answers `ts.net`, so a broken tailscaled costs tailnet names and nothing
  # else. Docker reads the same upstream list, so containers follow.
  # ===========================================================================
  networking.nameservers = [
    "1.1.1.1" # Cloudflare
    "9.9.9.9" # Quad9
  ];

  services.resolved = {
    enable = true;
    fallbackDns = [
      "1.0.0.1"
      "149.112.112.112"
    ];
    # avahi (network.nix) owns mDNS, and nothing here speaks LLMNR.
    llmnr = "false";
    extraConfig = "MulticastDNS=no";
  };

  # tailscaled picks its DNS mode once, at start. If resolved is not up yet it
  # falls back to rewriting /etc/resolv.conf itself, which is the old setup.
  systemd.services.tailscaled = {
    after = ["systemd-resolved.service"];
    wants = ["systemd-resolved.service"];
  };
}
