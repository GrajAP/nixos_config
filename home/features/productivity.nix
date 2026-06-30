{
  lib,
  pkgs,
  ...
}: let
  t3codeNoSandbox = pkgs.symlinkJoin {
    name = "${pkgs.t3code.pname or "t3code"}-${pkgs.t3code.version or "wrapped"}-no-sandbox";
    paths = [pkgs.t3code];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      rm -f "$out/bin/t3code-desktop"
      makeWrapper ${lib.getExe pkgs.electron} "$out/bin/t3code-desktop" \
        --add-flags "--no-sandbox" \
        --add-flags "${pkgs.t3code}/libexec/t3code/apps/desktop/dist-electron/main.cjs" \
        --prefix PATH : "${lib.makeBinPath [pkgs.codex pkgs.gh pkgs.git]}"
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
    obsidian
    t3codeNoSandbox
    t3codeNotify
  ];
}
