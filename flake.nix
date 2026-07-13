{
  description = "grajpap.nix";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    helium-browser = {
      url = "github:ominit/helium-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {nixpkgs, ...} @ inputs: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        android_sdk.accept_license = true;
      };
    };
    androidComposition = pkgs.androidenv.composeAndroidPackages {
      cmdLineToolsVersion = "11.0";
      platformToolsVersion = "35.0.2";
      buildToolsVersions = ["34.0.0"];
      platformVersions = ["34"];
      abiVersions = ["x86_64"];
      includeEmulator = true;
      includeSystemImages = true;
      systemImageTypes = ["google_apis_playstore"];
      useGoogleAPIs = true;
    };
    texlive = pkgs.texliveSmall.withPackages (ps: [
      ps.scheme-small
      ps.noto
      ps.mweights
      ps.cm-super
      ps.cmbright
      ps.fontaxes
      ps.beamer
    ]);
    sharedModules = [
      ./configuration.nix
      inputs.stylix.nixosModules.stylix
      inputs.home-manager.nixosModules.home-manager
      inputs.spicetify-nix.nixosModules.default
    ];
    mkHost = extraModules:
      nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [(import ./hosts/grajpap)] ++ sharedModules ++ extraModules;
      };
  in {
    nixosConfigurations.grajpap = mkHost [];
    formatter.${system} = pkgs.alejandra;
    devShells.${system} = {
      default = pkgs.mkShellNoCC {
        packages = with pkgs; [bun nodejs_22 pnpm watchman];
        shellHook = ''echo "Web shell: Node, Bun, pnpm and Watchman"'';
      };
      mobile = pkgs.mkShell {
        packages = with pkgs; [
          android-tools
          androidComposition.androidsdk
          androidComposition.emulator
          androidComposition.platform-tools
          bun
          cmake
          jdk17
          ninja
          nodejs_22
          pnpm
          watchman
        ];
        ANDROID_HOME = "${androidComposition.androidsdk}/libexec/android-sdk";
        ANDROID_SDK_ROOT = "${androidComposition.androidsdk}/libexec/android-sdk";
        JAVA_HOME = "${pkgs.jdk17}/lib/openjdk";
        shellHook = ''echo "Mobile shell: Android SDK 34, JDK 17 and JavaScript tools"'';
      };
      native = pkgs.mkShell {
        packages = with pkgs; [
          cargo
          clang
          cmake
          gdb
          gnumake
          libpqxx
          nlohmann_json
          openssl
          pkg-config
          postgresql
          clippy
          rustc
          rustfmt
          valgrind
          zlib
        ];
        shellHook = ''echo "Native shell: C/C++, Rust and PostgreSQL tools"'';
      };
      docs = pkgs.mkShellNoCC {
        packages = [texlive];
        shellHook = ''echo "Documentation shell: TeX Live"'';
      };
    };
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
          ${inputs.self}/home/scripts/katana-switch \
          ${inputs.self}/home/scripts/whisper-record-v2
        shellcheck --shell=bash ${inputs.self}/home/scripts/bcn
        shellcheck --shell=bash ${inputs.self}/home/rice/quickshell/scripts/*.sh
        touch $out
      '';
      quickshell-scripts =
        pkgs.runCommand "check-quickshell-scripts" {
          nativeBuildInputs = [pkgs.bash pkgs.python3];
        } ''
          for file in ${inputs.self}/home/rice/quickshell/scripts/*.sh; do
            bash -n "$file"
          done
          for file in weather-query calendar; do
            sed -n '/^if True:/,/^PY$/p' ${inputs.self}/home/rice/quickshell/scripts/"$file".sh \
              | sed '$d' > "$file.py"
            python3 -m py_compile "$file.py"
          done
          touch $out
        '';
      quickshell-qml =
        pkgs.runCommand "check-quickshell-qml" {
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
