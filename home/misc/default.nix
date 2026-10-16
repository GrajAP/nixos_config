{lib, ...}: {
  imports = [
    ./media.nix
    ./cursor.nix
    ./obsidian.nix
    ./stylus.nix
    ./ferdium.nix
  ];

  # Codex itself is provided by the T3 Code module (apps/t3code), which installs
  # the npm-first provider wrapper so `codex` tracks whatever T3 Code's "update
  # providers" last installed. Only the agent defaults on top of the mutable
  # ~/.codex state are managed here.
  home.activation.codexDefaults = lib.hm.dag.entryAfter ["writeBoundary"] ''
    config="$HOME/.codex/config.toml"
    mkdir -p "$(dirname "$config")"
    touch "$config"

    set_codex_option() {
      key="$1"
      value="$2"
      if grep -q "^$key[[:space:]]*=" "$config"; then
        sed -i "s|^$key[[:space:]]*=.*$|$key = $value|" "$config"
      elif [[ -s $config ]]; then
        # Insert above every table header, so the key stays top-level TOML.
        sed -i "1i$key = $value" "$config"
      else
        # GNU sed writes nothing when told to insert before line 1 of an empty
        # file, and there are no tables yet, so appending is the same thing.
        printf '%s = %s\n' "$key" "$value" >> "$config"
      fi
    }

    set_codex_option model '"gpt-6-luna"'
    set_codex_option model_reasoning_effort '"medium"'
  '';
}
