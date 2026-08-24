{
  lib,
  pkgs,
  ...
}: let
  codexDesktop =
    pkgs.codex-desktop or pkgs.codex;
in {
  imports = [
    ./media.nix
    ./vscode.nix
    ./cursor.nix
    ./obsidian.nix
    ./stylus.nix
    ./chatgpt.nix
  ];

  # Desktop entry for Codex (keeps one place for Codex UX instead of generic package list)
  home.packages = [codexDesktop];

  # Codex keeps mutable state alongside its configuration in ~/.codex. Update
  # only our defaults so project trust and notice state remain intact.
  home.activation.codexDefaults = lib.hm.dag.entryAfter ["writeBoundary"] ''
    config="$HOME/.codex/config.toml"
    mkdir -p "$(dirname "$config")"
    touch "$config"

    set_codex_option() {
      key="$1"
      value="$2"
      if grep -q "^$key[[:space:]]*=" "$config"; then
        sed -i "s|^$key[[:space:]]*=.*$|$key = $value|" "$config"
      else
        sed -i "1i$key = $value" "$config"
      fi
    }

    set_codex_option model '"gpt-5.3-codex-spark"'
    set_codex_option model_reasoning_effort '"low"'
    set_codex_option approval_policy '"never"'
    set_codex_option sandbox_mode '"danger-full-access"'

    # Drop legacy local-provider keys so Codex uses its default OpenAI provider.
    sed -i '/^model_provider[[:space:]]*=/d; /^oss_provider[[:space:]]*=/d' "$config"

    # Codex defaults to the built-in OpenAI provider; strip legacy local
    # ollama overrides from older home-manager gens.
    if grep -q '^\[model_providers\.ollama\]' "$config"; then
      tmp="$(mktemp)"
      awk '
        /^\[model_providers\.ollama\]/ { skip=1; next }
        /^\[/ { skip=0 }
        !skip { print }
      ' "$config" > "$tmp"
      mv "$tmp" "$config"
    fi
    if grep -q '^\[model_providers\.ollama-custom\]' "$config"; then
      tmp="$(mktemp)"
      awk '
        /^\[model_providers\.ollama-custom\]/ { skip=1; next }
        /^\[/ { skip=0 }
        !skip { print }
      ' "$config" > "$tmp"
      mv "$tmp" "$config"
    fi

    # Remove stale local-ai artifacts from older generations.
    rm -f "$HOME/.codex/ollama-launch.config.toml" "$HOME/.codex/model.json"
  '';

  xdg.desktopEntries.codex = {
    name = "Codex";
    genericName = "AI coding assistant";
    comment = "OpenAI Codex coding assistant";
    exec =
      if pkgs ? codex-desktop
      then "codex-desktop"
      else "codex";
    terminal = !(pkgs ? codex-desktop);
    type = "Application";
    categories = ["Development"];
    icon = "utilities-terminal";
  };
}
