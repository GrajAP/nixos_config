{
  pkgs,
  config,
  ...
}: {
  home = {
    packages = with pkgs; [
      electron
      postman
      libreoffice-stable
      nextcloud-client
      rnote
      pnpm
      bun
      antigravity-ide
      opencode
      # Local inference, for working with no network at all. t3code and
      # opencode are already pointed at an [model_providers.ollama] block in
      # home/misc/default.nix, so the server itself was the missing piece.
      # Binds to loopback only; see the service below.
      ollama
      (pkgs.writeShellApplication {
        name = "install-js-clis";
        runtimeInputs = [pkgs.bun];
        text = ''
          set -euo pipefail

          # bun 1.3 dropped working support for `--prefix` on a global install:
          # it tries to resolve the prefix directory as a package and dies with
          # "Could not find package.json for file:../../../.bun-global". BUN_INSTALL
          # is the supported way to relocate the global prefix, and it keeps the
          # ~/.bun-global/bin path that home.sessionVariables already puts on
          # PATH.
          export BUN_INSTALL="$HOME/.bun-global"
          mkdir -p "$BUN_INSTALL"

          bun install -g \
            @angular/cli \
            @expo/cli \
            vite \
            @react-native-community/cli \
            concurrently
        '';
      })
    ];

    sessionVariables.PATH = "${config.home.homeDirectory}/.bun-global/bin:$PATH";

    sessionPath = ["${config.home.homeDirectory}/.bun-global/bin"];
  };

  systemd.user.services.ollama = {
    Unit.Description = "Local LLM server (Ollama)";
    Service = {
      ExecStart = "${pkgs.ollama}/bin/ollama serve";
      # Loopback only. Its API is unauthenticated by design, so it must not
      # be reachable from the tailnet without a proxy in front of it.
      Environment = "OLLAMA_HOST=127.0.0.1:11434";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = ["default.target"];
  };
}
