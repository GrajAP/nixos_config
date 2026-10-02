# ===========================================================================
# MOBILE / ANDROID
#
# Split by cost, not by host:
#
#   - adb, platform-tools, the Android SDK and the native build deps are cheap
#     and belong on any machine that may talk to a phone.
#   - Android Studio, the emulator and its system images are hundreds of
#     megabytes and are gated on fleet.heavy.enable, so a laptop gets a working
#     React Native / adb setup without pulling the desktop's IDE.
#
# grajpap sets fleet.heavy.enable = true and is unaffected by the gating; dell
# sets it false and takes the light path.
#
# The emulator and system images are switched off in the composition itself
# rather than merely being left out of systemPackages: androidenv would still
# realise and download them as a dependency of androidSdk otherwise.
# ===========================================================================
{
  config,
  lib,
  pkgs,
  ...
}: let
  heavy = config.fleet.heavy.enable;

  androidComposition = pkgs.androidenv.composeAndroidPackages {
    cmdLineToolsVersion = "11.0";
    platformToolsVersion = "37.0.1";
    buildToolsVersions = ["34.0.0"];
    platformVersions = ["34"];
    abiVersions = ["x86_64"];
    includeEmulator = heavy;
    includeSystemImages = heavy;
    systemImageTypes = ["google_apis_playstore"];
    useGoogleAPIs = heavy;
  };
  androidSdk = androidComposition.androidsdk;
  platformTools = androidComposition.platform-tools;
in {
  nixpkgs.config.android_sdk.accept_license = true;

  # system/core/users.nix puts grajpap in adbusers unconditionally, but nothing
  # in current nixpkgs creates the group: programs.adb.enable is package-only
  # now that systemd-logind's uaccess handles device access, and the old
  # top-level usersGroups option is gone entirely as of 26.11. Without this the
  # group reference is silently dropped at activation.
  users.groups.adbusers = {};

  # TAG+="uaccess" hands the device to whoever is logged in at the seat, which
  # is what a local desktop session wants. Only desktop hosts import this
  # module; lenovo has its own headless variant with MODE="0666" instead,
  # because it has no seat session for the ACL to bind to
  # (hosts/lenovo/modules/mobile.nix).
  services.udev.extraRules = ''
    # POCO (Xiaomi, 2717) and Pixel (Google, 18d1).
    SUBSYSTEM=="usb", ATTR{idVendor}=="2717", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", TAG+="uaccess"
    # Any other phone exposing MTP, so a new device needs no rule here.
    SUBSYSTEM=="usb", ENV{ID_MTP_USER}!="", TAG+="uaccess"
  '';

  home-manager.users.grajpap = {
    home.packages =
      [pkgs.scrcpy]
      ++ lib.optionals heavy [
        pkgs.android-studio
      ];

    home.sessionVariables = {
      EXPO_CLI_PASSWORD_PROMPT = "false";
      REACT_NATIVE_PACKAGER_HOSTNAME = "localhost";
    };
  };

  environment = {
    systemPackages = with pkgs;
      [
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
      ]
      ++ lib.optionals heavy [
        androidComposition.emulator
      ];

    sessionVariables = {
      ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
      ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
      JAVA_HOME = "${pkgs.jdk17}/lib/openjdk";
    };

    etc."android-setup.sh" = {
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
  };
}
