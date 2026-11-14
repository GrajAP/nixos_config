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
      antigravity-ide
      opencode
      ollama
      uv
      google-cloud-sdk
      (pkgs.writeShellApplication {
        name = "install-js-clis";
        runtimeInputs = [pkgs.bun];
        text = ''
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
            concurrently \
            @google/gemini-cli
        '';
      })
    ];

    sessionPath = [
      "${config.home.homeDirectory}/.bun-global/bin"
      # uv tool install (harbor)
      "${config.home.homeDirectory}/.local/bin"
    ];
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
