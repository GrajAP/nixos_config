{
  lib,
  inputs,
  ...
}: let
  agents = import ./skills.nix {inherit lib inputs;};
in {
  home.file = lib.listToAttrs (
    lib.concatMap (dir:
      lib.mapAttrsToList (name: source: {
        name = "${dir}/${name}";
        value = {
          inherit source;
          recursive = true;
        };
      })
      agents.skills)
    agents.skillDirs
    ++ map (target: {
      name = target;
      value.source = agents.instructions;
    })
    agents.instructionTargets
  );
}
