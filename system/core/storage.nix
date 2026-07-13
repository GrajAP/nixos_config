{
  config,
  pkgs,
  ...
}: let
  # Keep Windows data volumes available at stable paths.  systemd's automount
  # units avoid delaying boot when a drive is absent, while GVFS exposes them
  # in graphical file managers without requiring a manual UDisks mount first.
  windowsVolume = uuid: label: group: mask: {
    device = "/dev/disk/by-uuid/${uuid}";
    fsType = "ntfs-3g";
    options = [
      "nofail"
      "x-systemd.automount"
      "x-systemd.device-timeout=1s"
      "uid=1000"
      "gid=${group}"
      "umask=${mask}"
      "windows_names"
      "x-gvfs-show"
      "x-gvfs-name=${label}"
    ];
  };
in {
  environment.systemPackages = with pkgs; [
    ntfs3g
  ];

  assertions = [
    {
      assertion = builtins.all (module: !(builtins.elem module config.boot.blacklistedKernelModules)) config.boot.kernelModules;
      message = "A kernel module cannot be both loaded and blacklisted.";
    }
  ];

  users = {
    groups.storage-share.gid = 970;
    users = {
      grajpap.extraGroups = ["storage-share"];
      nextcloud.extraGroups = ["storage-share"];
    };
  };

  fileSystems = {
    "/mnt/Storage" = windowsVolume "D62C7B212C7AFC35" "Storage" "970" "0002";
    "/mnt/HDD" = windowsVolume "181ACB431ACB1C9E" "HDD" "100" "0022";
    "/mnt/Windows" = windowsVolume "FC0084040083C3DC" "Windows" "100" "0022";
    "/mnt/NVME128" = windowsVolume "F852327652323A28" "NVME128" "100" "0022";
  };
}
