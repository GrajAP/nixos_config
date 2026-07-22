{
  pkgs,
  lib,
  inputs,
  ...
}: let
  nhAgentElevation = pkgs.writeShellApplication {
    name = "nh-agent-elevation";
    runtimeInputs = [pkgs.systemd];
    text = ''
      if [[ ''${1-} != "env" ]]; then
        echo "Refusing unexpected elevation request" >&2
        exit 2
      fi
      shift

      while [[ ''${1-} == *=* ]]; do
        shift
      done

      command="''${1-}"
      action="''${2-}"

      case "$command:$action" in
        /nix/store/*-nixos-system-grajpap-*/bin/switch-to-configuration:test)
          exec systemctl start t3code-os-switch.service
          ;;
        nix:build)
          # The switch service already installed the validated candidate as the
          # system profile.
          exit 0
          ;;
        /nix/store/*-nixos-system-grajpap-*/bin/switch-to-configuration:boot)
          # The switch service already activated the candidate and updated the
          # bootloader.
          exit 0
          ;;
        *)
          echo "Refusing unexpected elevation command: $command $action" >&2
          exit 2
          ;;
      esac
    '';
  };
  nhUnprivilegedSwitch = pkgs.writeShellApplication {
    name = "nh";
    text = ''
      if [[ $# -ge 2 && $1 == "os" && $2 == "switch" ]]; then
        exec ${lib.getExe pkgs.nh} \
          --elevation-strategy ${lib.getExe nhAgentElevation} "$@"
      fi

      exec ${lib.getExe pkgs.nh} "$@"
    '';
  };
in {
  environment = {
    # set channels (backwards compatibility)
    sessionVariables.FLAKE = "/etc/nixos";
    sessionVariables.NH_FLAKE = "/etc/nixos";
    etc = {
      "nix/flake-channels/nixpkgs".source = inputs.nixpkgs;
      "nix/flake-channels/home-manager".source = inputs.home-manager;
    };

    systemPackages = with pkgs; [
      nhUnprivilegedSwitch
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
      # Keep Codex on the latest verified upstream release. The official static
      # binary avoids waiting for the nixos-unstable package update.
      (_: prev: {
        codex = prev.stdenvNoCC.mkDerivation rec {
          pname = "codex";
          version = "0.144.4";

          src = prev.fetchurl {
            url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-unknown-linux-musl.tar.gz";
            hash = "sha256-N8mFvp2J6MT0OzqgWUwSE+rCEtMK4rlSIfCP7IB1FdE=";
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
      dates = "weekly";
      options = "--delete-older-than 14d";
      randomizedDelaySec = "45min";
    };
    package = pkgs.lix;

    # pin the registry to avoid downloading and evaling a new nixpkgs version every time
    registry = lib.mapAttrs (_: v: {flake = v;}) inputs;

    # Keep legacy NIX_PATH evaluation pinned to the flake input.
    #nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
    nixPath = ["nixpkgs=${inputs.nixpkgs}"];

    # Keep enough headroom for large builds and recover before the disk fills.
    extraOptions = ''
      warn-dirty = false
      min-free = ${toString (44 * 1024 * 1024 * 1024)}
      max-free = ${toString (55 * 1024 * 1024 * 1024)}
    '';
    settings = {
      flake-registry = "/etc/nix/registry.json";
      auto-optimise-store = true;
      # use binary cache, its not gentoo
      builders-use-substitutes = true;
      allowed-users = ["@wheel"];
      trusted-users = ["root"];
      sandbox = true;
      max-jobs = "auto";
      # continue building derivations if one fails
      keep-going = true;
      log-lines = 40;
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
