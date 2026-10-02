# The `t3` CLI for hosts with no desktop app.
#
# Deliberately not the nixpkgs `t3`: that derivation is a 3.2 GB Electron
# closure, and a server needs none of it. `t3 service install` already downloads
# the server into ~/.t3/runtime and `t3 update` replaces it there, so the CLI
# resolves to the version the service is actually running instead of a second
# copy that drifts behind it.
#
# What is ours is the environment: cloudflared for the T3 Connect relay, a CA
# bundle the runtime's bundled Python trusts, and a PATH that still finds
# git. Without the bundle Antigravity's ACP fails every Gemini request with
# SSL: CERTIFICATE_VERIFY_FAILED, which it surfaces as 502 Bad Gateway.
{
  lib,
  pkgs,
}: let
  certBundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
in
  pkgs.writeShellApplication {
    name = "t3";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      runtime_dir="''${T3CODE_HOME:-$HOME/.t3}/runtime"

      cli=""
      if [[ -r "$runtime_dir/service-state.json" ]]; then
        version="$(jq -r '.activeVersion // empty' "$runtime_dir/service-state.json")"
        if [[ -n "$version" && -x "$runtime_dir/versions/$version/t3" ]]; then
          cli="$runtime_dir/versions/$version/t3"
        fi
      fi

      if [[ -z "$cli" ]]; then
        # `|| true` because a host with no runtime at all must fall through to
        # the message below, not die on find's non-zero exit under pipefail.
        cli="$(find "$runtime_dir/versions" -mindepth 2 -maxdepth 2 -name t3 2>/dev/null | sort -V | tail -n1 || true)"
      fi

      if [[ -z "$cli" ]]; then
        echo "No T3 Code runtime under $runtime_dir. Run 't3 service install' on this host first." >&2
        exit 1
      fi

      export PATH="${lib.makeBinPath [
        pkgs.cloudflared
        pkgs.git
      ]}:$PATH"
      export T3CODE_CLOUDFLARED_PATH="${lib.getExe pkgs.cloudflared}"
      export SSL_CERT_FILE="${certBundle}"
      export NIX_SSL_CERT_FILE="${certBundle}"
      export NODE_EXTRA_CA_CERTS="${certBundle}"
      export REQUESTS_CA_BUNDLE="${certBundle}"
      export CURL_CA_BUNDLE="${certBundle}"

      exec "$cli" "$@"
    '';
  }
