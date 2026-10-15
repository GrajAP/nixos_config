{pkgs}: let
  extension = ./extension;
in
  pkgs.runCommand "t3-gate-extension" {} ''
    cp -r ${extension} "$out"
    chmod -R u+w "$out"
  ''
