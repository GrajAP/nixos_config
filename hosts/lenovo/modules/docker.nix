{unstablePkgs, ...}: {
  # ===========================================================================
  # CONTAINER ENGINE
  # ===========================================================================

  virtualisation.docker = {
    enable = true;

    # 25.11 ships 28.5.2, which nixpkgs flags as insecure; the old config
    # silenced that with permittedInsecurePackages. Taking docker from the
    # rolling channel instead removes the need for the exception entirely.
    package = unstablePkgs.docker;

    autoPrune = {
      enable = true;
      dates = "weekly";
    };

    daemon.settings = {
      # The NixOS default is the journald driver, which means container stdout
      # lands in the journal. That makes a single chatty container able to eat
      # the whole journal budget. json-file with a hard per-container cap bounds
      # it at the source instead, and `docker logs` still works.
      log-driver = "json-file";
      log-opts = {
        max-size = "10m";
        max-file = "3";
      };

      # Keep containers running across daemon restarts and upgrades. For a 24/7
      # box this is the difference between a `docker` upgrade and an outage.
      live-restore = true;

      # Docker's default 172.17/16 can collide with a LAN or a Tailscale exit
      # node -- and this tailnet has an exit node on offer. Pinned to a range
      # that will not.
      default-address-pools = [
        {
          base = "172.30.0.0/16";
          size = 24;
        }
      ];
    };
  };

  # Note on firewall interaction: a container port published with -p is DNAT'd in
  # the FORWARD path, which the nixos-fw INPUT chain never sees. To restrict a
  # published port to specific source addresses, add a rule to the DOCKER-USER
  # chain, which is evaluated before Docker's own accept rules.

  # ---------------------------------------------------------------------------
  # Containers that want hardware video (VAAPI / QSV on this Haswell iGPU):
  #
  #   docker run --device /dev/dri/renderD128 --group-add render ...
  #
  # `render` (gid 303) and `video` (gid 26) already exist via hardware.graphics.
  # Note that Haswell VAAPI is encode-limited: H.264 both ways, and no HEVC
  # encode. For that, Jellyfin needs a CPU encoder or a different host.
  # ---------------------------------------------------------------------------
}
