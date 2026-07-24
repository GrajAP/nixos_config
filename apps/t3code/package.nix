{
  lib,
  pkgs,
}: let
  catppuccinCss = ./catppuccin-mocha-blue.css;
  catppuccinVersion = builtins.hashFile "sha256" catppuccinCss;
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

  # Present Codex as an npm-managed provider to T3 Code while keeping the
  # mutable npm installation isolated from the declarative system profile.
  t3codeProviderTools = pkgs.runCommand "t3code-provider-tools" {} ''
    mkdir -p "$out/bin" "$out/lib/node_modules/.bin"
    ln -s ${lib.getExe t3codeNpm} "$out/bin/npm"
    ln -s ${lib.getExe t3codeCodex} "$out/lib/node_modules/.bin/codex"
  '';

  providerPath = "${t3codeProviderTools}/lib/node_modules/.bin:${lib.makeBinPath [t3codeProviderTools pkgs.gh pkgs.git]}";

  t3codeUnwrappedQueued = pkgs.t3code.unwrapped.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./queued-messages.patch];
  });
  t3codeQueued = pkgs.t3code.override {
    t3code-unwrapped = t3codeUnwrappedQueued;
  };

  t3codeCatppuccin = pkgs.runCommand "${t3codeQueued.pname or "t3code"}-${t3codeQueued.version or "wrapped"}-catppuccin-mocha-blue" {} ''
    mkdir -p "$out"
    cp -a ${t3codeQueued}/. "$out/"
    chmod -R u+w "$out"

    # Keep pnpm's symlink layout intact, and materialize only files that need
    # local edits or whose runtime path must remain inside this themed copy.
    materialize() {
      local target="$1"
      local source
      source=$(readlink -f "$target")
      rm "$target"
      cp "$source" "$target"
      chmod u+w "$target"
    }

    materialize "$out/libexec/t3code/apps/desktop/dist-electron/main.cjs"
    materialize "$out/libexec/t3code/apps/server/dist/bin.mjs"

    client="$out/libexec/t3code/apps/server/dist/client"
    materialize "$client/index.html"
    cp ${catppuccinCss} "$client/catppuccin-mocha-blue.css"
    substituteInPlace "$client/index.html" \
      --replace-fail '#161616' '#1e1e2e' \
      --replace-fail '</head>' '<link rel="stylesheet" href="/catppuccin-mocha-blue.css"></head>'

    main_js=("$client"/assets/index-*.js)
    materialize "''${main_js[0]}"
    substituteInPlace "''${main_js[0]}" \
      --replace-fail 'light:`pierre-light`,dark:`pierre-dark`' \
      'light:`catppuccin-latte`,dark:`catppuccin-mocha`'
  '';

  t3codeFallback = pkgs.symlinkJoin {
    name = "${t3codeQueued.pname or "t3code"}-${t3codeQueued.version or "wrapped"}-no-sandbox";
    paths = [t3codeCatppuccin];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      rm -f "$out/bin/t3" "$out/bin/t3code-desktop"
      makeWrapper ${lib.getExe pkgs.nodejs} "$out/bin/t3" \
        --add-flags "${t3codeCatppuccin}/libexec/t3code/apps/server/dist/bin.mjs" \
        --prefix PATH : "${providerPath}"
      makeWrapper ${lib.getExe pkgs.electron} "$out/bin/t3code-desktop" \
        --add-flags "--no-sandbox" \
        --add-flags "${t3codeCatppuccin}/libexec/t3code/apps/desktop/dist-electron/main.cjs" \
        --prefix PATH : "${providerPath}"
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
        'https://api.github.com/repos/pingdotgg/t3code/releases?per_page=10')"

      release="$(${lib.getExe pkgs.jq} --raw-output '
        first(
          .[]
          | select(.draft | not)
          | . as $release
          | $release.assets[]
          | select(.name | endswith("-x86_64.AppImage"))
          | [$release.tag_name, .browser_download_url, .digest]
          | @tsv
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
      appimage-run
      coreutils
      gnugrep
      gnused
      util-linux
      update
    ];
    text = ''
      set -euo pipefail

      app="''${XDG_DATA_HOME:-$HOME/.local/share}/t3code/desktop/T3-Code.AppImage"

      if ! ${lib.getExe update}; then
        echo "Could not refresh T3 Code; using the newest installed version" >&2
      fi

      export PATH="${providerPath}:$PATH"
      if [[ -x "$app" ]]; then
        app_hash="$(sha256sum "$app" | cut -d ' ' -f 1)"
        cache_root="''${XDG_CACHE_HOME:-$HOME/.cache}/appimage-run"
        app_dir="$cache_root/$app_hash"
        marker="$app_dir/.catppuccin-mocha-blue-${catppuccinVersion}"

        mkdir -p "$cache_root"
        exec 8>"$cache_root/t3code-catppuccin.lock"
        flock 8

        if [[ ! -x "$app_dir/AppRun" ]]; then
          staging="$(mktemp -d --tmpdir="$cache_root" ".t3code-$app_hash.XXXXXX")"
          cleanup() {
            rm -rf "$staging"
          }
          trap cleanup EXIT
          appimage-run -x "$staging" "$app"
          rm -rf "$app_dir"
          mv "$staging" "$app_dir"
          trap - EXIT
        fi

        client="$app_dir/resources/app.asar.unpacked/apps/server/dist/client"
        index="$client/index.html"
        main_js=("$client"/assets/index-*.js)

        if [[ ! -f "$marker" ]]; then
          if [[ ! -f "$index" || ! -f "''${main_js[0]}" ]]; then
            echo "The downloaded T3 Code layout is unsupported; using the Nix fallback" >&2
            exec ${lib.getExe' t3codeFallback "t3code-desktop"} "$@"
          fi

          cp ${catppuccinCss} "$client/catppuccin-mocha-blue.css"
          sed -i -e 's/#161616/#1e1e2e/g' "$index"
          if ! grep -Fq 'catppuccin-mocha-blue.css' "$index"; then
            sed -i \
              -e 's#</head>#<link rel="stylesheet" href="/catppuccin-mocha-blue.css"></head>#' \
              "$index"
          fi
          sed -i \
            "s/light:\`pierre-light\`,dark:\`pierre-dark\`/light:\`catppuccin-latte\`,dark:\`catppuccin-mocha\`/" \
            "''${main_js[0]}"

          if ! grep -Fq 'catppuccin-mocha-blue.css' "$index" \
            || ! grep -Fq "light:\`catppuccin-latte\`,dark:\`catppuccin-mocha\`" "''${main_js[0]}"; then
            echo "Could not apply Catppuccin to the downloaded T3 Code release" >&2
            exec ${lib.getExe' t3codeFallback "t3code-desktop"} "$@"
          fi

          touch "$marker"
        fi

        flock -u 8
        export APPIMAGE="$app"
        exec ${lib.getExe pkgs.appimage-run} -w "$app_dir" -- --no-sandbox "$@"
      fi

      echo "No downloaded T3 Code release is available; using the Nix fallback" >&2
      exec ${lib.getExe' t3codeFallback "t3code-desktop"} "$@"
    '';
  };

  desktop = pkgs.symlinkJoin {
    name = "t3code-latest";
    paths = [t3codeFallback update];
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
