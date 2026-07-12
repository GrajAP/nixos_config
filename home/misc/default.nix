{pkgs, ...}: let
  codexDesktop =
    if pkgs ? codex-desktop
    then pkgs.codex-desktop
    else pkgs.codex;
  codexHeartbeat = pkgs.writeShellApplication {
    name = "codex-heartbeat";
    runtimeInputs = with pkgs; [
      bash
      codex
      coreutils
    ];
    text = ''
      set -euo pipefail

      if [[ "''${1:-}" == "cancel" ]]; then
        "${pkgs.systemd}/bin/systemctl" --user disable --now codex-heartbeat.timer
        exit 0
      fi

      # Lightweight heartbeat ping to refresh Codex 5h usage windows.
      printf 'hi\n' | "${pkgs.codex}/bin/codex" --dangerously-bypass-approvals-and-sandbox >/dev/null 2>&1 || true
    '';
  };
in {
  imports = [
    ./media.nix
    ./vscode.nix
    ./cursor.nix
    ./obsidian.nix
  ];

  # Desktop entry for Codex (keeps one place for Codex UX instead of generic package list)
  home.packages = [codexDesktop];

  xdg.configFile."codex/config.toml".text = ''
    approval_policy = "never"
    sandbox_mode = "danger-full-access"
  '';

  xdg.desktopEntries.codex = {
    name = "Codex";
    genericName = "AI coding assistant";
    comment = "OpenAI Codex coding assistant";
    exec =
      if pkgs ? codex-desktop
      then "codex-desktop --dangerously-bypass-approvals-and-sandbox"
      else "codex --dangerously-bypass-approvals-and-sandbox";
    terminal = !(pkgs ? codex-desktop);
    type = "Application";
    categories = ["Development"];
    icon = "utilities-terminal";
  };

  systemd.user = {
    services.codex-heartbeat = {
      Unit = {
        Description = "Codex heartbeat";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${codexHeartbeat}/bin/codex-heartbeat";
      };
    };
    timers.codex-heartbeat = {
      Unit = {
        Description = "Run Codex heartbeat every 5h";
      };
      Timer = {
        OnBootSec = "5h";
        OnUnitActiveSec = "5h";
        Persistent = true;
        Unit = "codex-heartbeat.service";
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
