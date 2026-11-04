# Self-hosted GitHub Actions runner for be-spotted/bespotted_codex.
#
# The repo workflows pick it through the CI_RUNNER repository variable. Setup and
# recovery: fleet/github-runner.md.
{
  config,
  pkgs,
  ...
}: let
  name = "bespotted";
  user = "github-runner";
  tokenFile = "/var/lib/github-runner-tokens/${name}.token";
  # The default work dir is on tmpfs, too small for an Android build, and the
  # module wipes it on every start. The cache dir survives that.
  workDir = "/var/lib/github-runner-work/${name}";
  cacheDir = "/var/lib/github-runner-cache/${name}";
  nixLd = "/run/current-system/sw/share/nix-ld/lib";

  # The Nix store SDK is read-only, so Gradle cannot download what is missing.
  # React Native 0.85 and its native modules ask for exactly these versions.
  androidSdk =
    (pkgs.androidenv.composeAndroidPackages {
      platformVersions = ["36"];
      buildToolsVersions = ["36.0.0"];
      includeNDK = true;
      ndkVersions = ["27.1.12297006" "27.0.12077973"];
      cmakeVersions = ["3.22.1"];
    }).androidsdk;
  androidHome = "${androidSdk}/libexec/android-sdk";
in {
  services.github-runners.${name} = {
    enable = true;
    url = "https://github.com/be-spotted/bespotted_codex";
    inherit tokenFile user workDir;
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
      # This is the desktop: CI yields to whatever is running on it.
      CPUWeight = 20;
      IOWeight = 20;
      Nice = 10;
    };
  };

  # Stay inactive, not failed, until the token exists, so a rebuild cannot fail on it.
  systemd = {
    services."github-runner-${name}".unitConfig.ConditionPathExists = tokenFile;
    tmpfiles.rules = [
      "d ${dirOf tokenFile} 0700 root root -"
      "d ${dirOf workDir} 0755 root root -"
      "d ${workDir} 0750 ${user} ${user} -"
      "d ${dirOf cacheDir} 0755 root root -"
      "d ${cacheDir} 0750 ${user} ${user} -"
    ];
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
