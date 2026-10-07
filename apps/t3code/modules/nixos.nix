# T3 Code for headless servers.
#
# Headless profile of the flake: no AppImage, no autostart, no notify. What a
# server actually needs is `t3 serve`, `t3 theme` and `t3 connect` -- the relay
# tunnel that makes the box reachable from the phone and the other desktops
# without router forwarding -- plus the environment those need to work from a
# unit systemd starts outside any login shell.
#
# The t3code.service unit and the runtime under ~/.t3/runtime stay owned by
# `t3 service install` and `t3 update`: the unit points at a versioned runtime
# that `t3 update` replaces under the running system, which NixOS cannot
# express. The CLI shim below follows that runtime instead of pinning its own,
# and this module writes only the drop-in that gives the unit a Nix-correct
# PATH, nix-ld and CA bundle.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.t3code;
  # The headless `t3` from cli.nix, not the nixpkgs one: that closure is a 3.2 GB
  # Electron app and a server needs none of it.
  t3Cli = pkgs.callPackage ../cli.nix {};
  t3code = pkgs.callPackage ../package.nix {cli = t3Cli;};
  certBundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

  # Provider CLIs and helper tools the server spawns have to be resolvable from
  # a unit with no login shell. npm-installed codex/opencode come first, then
  # the Nix profiles, then the raw system paths.
  servicePath = lib.concatStringsSep ":" [
    "%h/.local/share/t3code/npm/bin"
    "%h/.npm-global/bin"
    "/run/wrappers/bin"
    "/run/current-system/sw/bin"
    "/etc/profiles/per-user/%U/bin"
    "%h/.local/state/nix/profile/bin"
    "%h/.nix-profile/bin"
  ];
in {
  options.t3code = {
    enable = lib.mkEnableOption "T3 Code CLI, T3 Connect environment and theme publishing";

    serviceDropIn = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Write /etc/systemd/user/t3code.service.d/nixos.conf so the unit that
        `t3 service install` manages inherits a Nix PATH, nix-ld and a CA
        bundle. Disable on hosts without such a unit.
      '';
    };

    theme = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Theme JSON to publish for this environment's T3 Code clients.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      # Replaces the /opt/t3 shim: same command, but resolved to the runtime
      # the service is actually running instead of a separately installed copy.
      t3Cli
      t3code.connect
      t3code.theme
    ];

    environment.etc = lib.mkIf cfg.serviceDropIn {
      "systemd/user/t3code.service.d/nixos.conf".text = ''
        [Service]
        Environment=PATH=${servicePath}
        Environment=T3CODE_CLOUDFLARED_PATH=${lib.getExe pkgs.cloudflared}
        # The runtime under ~/.t3/runtime is a plain npm tree, so its
        # dynamically linked provider binaries need the Nix loader.
        Environment=NIX_LD=/run/current-system/sw/share/nix-ld/lib/ld.so
        Environment=NIX_LD_LIBRARY_PATH=/run/current-system/sw/share/nix-ld/lib
        # Antigravity's ACP ships its own Python and OpenSSL. Without a CA
        # bundle every Gemini request dies with SSL: CERTIFICATE_VERIFY_FAILED,
        # which the ACP surfaces as 502 Bad Gateway.
        Environment=SSL_CERT_FILE=${certBundle}
        Environment=SSL_CERT_DIR=${pkgs.cacert}/etc/ssl/certs
        Environment=NIX_SSL_CERT_FILE=${certBundle}
        Environment=NODE_EXTRA_CA_CERTS=${certBundle}
        Environment=REQUESTS_CA_BUNDLE=${certBundle}
        Environment=CURL_CA_BUNDLE=${certBundle}
      '';
    };

    system.activationScripts = lib.mkIf (cfg.theme != null) {
      t3codeTheme = ''
        theme_dir="$HOME/.t3/userdata/themes"
        mkdir -p "$theme_dir"
        install -m 644 "${cfg.theme}" \
          "$theme_dir/$(basename ${cfg.theme} .json).json"
      '';
    };
  };
}
