{lib, ...}: let
  fleetDir = ./.;
  skillsDir = fleetDir + "/skills";
  skillNames =
    lib.filter (name: builtins.pathExists (skillsDir + "/${name}/SKILL.md"))
    (builtins.attrNames (builtins.readDir skillsDir));

  # One symlink per skill, per harness that discovers global skills.
  harnessSkillDirs = [
    ".config/opencode/skills"
    ".claude/skills"
    ".agents/skills"
    ".codex/skills"
  ];

  perSkill = builtins.concatLists (map
    (
      harness:
        map (skill: {
          name = "${harness}/${skill}";
          value = {
            source = skillsDir + "/${skill}";
            recursive = true;
          };
        })
        skillNames
    )
    harnessSkillDirs);

  instructionTargets = [
    ".config/opencode/AGENTS.md"
    ".claude/CLAUDE.md"
    ".agents/AGENTS.md"
  ];

  instructions =
    map (target: {
      name = target;
      value.source = fleetDir + "/AGENTS.md";
    })
    instructionTargets;
in {
  home.file = builtins.listToAttrs (perSkill ++ instructions);
}
