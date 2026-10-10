{config, ...}: let
  # PWr's RADIUS servers (rad01.pwr.edu.pl) are signed by "GEANT TLS RSA 1",
  # an intermediate under the self-signed HARICA TLS RSA Root CA 2021, since
  # the 2025-08-31 certificate change (both fingerprints match repo.harica.gr).
  # Keeping the root in the bundle too means the chain verifies whether or not
  # the server sends its intermediate.
  caBundle = ./eduroam-ca.pem;

  # Identity and password live outside git: a root-only file on this box that
  # is filled in by hand (see fleet/lenovo.md).
  secretsFile = "/var/lib/eduroam/eduroam.env";
in {
  # ===========================================================================
  # WIFI: BCM43142 driver + the PWr eduroam profile
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # The BCM43142 (PCI 14e4:4365) is supported by neither b43 nor brcmfmac, so
  # nothing in the kernel binds it out of the box -- this box has never had a
  # wlan interface. The proprietary broadcom-sta "wl" module is the only driver
  # for it. nixpkgs marks that package insecure (CVE-2019-9501/9502, no
  # upstream since 2015), so permit that single package instead of widening
  # the gate for the whole system.
  # ---------------------------------------------------------------------------
  boot = {
    extraModulePackages = [config.boot.kernelPackages.broadcom_sta];
    kernelModules = ["wl"];
    blacklistedKernelModules = [
      "b43" # would claim the same chips on other boots
      "bcma"
    ];
  };

  nixpkgs.config.allowInsecurePredicate = x:
    (builtins.parseDrvName (x.name or "")).name == "broadcom-sta";

  # ---------------------------------------------------------------------------
  # Credentials
  #
  # ensure-profiles runs envsubst over the profile with this file as its
  # environment, so the secret never appears in the Nix expression or in the
  # store -- only in the root-only keyfile it writes under /run.
  #
  # Creating it here rather than in the profile unit keeps the first switch
  # from failing: systemd's EnvironmentFile= is mandatory, and a missing file
  # would take NetworkManager-ensure-profiles down with it.
  # ---------------------------------------------------------------------------
  systemd.services.eduroam-secrets = {
    description = "Create the root-only eduroam credential file";
    wantedBy = ["multi-user.target"];
    before = ["NetworkManager-ensure-profiles.service"];
    requiredBy = ["NetworkManager-ensure-profiles.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
    };
    script = ''
      install -d -m 0700 /var/lib/eduroam
      if [ ! -s ${secretsFile} ]; then
        printf 'EDUROAM_IDENTITY=\nEDUROAM_PASSWORD=\n' > ${secretsFile}
      fi
      chmod 0600 ${secretsFile}
    '';
  };

  # ---------------------------------------------------------------------------
  # eduroam -- WPA2-Enterprise, EAP-TTLS with PAP inside the tunnel, exactly as
  # documented by Dział Informatyzacji PWr. The anonymous identity hides the
  # real one from other institutions' servers when roaming.
  # ---------------------------------------------------------------------------
  networking.networkmanager.ensureProfiles = {
    environmentFiles = [secretsFile];
    profiles.eduroam = {
      connection = {
        id = "eduroam";
        type = "wifi";
      };
      wifi = {
        ssid = "eduroam";
        mode = "infrastructure";
        security = "802-11-wireless-security";
      };
      "wifi-security".key-mgmt = "wpa-eap";
      "802-1x" = {
        eap = "ttls";
        phase2-auth = "pap";
        identity = "$EDUROAM_IDENTITY";
        anonymous-identity = "anonymous@pwr.edu.pl";
        password = "$EDUROAM_PASSWORD";
        ca-cert = "${caBundle}";
      };
      ipv4.method = "auto";
      ipv6.method = "auto";
    };
  };
}
