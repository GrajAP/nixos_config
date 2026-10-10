{
  description = "fleet: grajpap + lenovo + dell";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprcontrib = {
      url = "github:hyprwm/contrib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helium-browser = {
      url = "github:ominit/helium-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-desktop-linux = {
      url = "github:ilysenko/codex-desktop-linux";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    nixpkgs-stable,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        android_sdk.accept_license = true;
      };
    };
    sharedModules = [
      ./configuration.nix
      inputs.stylix.nixosModules.stylix
      inputs.home-manager.nixosModules.home-manager
      inputs.spicetify-nix.nixosModules.default
    ];
    mkHost = hostModule:
      nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [hostModule] ++ sharedModules;
      };
  in {
    nixosConfigurations = {
      # grajpap: desktop + heavy extras + dual-boot Windows.
      grajpap = mkHost ./hosts/grajpap;
      # dell: same desktop as grajpap minus fleet.heavy, battery-first,
      # single-boot. (hardware-configuration.nix arrives with the machine.)
      dell = mkHost ./hosts/dell;
      # lenovo: headless server, pinned to 25.11 stable.
      lenovo = nixpkgs-stable.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          unstablePkgs = pkgs;
        };
        modules = [./hosts/lenovo/configuration.nix];
      };
    };
    formatter.${system} = pkgs.alejandra;
    checks.${system} = {
      formatting = pkgs.runCommand "check-alejandra" {nativeBuildInputs = [pkgs.alejandra];} ''
        alejandra --check ${inputs.self}
        touch $out
      '';
      statix = pkgs.runCommand "check-statix" {nativeBuildInputs = [pkgs.statix];} ''
        statix check ${inputs.self}
        touch $out
      '';
      deadnix = pkgs.runCommand "check-deadnix" {nativeBuildInputs = [pkgs.deadnix];} ''
        deadnix --fail ${inputs.self}
        touch $out
      '';
      shellcheck = pkgs.runCommand "check-shell-scripts" {nativeBuildInputs = [pkgs.shellcheck];} ''
        shellcheck \
          ${inputs.self}/rebuild.sh \
          ${inputs.self}/fleet/auto-rebuild \
          ${inputs.self}/fleet/status.sh \
          ${inputs.self}/fleet/dell-bootstrap.sh \
          ${inputs.self}/home/scripts/katana-switch \
          ${inputs.self}/home/scripts/herdr-launch \
          ${inputs.self}/apps/spark-corrector/spark-corrector \
          ${inputs.self}/apps/spark-corrector/test.sh \
          ${inputs.self}/apps/whisprflow/whisprflow
        shellcheck --shell=bash \
          ${inputs.self}/home/scripts/bcn \
          ${inputs.self}/home/scripts/eduroam \
          ${inputs.self}/home/scripts/loc \
          ${inputs.self}/home/scripts/update-userstyles
        shellcheck --shell=bash ${inputs.self}/home/rice/quickshell/scripts/*.sh
        touch $out
      '';
      spark-corrector =
        pkgs.runCommand "check-spark-corrector" {
          nativeBuildInputs = [pkgs.bash pkgs.coreutils pkgs.jq];
        } ''
          bash ${inputs.self}/apps/spark-corrector/test.sh
          touch $out
        '';
      quickshell-scripts =
        pkgs.runCommand "check-quickshell-scripts" {
          nativeBuildInputs = [pkgs.bash pkgs.python3];
        } ''
          for file in ${inputs.self}/home/rice/quickshell/scripts/*.sh; do
            bash -n "$file"
          done
          for file in weather-query calendar clipboard; do
            sed -n '/^if True:/,/^PY$/p' ${inputs.self}/home/rice/quickshell/scripts/"$file".sh \
              | sed '$d' > "$file.py"
            python3 -m py_compile "$file.py"
          done
          touch $out
        '';
      quickshell-qml =
        pkgs.runCommand "check-quickshell-qml" {
          LC_ALL = "C.UTF-8";
          nativeBuildInputs = [pkgs.qt6.qtdeclarative];
        } ''
          cp -r ${inputs.self}/home/rice/quickshell qml
          chmod -R u+w qml
          sed -E -i 's/@[A-Za-z0-9_]+@/[]/g' qml/shell.qml
          for file in qml/*.qml; do
            qmlformat "$file" >/dev/null
          done
          touch $out
        '';
    };
  };
}
