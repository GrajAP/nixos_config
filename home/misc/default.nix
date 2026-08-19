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

        set_codex_option model '"qwen3.8:latest"'
        set_codex_option model_provider '"ollama"'
        set_codex_option oss_provider '"ollama"'
        set_codex_option model_reasoning_effort '"low"'
        set_codex_option approval_policy '"never"'
        set_codex_option sandbox_mode '"danger-full-access"'

        # Codex ships a built-in ollama provider; custom [model_providers.ollama]
        # blocks are rejected. Strip legacy overrides from older home-manager gens.
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

        # codex --oss uses ~/.codex/ollama-launch.config.toml; keep it on the local alias.
        oss_profile="$HOME/.codex/ollama-launch.config.toml"
        mkdir -p "$(dirname "$oss_profile")"
        cat > "$oss_profile" <<'OSS'
    model = "qwen3.8:latest"
    model_provider = "ollama-launch"
    model_catalog_json = "/home/grajpap/.codex/model.json"

    [model_providers.ollama-launch]
    name = "Ollama"
    base_url = "http://127.0.0.1:11434/v1"
    wire_api = "responses"
    OSS

        cat > "$HOME/.codex/model.json" <<'MODELS'
    {
      "models": [
        {
          "base_instructions": "",
          "context_window": 65536,
          "default_verbosity": "low",
          "display_name": "qwen3.8:latest",
          "experimental_supported_tools": [],
          "input_modalities": [
            "text",
            "image"
          ],
          "priority": 0,
          "shell_type": "default",
          "slug": "qwen3.8:latest",
          "support_verbosity": true,
          "supported_in_api": true,
          "supported_reasoning_levels": [],
          "supports_parallel_tool_calls": false,
          "supports_reasoning_summaries": false,
          "truncation_policy": {
            "limit": 10000,
            "mode": "bytes"
          },
          "visibility": "list"
        }
      ]
    }
    MODELS
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
