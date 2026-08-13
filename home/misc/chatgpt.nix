{
  inputs,
  pkgs,
  ...
}: {
  imports = [inputs.codex-desktop-linux.homeManagerModules.default];

  # Official ChatGPT desktop app for Linux (from OpenAI's Codex app family),
  # packaged by the upstream community flake. The existing nixpkgs `chatgpt`
  # package is macOS-only.
  programs.codexDesktopLinux = {
    enable = true;
    # Desktop launches Codex from the checked CLI. Keep the pinned custom
    # codex in sync so apps launched from the launcher use the same CLI.
    cliPackage = pkgs.codex;
  };
}
