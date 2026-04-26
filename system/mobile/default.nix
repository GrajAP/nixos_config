{pkgs, ...}: let
  androidComposition = pkgs.androidenv.composeAndroidPackages {
    cmdLineToolsVersion = "11.0";
    platformToolsVersion = "35.0.1";
    buildToolsVersions = ["34.0.0"];
    platformVersions = ["34"];
    abiVersions = ["x86_64"];
    includeEmulator = true;
    includeSystemImages = true;
    systemImageTypes = ["google_apis_playstore"];
    useGoogleAPIs = true;
  };
  androidSdk = androidComposition.androidsdk;
  platformTools = androidComposition.platform-tools;
in {
  nixpkgs.config.android_sdk.accept_license = true;

  environment.systemPackages = with pkgs; [
    android-tools
    cmake
    gcc
    gnumake
    h3
    jdk17
    libpqxx
    nlohmann_json
    openssl
    pkg-config
    postgresql
    zlib
    androidSdk
    platformTools
    androidComposition.emulator
  ];

  environment.sessionVariables = {
    ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
    ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
    JAVA_HOME = "${pkgs.jdk17}/lib/openjdk";
  };

  environment.etc."android-setup.sh" = {
    text = ''
      #!/bin/bash
      # Android Development Environment Setup

      echo "Setting up Android SDK environment..."

      SDK_ROOT="${androidSdk}/libexec/android-sdk"

      export ANDROID_HOME="$SDK_ROOT"
      export ANDROID_SDK_ROOT="$SDK_ROOT"
      export PATH="$SDK_ROOT/emulator:$SDK_ROOT/platform-tools:$PATH"

      echo "Android SDK: $SDK_ROOT"
      echo ""
      echo "Available commands:"
      echo "  adb devices                    - List connected devices"
      echo "  emulator -list-avds            - List available AVDs"
      echo "  emulator -avd <name>           - Start emulator"
      echo ""

      if [ -f "$SDK_ROOT/emulator/emulator" ]; then
        echo "✓ Emulator found"
      else
        echo "⚠ Emulator not found at expected location"
      fi

      if [ -d ~/.android/avd ]; then
        echo "AVD Directory: ~/.android/avd"
        ls ~/.android/avd/ 2>/dev/null | grep -E '\.avd$' || echo "No AVDs found"
      fi
    '';
    mode = "0755";
  };
}
