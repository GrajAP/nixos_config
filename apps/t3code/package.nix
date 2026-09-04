{
  lib,
  pkgs,
}: let
  t3codeNpm = pkgs.writeShellApplication {
    name = "npm";
    runtimeInputs = [pkgs.nodejs];
    text = ''
      prefix="''${XDG_DATA_HOME:-$HOME/.local/share}/t3code/npm"
      mkdir -p "$prefix/bin" "$prefix/lib"
      export npm_config_prefix="$prefix"
      exec npm "$@"
    '';
  };

  t3codeCodex = pkgs.writeShellApplication {
    name = "codex";
    text = ''
      user_codex="''${XDG_DATA_HOME:-$HOME/.local/share}/t3code/npm/bin/codex"
      if [[ -x "$user_codex" ]]; then
        exec "$user_codex" "$@"
      fi

      exec ${lib.getExe pkgs.codex} "$@"
    '';
  };

  t3codeOpencode = pkgs.writeShellApplication {
    name = "opencode";
    text = ''
      user_opencode="''${XDG_DATA_HOME:-$HOME/.local/share}/t3code/npm/bin/opencode"
      if [[ -x "$user_opencode" ]]; then
        exec "$user_opencode" "$@"
      fi

      exec ${lib.getExe pkgs.opencode} "$@"
    '';
  };

  # Present Codex and OpenCode as npm-managed providers to T3 Code while
  # keeping the mutable npm installation isolated from the declarative system
  # profile.
  t3codeProviderTools = pkgs.runCommand "t3code-provider-tools" {} ''
    mkdir -p "$out/bin" "$out/lib/node_modules/.bin"
    ln -s ${lib.getExe t3codeNpm} "$out/bin/npm"
    ln -s ${lib.getExe t3codeCodex} "$out/lib/node_modules/.bin/codex"
    ln -s ${lib.getExe t3codeOpencode} "$out/lib/node_modules/.bin/opencode"
  '';

  providerPath = "${t3codeProviderTools}/lib/node_modules/.bin:${lib.makeBinPath [t3codeProviderTools pkgs.gh pkgs.git]}";

  # appimage-run normally hides host paths below /etc. T3 Code needs the
  # configured workspace to remain visible so provider processes can start in
  # the same directory selected by the desktop application.
  t3codeAppimageRun = pkgs.appimage-run.override {
    buildFHSEnv = args:
      pkgs.buildFHSEnv (args
        // {
          extraBwrapArgs =
            (args.extraBwrapArgs or [])
            ++ ["--bind /etc/nixos /etc/nixos"];
        });
  };

  t3codeFallback = pkgs.symlinkJoin {
    name = "${pkgs.t3code.pname or "t3code"}-${pkgs.t3code.version or "wrapped"}-providers";
    paths = [pkgs.t3code];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      for program in "$out"/bin/*; do
        wrapProgram "$program" --prefix PATH : "${providerPath}" \
          --set SSL_CERT_FILE "/etc/ssl/certs/ca-certificates.crt" \
          --set SSL_CERT_DIR "/etc/ssl/certs"
      done
    '';
  };

  # The built-in Electron updater cannot replace an application stored in the
  # immutable Nix store. Keep the official AppImage in user-writable storage so
  # both this updater and T3 Code's own update action can replace it.
  update = pkgs.writeShellApplication {
    name = "t3code-update";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      jq
      util-linux
    ];
    text = ''
      set -euo pipefail

      state_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/t3code/desktop"
      app="$state_dir/T3-Code.AppImage"
      version_file="$state_dir/version"
      mkdir -p "$state_dir"

      exec 9>"$state_dir/update.lock"
      flock 9

      metadata="$(${lib.getExe pkgs.curl} \
        --fail \
        --location \
        --silent \
        --show-error \
        --retry 3 \
        --connect-timeout 10 \
        --max-time 30 \
        --header 'Accept: application/vnd.github+json' \
        --header 'X-GitHub-Api-Version: 2022-11-28' \
        --user-agent 't3code-update-nixos' \
        'https://api.github.com/repos/pingdotgg/t3code/releases?per_page=20')"

      # Prefer the newest nightly/prerelease AppImage. Fall back to the newest
      # non-draft release only when no nightly asset is published yet.
      release="$(${lib.getExe pkgs.jq} --raw-output '
        def appimage:
          . as $release
          | $release.assets[]
          | select(.name | endswith("-x86_64.AppImage"))
          | [$release.tag_name, .browser_download_url, .digest]
          | @tsv;
        (
          first(
            .[]
            | select(.draft | not)
            | select(.prerelease or (.tag_name | test("nightly"; "i")))
            | appimage
          )
        ) // (
          first(
            .[]
            | select(.draft | not)
            | appimage
          )
        ) // empty
      ' <<<"$metadata")"

      if [[ -z "$release" ]]; then
        echo "No current x86_64 AppImage release found for T3 Code" >&2
        exit 1
      fi

      IFS=$'\t' read -r tag url digest <<<"$release"
      if [[ ! "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
        echo "Release $tag has no valid SHA-256 digest" >&2
        exit 1
      fi

      expected_hash="''${digest#sha256:}"
      if [[ -x "$app" ]]; then
        if [[ -r "$version_file" && "$(<"$version_file")" == "$tag" ]]; then
          echo "T3 Code $tag is already installed"
          exit 0
        fi

        # T3 Code's Electron updater does not know about our version marker.
        # Recognize an AppImage it has already updated instead of downloading
        # the same release again.
        installed_hash="$(sha256sum "$app" | cut -d ' ' -f 1)"
        if [[ "$installed_hash" == "$expected_hash" ]]; then
          printf '%s\n' "$tag" >"$version_file"
          echo "T3 Code $tag is already installed"
          exit 0
        fi
      fi

      app_tmp="$(mktemp --tmpdir="$state_dir" '.T3-Code.AppImage.XXXXXX')"
      version_tmp="$(mktemp --tmpdir="$state_dir" '.version.XXXXXX')"
      cleanup() {
        rm -f "$app_tmp" "$version_tmp"
      }
      trap cleanup EXIT

      echo "Downloading T3 Code $tag"
      ${lib.getExe pkgs.curl} \
        --fail \
        --location \
        --show-error \
        --retry 3 \
        --connect-timeout 15 \
        --output "$app_tmp" \
        "$url"

      actual_hash="$(sha256sum "$app_tmp" | cut -d ' ' -f 1)"
      if [[ "$actual_hash" != "$expected_hash" ]]; then
        echo "SHA-256 mismatch for T3 Code $tag" >&2
        exit 1
      fi

      chmod 700 "$app_tmp"
      printf '%s\n' "$tag" >"$version_tmp"
      mv -f "$app_tmp" "$app"
      mv -f "$version_tmp" "$version_file"
      trap - EXIT
      echo "Installed T3 Code $tag"
    '';
  };

  t3codeDesktopLatest = pkgs.writeShellApplication {
    name = "t3code-desktop-latest";
    runtimeInputs = with pkgs; [
      coreutils
      t3codeAppimageRun
      update
    ];
    text = ''
      set -euo pipefail

      app="''${XDG_DATA_HOME:-$HOME/.local/share}/t3code/desktop/T3-Code.AppImage"

      if ! ${lib.getExe update}; then
        echo "Could not refresh T3 Code; using the newest installed version" >&2
      fi

      export SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
      export SSL_CERT_DIR="/etc/ssl/certs"
      export PATH="${providerPath}:$PATH"
      if [[ -x "$app" ]]; then
        export APPIMAGE="$app"
        exec ${lib.getExe t3codeAppimageRun} "$app" --no-sandbox "$@"
      fi

      echo "No downloaded T3 Code release is available; using the Nix fallback" >&2
      exec ${lib.getExe' t3codeFallback "t3code-desktop"} "$@"
    '';
  };

  desktop = pkgs.symlinkJoin {
    name = "t3code-latest-with-fallback";
    paths = [
      t3codeFallback
      t3codeDesktopLatest
      update
    ];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      rm -f "$out/bin/t3code-desktop"
      makeWrapper ${lib.getExe t3codeDesktopLatest} "$out/bin/t3code-desktop"
    '';
  };

  notify = pkgs.writeShellApplication {
    name = "t3code-notify";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      libnotify
      desktop
    ];
    text = ''
      set +e

      start_epoch="$(date +%s)"
      t3code "$@"
      status="$?"
      end_epoch="$(date +%s)"
      elapsed="$((end_epoch - start_epoch))"

      minutes="$((elapsed / 60))"
      seconds="$((elapsed % 60))"
      if [ "$minutes" -gt 0 ]; then
        duration="''${minutes}m ''${seconds}s"
      else
        duration="''${seconds}s"
      fi

      if [ "$status" -eq 0 ]; then
        title="T3 Code finished"
        body="Ready for the next prompt after $duration."
        urgency="normal"
        priority="default"
      else
        title="T3 Code stopped"
        body="Exited with status $status after $duration."
        urgency="critical"
        priority="high"
      fi

      notify-send --app-name="T3 Code" --urgency="$urgency" "$title" "$body" >/dev/null 2>&1 || true

      topic="''${T3CODE_NTFY_TOPIC:-}"
      topic_file="''${XDG_CONFIG_HOME:-$HOME/.config}/t3code-notify/ntfy-topic"
      if [ -z "$topic" ] && [ -r "$topic_file" ]; then
        topic="$(head -n1 "$topic_file" | tr -d '[:space:]')"
      fi

      if [ -n "$topic" ]; then
        server="''${T3CODE_NTFY_SERVER:-https://ntfy.sh}"
        curl \
          --fail \
          --silent \
          --show-error \
          --max-time 8 \
          -H "Title: $title" \
          -H "Priority: $priority" \
          -H "Tags: computer" \
          -d "$body" \
          "$server/$topic" >/dev/null 2>&1 || true
      fi

      exit "$status"
    '';
  };
in {
  inherit desktop notify update;
}
