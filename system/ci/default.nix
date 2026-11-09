# Self-hosted GitHub Actions runners for be-spotted/bespotted_codex.
#
# The repo workflows pick them through the CI_RUNNER repository variable. Setup and
# recovery: fleet/github-runner.md.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # One runner ran every job of every PR in a row. Each name is its own runner
  # with its own registration, work dir and Rust build output.
  names = ["bespotted" "bespotted-2" "bespotted-3"];
  user = "github-runner";
  tokenFile = name: "/var/lib/github-runner-tokens/${name}.token";
  # The default work dir is on tmpfs, too small for an Android build, and the
  # module wipes it on every start. The cache dir survives that.
  workDir = name: "/var/lib/github-runner-work/${name}";
  # Shared by all runners: Cargo, rustup and Gradle lock their own caches.
  cacheDir = "/var/lib/github-runner-cache/bespotted";
  nixLd = "/run/current-system/sw/share/nix-ld/lib";

  # The Nix store SDK is read-only, so Gradle cannot download what is missing.
  # React Native 0.85 and its native modules ask for exactly these versions.
  androidSdk =
    (pkgs.androidenv.composeAndroidPackages {
      platformVersions = ["33" "35" "36"];
      buildToolsVersions = ["35.0.0" "36.0.0"];
      includeNDK = true;
      ndkVersions = ["27.1.12297006" "27.0.12077973"];
      cmakeVersions = ["3.22.1"];
    }).androidsdk;
  androidHome = "${androidSdk}/libexec/android-sdk";

  runner = name: {
    enable = true;
    url = "https://github.com/be-spotted/bespotted_codex";
    tokenFile = tokenFile name;
    workDir = workDir name;
    inherit user;
    group = user;
    replace = true;
    extraLabels = ["grajpap-ci"];
    extraPackages = with pkgs; [
      config.virtualisation.docker.package
      curl
      ffmpeg
      file
      findutils
      gawk
      gcc
      gnugrep
      gnumake
      gnused
      pkg-config
      python3
      rustup
      unzip
      which
      xz
      zstd
    ];
    extraEnvironment = {
      ANDROID_HOME = androidHome;
      ANDROID_SDK_ROOT = androidHome;
      CARGO_HOME = "${cacheDir}/cargo";
      # actions/checkout wipes backend/target, so the backend compiled from zero
      # on every job. Outside the checkout the build stays incremental.
      CARGO_TARGET_DIR = "${cacheDir}/cargo-target/${name}";
      RUSTUP_HOME = "${cacheDir}/rustup";
      # Actions on the deprecated Node 20 runtime, the runner only ships Node 24.
      FORCE_JAVASCRIPT_ACTIONS_TO_NODE24 = "true";
      # setup-node, setup-java, rustup and Gradle download generic Linux binaries.
      NIX_LD = "${nixLd}/ld.so";
      NIX_LD_LIBRARY_PATH = nixLd;
    };
    serviceOverrides = {
      # Docker socket access for service containers and `docker build`.
      # PrivateUsers would map the docker group away from this service.
      PrivateUsers = false;
      # The runner reads /proc/1/cgroup before it starts service containers.
      ProtectProc = "default";
      ReadWritePaths = [cacheDir];
      # The module never restarts a crashed runner, and a full disk once left CI
      # down until someone noticed.
      Restart = lib.mkForce "always";
      RestartSec = "30s";
      # This is the desktop: CI yields to whatever is running on it.
      CPUWeight = 20;
      IOWeight = 20;
      Nice = 10;
    };
  };
in {
  services.github-runners = lib.genAttrs names runner;

  # Stay inactive, not failed, until the token exists, so a rebuild cannot fail on it.
  systemd = {
    services = lib.listToAttrs (map (name:
      lib.nameValuePair "github-runner-${name}" {
        unitConfig.ConditionPathExists = tokenFile name;
      })
    names);
    tmpfiles.rules =
      [
        "d /var/lib/github-runner-tokens 0700 root root -"
        "d /var/lib/github-runner-work 0755 root root -"
        "d ${dirOf cacheDir} 0755 root root -"
        "d ${cacheDir} 0750 ${user} ${user} -"
      ]
      ++ map (name: "d ${workDir name} 0750 ${user} ${user} -") names;
  };

  # A fixed home, because Gradle reads it from passwd and not from $HOME.
  users = {
    groups.${user} = {};
    users.${user} = {
      isSystemUser = true;
      group = user;
      extraGroups = ["docker"];
      home = cacheDir;
    };
  };
}
