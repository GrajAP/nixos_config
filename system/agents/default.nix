# home/agents/default.nix for hosts without home-manager (lenovo): the same
# AGENTS.md and skills, linked into the user's home by a oneshot.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.fleet.agents;

  agents = import ../../home/agents/skills.nix {inherit lib inputs;};

  # "<path under $HOME> <store path>", one per line. Store paths have no spaces.
  linkLines =
    lib.concatMap (dir: lib.mapAttrsToList (name: source: "  ${dir}/${name} ${source}") agents.skills) agents.skillDirs
    ++ map (target: "  ${target} ${agents.instructions}") agents.instructionTargets;

  linkScript = pkgs.writeShellApplication {
    name = "fleet-agent-skills";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      home=/home/${cfg.user}

      if [ ! -d "$home" ]; then
        echo "fleet-agent-skills: $home does not exist, nothing to link" >&2
        exit 0
      fi

      while read -r relative target; do
        [ -n "$relative" ] || continue
        link="$home/$relative"
        mkdir -p "$(dirname "$link")"

        if [ -e "$link" ] || [ -L "$link" ]; then
          if [ "$(readlink -f "$link" 2>/dev/null || true)" = "$target" ]; then
            continue
          fi
          # Never delete a real file, only our own symlinks.
          if [ ! -L "$link" ]; then
            echo "fleet-agent-skills: $link is a real file, leaving it alone" >&2
            continue
          fi
          rm -f "$link"
        fi

        ln -s "$target" "$link"
      done <<'LINKS'
      ${lib.concatStringsSep "\n" linkLines}
      LINKS

      # Root created these dirs; the harnesses need to write next to the links.
      for dir in .config/opencode .claude .agents .codex .gemini; do
        if [ -d "$home/$dir" ]; then
          chown -R ${cfg.user}:users "$home/$dir"
        fi
      done
    '';
  };
in {
  options.fleet.agents = {
    enable = lib.mkEnableOption "fleet-wide agent instructions and skills, linked into the user home without home-manager";

    user = lib.mkOption {
      type = lib.types.str;
      default = "grajpap";
      description = "Whose home the links are installed into.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.fleet-agent-skills = {
      description = "Link fleet-wide agent instructions and skills into ${cfg.user}'s home";
      documentation = [
        "file:/etc/nixos/home/agents/README.md"
      ];
      wantedBy = ["multi-user.target"];
      after = ["users.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = "${linkScript}/bin/fleet-agent-skills";
    };
  };
}
