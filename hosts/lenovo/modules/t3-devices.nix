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
  # unset, so expose the store tree there. A symlink keeps it undeclared
  # state owned by NixOS: the pointer moves on the next switch, nothing else
  # in /home changes.
  system.activationScripts.t3AndroidSdk = lib.stringAfter ["users"] ''
    target=/home/grajpap/Android/Sdk
    if [ -e "$target" ] && [ ! -L "$target" ]; then
      echo "warning: $target exists and is not a symlink; leaving it alone" >&2
      exit 0
    fi

    mkdir -p "$(dirname "$target")"
    ln -sfn "${t3AndroidSdk}" "$target"
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
