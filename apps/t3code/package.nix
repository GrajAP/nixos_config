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
    cp ${./catppuccin-mocha-blue.css} "$client/catppuccin-mocha-blue.css"
    substituteInPlace "$client/index.html" \
      --replace-fail '#161616' '#1e1e2e' \
      --replace-fail '</head>' '<link rel="stylesheet" href="/catppuccin-mocha-blue.css"></head>'

    main_js=("$client"/assets/index-*.js)
    materialize "''${main_js[0]}"
    substituteInPlace "''${main_js[0]}" \
      --replace-fail 'light:`pierre-light`,dark:`pierre-dark`' \
      'light:`catppuccin-latte`,dark:`catppuccin-mocha`'
  '';

  desktop = pkgs.symlinkJoin {
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
  inherit desktop notify;
}
