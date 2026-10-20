{
  description = "Polish and English correction with GPT-5.3-Codex-Spark";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {nixpkgs, ...}: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
    package = pkgs.callPackage ./package.nix {};
  in {
    packages.${system} = {
      default = package;
      spark-corrector = package;
    };
    apps.${system}.default = {
      type = "app";
      program = "${package}/bin/spark-corrector";
    };
  };
}
