# Fleet-wide agent instructions and skills, system scope.
#
# home/agents/default.nix does the same thing through home-manager, which is the
# better mechanism: it links into the Nix store, so the links survive the repo
# being moved, replaced by a `git checkout`, or deleted outright. It only runs
# on the desktop hosts though, because lenovo is headless and has no
# home-manager.
#
# That gap was not visible: the desktop links existed, the `fleet` skill loaded
# from a session opened in /etc/nixos (a hand-made .opencode/skills symlink in
# the repo, not a deploy), and nothing anywhere said that the same skill was
# missing on the server. So this module is the same deployment in system scope,
# with the same source of truth in home/agents, for hosts without home-manager.
#
# Same targets as the home-manager module, and deliberately the same list: a
# skill added to home/agents/skills reaches every host that imports this, and
# no host needs its own copy to know about it.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.fleet.agents;

  # home/agents, not a copy. Adding a skill directory in one place and running
  # rebuild anywhere in the fleet is the whole point. As a flake-relative path
  # this lands in the store, so the links point at an immutable generation
  # rather than at whatever the working tree currently holds.
  agentsDir = ../../home/agents;
  skillsDir = agentsDir + "/skills";

  skillNames =
    lib.filter (name: builtins.pathExists (skillsDir + "/${name}/SKILL.md"))
    (builtins.attrNames (builtins.readDir skillsDir));

  # Same four harnesses as home/agents/default.nix. Adding a harness here is the
  # only edit needed to teach the headless hosts about it.
  harnessSkillDirs = [
    ".config/opencode/skills"
    ".claude/skills"
    ".agents/skills"
    ".codex/skills"
  ];

  instructionTargets = [
    ".config/opencode/AGENTS.md"
    ".claude/CLAUDE.md"
    ".agents/AGENTS.md"
  ];

  # "  <path under $HOME> <store path to link it to>", one per line. Store paths
  # contain no whitespace, so the shell can read these two fields apart without
  # quoting games.
  linkLines =
    lib.concatLists (lib.map
      (harness: lib.map (skill: "  ${harness}/${skill} ${skillsDir}/${skill}") skillNames)
      harnessSkillDirs)
    ++ lib.map (target: "  ${target} ${agentsDir}/AGENTS.md") instructionTargets;

  linkScript = pkgs.writeShellApplication {
    name = "fleet-agent-skills";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      set -eu
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
          # Already pointing at this generation. Nothing to do, and not a
          # question worth a log line on every boot.
          if [ "$(readlink -f "$link" 2>/dev/null || true)" = "$target" ]; then
            continue
          fi
          # A real file here is not ours to delete: a hand-written
          # ~/.codex/AGENTS.md, or a harness's own config, would be lost.
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

      # The directories themselves are created by root above, so without this
      # the user's harness cannot write its own state next to the links.
      for dir in .config/opencode .claude .agents .codex; do
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
      description = ''
        Whose home the links are installed into. Same account name on every host
        in this fleet, which is what makes one list of targets enough.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.fleet-agent-skills = {
      description = "Link fleet-wide agent instructions and skills into ${cfg.user}'s home";
      documentation = [
        "file:/etc/nixos/home/agents/README.md"
      ];
      wantedBy = ["multi-user.target"];
      # On a fresh install this is the systemd unit, not home-manager, that
      # leaves /home/grajpap ready for these links to go into.
      after = ["users.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [pkgs.coreutils];
      script = "${linkScript}/bin/fleet-agent-skills";
    };
  };
}
