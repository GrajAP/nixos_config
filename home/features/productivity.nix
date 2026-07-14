{
  lib,
  pkgs,
  ...
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

  t3codeCatppuccin = pkgs.runCommand "${pkgs.t3code.pname or "t3code"}-${pkgs.t3code.version or "wrapped"}-catppuccin-mocha-blue" {} ''
    mkdir -p "$out"
    cp -aL ${pkgs.t3code}/. "$out/"
    chmod -R u+w "$out"

    # t3code 0.0.28 packages fast-check in pnpm's store but drops the
    # top-level link needed by Effect during Electron startup.
    fast_check=$(find "$out/libexec/t3code/node_modules/.pnpm" \
      -path '*/fast-check@*/node_modules/fast-check' -type d -print -quit)
    test -n "$fast_check"
    ln -s "$fast_check" "$out/libexec/t3code/node_modules/fast-check"

    client="$out/libexec/t3code/apps/server/dist/client"
    cp ${./t3code-catppuccin-mocha-blue.css} "$client/catppuccin-mocha-blue.css"
    substituteInPlace "$client/index.html" \
      --replace-fail '#161616' '#1e1e2e' \
      --replace-fail '</head>' '<link rel="stylesheet" href="/catppuccin-mocha-blue.css"></head>'

    main_js=("$client"/assets/index-*.js)
    substituteInPlace "''${main_js[0]}" \
      --replace-fail 'var vG={light:`pierre-light`,dark:`pierre-dark`}' \
      'var vG={light:`catppuccin-latte`,dark:`catppuccin-mocha`}'
  '';

  t3codeNoSandbox = pkgs.symlinkJoin {
    name = "${pkgs.t3code.pname or "t3code"}-${pkgs.t3code.version or "wrapped"}-no-sandbox";
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

  t3codeNotify = pkgs.writeShellApplication {
    name = "t3code-notify";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      libnotify
      t3codeNoSandbox
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
  home.packages = with pkgs; [
    github-desktop
    libreoffice-fresh
    nextcloud-client
    rnote
    t3codeNoSandbox
    t3codeNotify
  ];
}
