{pkgs, ...}: let
  codexDesktop =
    if pkgs ? codex-desktop
    then pkgs.codex-desktop
    else pkgs.codex;
in {
  imports = [
    ./media.nix
    ./vscode.nix
    ./cursor.nix
    ./spotify.nix
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
}
