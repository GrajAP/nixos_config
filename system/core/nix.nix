{
  pkgs,
  lib,
  inputs,
  ...
}: {
  environment = {
    # set channels (backwards compatibility)
    sessionVariables.FLAKE = "/etc/nixos";
    sessionVariables.NH_FLAKE = "/etc/nixos";
    etc = {
      "nix/flake-channels/nixpkgs".source = inputs.nixpkgs;
      "nix/flake-channels/home-manager".source = inputs.home-manager;
    };

    systemPackages = with pkgs; [
      nh
      nixd
      deadnix
      alejandra
      nvd
      statix
      glib
      libglibutil
      nix-output-monitor
      gitleaks
    ];
    defaultPackages = [];
  };

  nixpkgs = {
    config = {
      # Desktop applications and proprietary firmware require unfree packages.
      allowUnfree = true;
      # 2026-09-30: rocmSupport stays off. This is a Polaris card (gfx803) and
      # current ROCm dropped Polaris, so the flag bought nothing. It cost a
      # great deal: with it on, python3.torch is no longer a cache.nixos.org
      # build, so it compiles locally, takes the ROCm/CK path, and dies in
      # aten/.../ck/add_make_kernel_pt.sh with "/bin/bash: bad interpreter".
      # ctranslate2 pulls torch in as a test dependency, so that one failure
      # took down faster-whisper, whisprflow and the whole home-manager
      # closure. Re-enable only for a GPU ROCm still supports (gfx90a+).
    };

    overlays = [
      # 2026-07-14: AppArmor 5.0.0 does not install the helper sourced by
      # apparmor-teardown and aa-remove-unknown. Remove after nixpkgs ships it.
      (_: prev: {
        apparmor-parser = prev.apparmor-parser.overrideAttrs (old: {
          # The parser itself is unchanged; only restore a missing installed file.
          doCheck = false;
          postInstall =
            (old.postInstall or "")
            + ''
              install -Dm444 ../init/rc.apparmor.functions \
                "$out/lib/apparmor/rc.apparmor.functions"
            '';
        });
      })
      # 2026-07-13: catppuccin-gtk still uses a Python 3.14-incompatible
      # argparse declaration. Remove after nixpkgs builds catppuccin-gtk
      # without this patch.
      (_: prev: {
        catppuccin-gtk = prev.catppuccin-gtk.overrideAttrs (old: {
          postPatch =
            (old.postPatch or "")
            + ''
              sed -i '/type=bool,/d' sources/build/args.py
            '';
        });
      })
      # 2026-07-13: the package imports a removed matplotlib.style.core API
      # during its checks. Scope the exception to this package only.
      (_: prev: {
        pythonPackagesExtensions =
          (prev.pythonPackagesExtensions or [])
          ++ [
            (_: python-prev: {
              catppuccin = python-prev.catppuccin.overridePythonAttrs (_: {
                doCheck = false;
                doInstallCheck = false;
                pythonImportsCheck = [];
              });
            })
          ];
      })
      # 2026-10-27: Track upstream 7.2.4-nightly.3 to fix window.open popups
      # (Slack huddles, Messenger audio/video calls, OAuth popups) which were
      # broken by contextBridge WindowProxy dropping in 7.2.3 (PR #2552).
      (_: prev: let
        arch =
          {
            x86_64-linux = "amd64";
            aarch64-linux = "arm64";
          }
          .${
            prev.stdenv.hostPlatform.system
          } or (throw "ferdium 7.2.4-nightly.3 overlay: arch ${prev.stdenv.hostPlatform.system} not supported");
      in {
        ferdium = prev.ferdium.overrideAttrs {
          version = "7.2.4-nightly.3";
          src = prev.fetchurl {
            url = "https://github.com/ferdium/ferdium-app/releases/download/v7.2.4-nightly.3/Ferdium-linux-7.2.4-nightly.3-${arch}.deb";
            hash =
              {
                x86_64-linux = "sha256-BTu5jw3sVYAqUBEp4Zb2m1AWWpedcsvdh2wc/TXXayc=";
                aarch64-linux = "sha256-9jeVGOVtaQ+7IIWRnC/JhQpl5EpyfMnKwR+Fs9FoE/s=";
              }
              .${
                prev.stdenv.hostPlatform.system
              };
          };
        };
      })
    ];
  };

  # faster rebuilding
  documentation = {
    enable = true;
    doc.enable = false;
    man.enable = true;
    dev.enable = false;
  };

  nix = {
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
      randomizedDelaySec = "45min";
    };
    optimise = {
      automatic = true;
      dates = ["weekly"];
    };
    package = pkgs.lix;

    # pin the registry to avoid downloading and evaling a new nixpkgs version every time
    registry = lib.mapAttrs (_: v: {flake = v;}) inputs;

    # Keep legacy NIX_PATH evaluation pinned to the flake input.
    #nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
    # nix.nixPath was renamed to nix.settings.nix-path; the freeform string list
    # is unchanged.
    settings.nix-path = ["nixpkgs=${inputs.nixpkgs}"];

    # Keep enough headroom for large builds without repeatedly collecting freshly
    # fetched flake inputs when the live system cannot reach max-free.
    # NOTE: min-free must stay below actually achievable free space (disk is
    # ~98% full). 32G/40G made auto-GC delete just-fetched flake sources
    # mid-evaluation: "path ...-source did not exist in the store". 5G/10G
    # stops the thrash; free disk space to raise this again.
    extraOptions = ''
      warn-dirty = false
      min-free = ${toString (5 * 1024 * 1024 * 1024)}
      max-free = ${toString (10 * 1024 * 1024 * 1024)}
    '';
    settings = {
      flake-registry = "/etc/nix/registry.json";
      auto-optimise-store = false;
      # use binary cache, its not gentoo
      builders-use-substitutes = true;
      allowed-users = ["@wheel"];
      trusted-users = ["root"];
      sandbox = true;
      max-jobs = "auto";
      cores = 6;
      # continue building derivations if one fails
      keep-going = true;
      # A temporary outage of an optional binary cache must not block rebuilds.
      fallback = true;
      log-lines = 40;
      connect-timeout = 5;
      http-connections = 50;
      narinfo-cache-negative-ttl = 300;
      experimental-features = ["flakes" "nix-command"];
      # use binary cache, its not gentoo
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://nixpkgs-unfree.cachix.org"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
      ];
    };
  };
  system = {
    switch = {
      enable = true;
    };
    autoUpgrade = {
      enable = false;
      flake = inputs.self.outPath;
      flags = [
        "--update-input"
        "nixpkgs"
        "-L"
      ];
      dates = "09:00";
      randomizedDelaySec = "45min";
      allowReboot = false;
    };
    # Keep this at the release used for the initial installation.
    stateVersion = "24.11";
  };
}
