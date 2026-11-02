# One list of skills and harness paths, used by home/agents/default.nix
# (desktops) and system/agents/default.nix (hosts without home-manager).
{
  lib,
  inputs,
}: let
  local = ./skills;
  localNames =
    lib.filter (name: builtins.pathExists (local + "/${name}/SKILL.md"))
    (builtins.attrNames (builtins.readDir local));
  # full-send and full-stop call file-pr, babysit-pr and sol-loop by name.
  # sol-loop is local (skills/sol-loop): there is no GPT Sol access here.
  tstackNames = ["full-send" "full-stop" "file-pr" "babysit-pr"];
in {
  instructions = ./AGENTS.md;

  skills =
    lib.genAttrs localNames (name: local + "/${name}")
    // lib.genAttrs tstackNames (name: "${inputs.tstack}/skills/${name}");

  skillDirs = [
    ".config/opencode/skills"
    ".claude/skills"
    ".agents/skills"
    ".codex/skills"
  ];

  instructionTargets = [
    ".config/opencode/AGENTS.md"
    ".claude/CLAUDE.md"
    ".agents/AGENTS.md"
    ".gemini/GEMINI.md"
  ];
}
