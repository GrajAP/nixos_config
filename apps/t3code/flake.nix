{
  description = "T3 Code for NixOS: wrapped desktop AppImage, headless CLI, T3 Connect and environment themes";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    pkgsFor = system:
      import nixpkgs {
        inherit system;
        # code-cursor, one of the provider CLIs handed to the app, is unfree.
        config.allowUnfree = true;
      };
  in {
    packages = forAllSystems (system: let
      pkgs = pkgsFor system;
      full = pkgs.callPackage ./package.nix {};
      # What a server installs: no Electron closure, `t3` resolved against the
      # runtime under ~/.t3 that `t3 service install` owns.
      t3Cli = pkgs.callPackage ./cli.nix {};
      headless = pkgs.callPackage ./package.nix {cli = t3Cli;};
    in {
      default = full.desktop;
      t3code = full.desktop;
      t3code-cli = t3Cli;
      t3code-connect = full.connect;
      t3code-desktop = full.desktop;
      t3code-notify = full.notify;
      t3code-theme = full.theme;
      t3code-update = full.update;
      t3code-headless = pkgs.buildEnv {
        name = "t3code-headless";
        paths = [
          t3Cli
          headless.connect
          headless.theme
        ];
      };
    });

    # Modules are plain files rather than functions of the flake inputs so the
    # same file can be imported by a host flake, where `pkgs` is the host's
    # package set and its own nixpkgs lock is irrelevant.
    homeModules.default = import ./modules/home-manager.nix;
    nixosModules.default = import ./modules/nixos.nix;

    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    checks = forAllSystems (system: let
      pkgs = pkgsFor system;
    in {
      formatting = pkgs.runCommand "check-alejandra" {nativeBuildInputs = [pkgs.alejandra];} ''
        alejandra --check ${self}
        touch $out
      '';
      statix = pkgs.runCommand "check-statix" {nativeBuildInputs = [pkgs.statix];} ''
        statix check ${self}
        touch $out
      '';
      deadnix = pkgs.runCommand "check-deadnix" {nativeBuildInputs = [pkgs.deadnix];} ''
        deadnix --fail ${self}
        touch $out
      '';
    });
  };
}
