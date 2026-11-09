{
  pkgs,
  lib,
  config,
  ...
}: let
  dnscrypt = config.services.dnscrypt-proxy.enable;
  tailnetInterface = config.services.tailscale.interfaceName;
  inherit (lib) mkIf;
in {
  environment.systemPackages = with pkgs; [speedtest-cli bandwhich];
  networking = {
    nameservers = ["1.1.1.1" "1.0.0.1"];
    dhcpcd.extraConfig = mkIf dnscrypt "nohook resolv.conf";
    networkmanager = {
      enable = true;
      unmanaged = ["docker0" "rndis0"];
      dns = mkIf dnscrypt "none";
      wifi = {
        # EAP-TTLS (eduroam) rejects a randomized MAC address, so hosts that
        # join campus wifi turn this off. fleet.wifiRandomMac is the switch;
        # lenovo and dell set it false, the PC keeps the random default.
        macAddress =
          if config.fleet.wifiRandomMac
          then "random"
          else "preserve";
        powersave = true;
      };
    };
    firewall = {
      enable = true;
      allowPing = false;
      logReversePathDrops = true;
      interfaces.${tailnetInterface}.allowedTCPPorts = [22 8081];
    };
  };

  # encrypted dns
  services.dnscrypt-proxy = {
    enable = true;
    settings = {
      ipv6_servers = true;
      require_dnssec = true;

      sources.public-resolvers = {
        urls = [
          "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
          "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
        ];
        cache_file = "/var/lib/dnscrypt-proxy2/public-resolvers.md";
        minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
      };
    };
  };

  # 2026-11-09: Docker had filled the root disk to 100%: 50G of build cache and
  # 146 orphaned anonymous volumes (53G), left behind by the GitHub runner's
  # postgres service containers. Cap the build cache, and sweep volumes no
  # container references any more.
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
    daemon.settings.builder.gc = {
      enabled = true;
      defaultKeepStorage = "20GB";
    };
  };

  services.tailscale.enable = true;

  systemd = {
    services = {
      dnscrypt-proxy-timesync-restart = mkIf dnscrypt {
        description = "Restart dnscrypt-proxy after clock synchronization";
        wantedBy = ["time-sync.target"];
        after = ["time-sync.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.systemd}/bin/systemctl try-restart dnscrypt-proxy.service";
        };
      };

      # Not virtualisation.docker.autoPrune: that runs `docker system prune`,
      # which also deletes stopped containers, and with them the anonymous
      # volumes a stopped compose stack still needs. `volume prune` only takes
      # anonymous volumes that no container, running or stopped, refers to.
      docker-prune-orphans = {
        description = "Remove orphaned anonymous Docker volumes and dangling images";
        after = ["docker.service"];
        serviceConfig = {
          Type = "oneshot";
          # Docker is socket-activated; do not start it on a laptop just to prune.
          ExecCondition = "${pkgs.systemd}/bin/systemctl is-active --quiet docker.service";
          ExecStart = [
            "${config.virtualisation.docker.package}/bin/docker volume prune -f"
            "${config.virtualisation.docker.package}/bin/docker image prune -f"
          ];
        };
      };

      # slows down boot time
      NetworkManager-wait-online.enable = false;
    };

    timers.docker-prune-orphans = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}
