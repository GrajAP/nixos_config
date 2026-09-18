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
    ];
    defaultPackages = [];
  };

  nixpkgs = {
    config = {
      # Desktop applications and proprietary firmware require unfree packages.
      allowUnfree = true;
      rocmSupport = true;
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
      # 2026-09-18: nixpkgs still ships Ferdium 7.1.2 (old Electron/Chromium),
      # which leaves Discord stuck at "Loading Discord". Track upstream 7.2.3
      # (Electron 43) until nixpkgs catches up. Remove after nixpkgs ships >= 7.2.3.
      (_: prev: let
        arch =
          {
            x86_64-linux = "amd64";
            aarch64-linux = "arm64";
          }
          .${
            prev.stdenv.hostPlatform.system
          } or (throw "ferdium 7.2.3 overlay: arch ${prev.stdenv.hostPlatform.system} not supported");
      in {
        ferdium = prev.ferdium.overrideAttrs {
          version = "7.2.3";
          src = prev.fetchurl {
            url = "https://github.com/ferdium/ferdium-app/releases/download/v7.2.3/Ferdium-linux-7.2.3-${arch}.deb";
            hash =
              {
                x86_64-linux = "sha256-+KP107a8Tmr2qR8pH+gHuXqEqiC5ExPGXoYOqV1Urbo=";
                aarch64-linux = "sha256-6XnuSqHOJxAURTGWfi4QUBv4ictLmjeJAoyrPg+o+Bg=";
              }
              .${
                prev.stdenv.hostPlatform.system
              };
          };
        };
      })
      # Keep Codex on the latest verified upstream release. The official static
      # binary avoids waiting for the nixos-unstable package update.
      (_: prev: {
        codex = prev.stdenvNoCC.mkDerivation rec {
          pname = "codex";
          version = "0.147.0";

          src = prev.fetchurl {
            url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-unknown-linux-musl.tar.gz";
            hash = "sha256-Akbi53ODTgfw+1JJ7W660S5FkeYI+Me7l91qlpBUTDY=";
          };

          dontUnpack = true;
          nativeBuildInputs = [prev.makeWrapper];

          installPhase = ''
            runHook preInstall
            tar -xzf "$src"
            install -Dm755 codex-x86_64-unknown-linux-musl "$out/libexec/codex"
            makeWrapper "$out/libexec/codex" "$out/bin/codex" \
              --prefix PATH : ${prev.lib.makeBinPath [prev.bubblewrap prev.ripgrep]}
            runHook postInstall
          '';

          meta =
            prev.codex.meta
            // {
              changelog = "https://github.com/openai/codex/releases/tag/rust-v${version}";
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
    nixPath = ["nixpkgs=${inputs.nixpkgs}"];

    # Keep enough headroom for large builds without repeatedly collecting freshly
    # fetched flake inputs when the live system cannot reach max-free.
    extraOptions = ''
      warn-dirty = false
      min-free = ${toString (32 * 1024 * 1024 * 1024)}
      max-free = ${toString (40 * 1024 * 1024 * 1024)}
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
