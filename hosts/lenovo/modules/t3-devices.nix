{
  pkgs,
  lib,
  ...
}: let
  # Lean SDK: nothing here builds Android apps. It only has to satisfy T3's
  # device bridge (device-hub + agent-device), which refuses the android
  # platform unless ANDROID_HOME carries platform-tools/adb, emulator/emulator
  # and cmdline-tools/latest/bin/avdmanager. Emulator without a system image
  # is enough for that check, and a device like the POCO only ever needs adb.
  #
  # Not shared with the desktops: system/mobile/default.nix there composes a
  # build-capable SDK (system images, build tools, ANDROID_HOME session vars)
  # for React Native, and lenovo has no home-manager for it. Lenovo's copy
  # exists solely for the T3 device layer.
  androidComposition = pkgs.androidenv.composeAndroidPackages {
    includeEmulator = true;
    includeSystemImages = false;
    includeNDK = false;
    includeCmake = false;
    includeSources = false;
    includeExtras = [];
    buildToolsVersions = [];
    platformVersions = [];
  };

  # androidenv deploys cmdLineToolsVersion normally: cmdline-tools/<version>/
  # with androidsdk as the deployer. T3 expects Google's sdkmanager layout with
  # cmdline-tools/latest/bin/avdmanager, so add the alias in a thin tree that
  # points at the composition, keeping the SDK read-only in the store.
  t3AndroidSdk = pkgs.runCommand "t3-android-sdk" {} ''
    root=${androidComposition.androidsdk}/libexec/android-sdk
    mkdir -p $out/cmdline-tools

    ln -s "$root/platform-tools" $out/platform-tools
    ln -s "$root/emulator" $out/emulator

    toolsDir=$(ls -d "$root/cmdline-tools"/* | head -n 1)
    ln -s "$toolsDir" $out/cmdline-tools/latest
  '';
in {
  # androidenv refuses to fetch Google's SDK without an accepted license.
  nixpkgs.config.android_sdk.accept_license = true;

  # T3's local device host probes $HOME/Android/Sdk when ANDROID_HOME is
  # unset, and that directory is already a real, working SDK here (React Native
  # builds put platforms, build-tools and ndk in it). Fill only the two pieces
  # it still lacks, each with a symlink into the read-only store tree so a
  # future manual install by the user simply replaces the link instead of
  # fighting it.
  system.activationScripts.t3AndroidSdk = lib.stringAfter ["users"] ''
    target=/home/grajpap/Android/Sdk

    fill() {
      # fill <path-under-Sdk> <store-path>: skip anything that already exists,
      # Nix never overwrites a working piece of the SDK.
      if [ ! -e "$target/$1" ] && [ ! -L "$target/$1" ]; then
        mkdir -p "$(dirname "$target/$1")"
        ln -s "$2" "$target/$1"
        echo "t3-devices: filled $target/$1"
      fi
    }

    fill "emulator" "${t3AndroidSdk}/emulator"
    fill "cmdline-tools/latest" "${t3AndroidSdk}/cmdline-tools/latest"
  '';

  # avdmanager/sdkmanager stay reachable for the rare case they are needed.
  # adb is NOT exportable: android-tools from ./adb.nix stays the fleet's adb.
  environment.systemPackages = [
    (pkgs.runCommand "t3-android-sdk-bin" {} ''
      mkdir -p $out/bin
      ln -s ${t3AndroidSdk}/cmdline-tools/latest/bin/avdmanager $out/bin/avdmanager
      ln -s ${t3AndroidSdk}/cmdline-tools/latest/bin/sdkmanager $out/bin/sdkmanager
    '')
  ];
}
