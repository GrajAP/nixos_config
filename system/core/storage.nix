{pkgs, ...}: let
  # Keep Windows data volumes available at stable paths.  systemd's automount
  # units avoid delaying boot when a drive is absent, while GVFS exposes them
  # in graphical file managers without requiring a manual UDisks mount first.
  windowsVolume = uuid: label: {
    device = "/dev/disk/by-uuid/${uuid}";
    fsType = "ntfs-3g";
    options = [
      "nofail"
      "x-systemd.automount"
      "x-systemd.device-timeout=5s"
      "uid=1000"
      "gid=100"
      "umask=0022"
      "windows_names"
      "x-gvfs-show"
      "x-gvfs-name=${label}"
    ];
  };
in {
  boot.kernelModules = ["ntfs3"];

  environment.systemPackages = with pkgs; [
    ntfs3g
  ];

  services.udisks2.enable = true;

  services.devmon.enable = true;

  services.gvfs.enable = true;

  fileSystems = {
    "/mnt/Storage" = windowsVolume "D62C7B212C7AFC35" "Storage";
    "/mnt/HDD" = windowsVolume "181ACB431ACB1C9E" "HDD";
    "/mnt/Windows" = windowsVolume "FC0084040083C3DC" "Windows";
    "/mnt/NVME128" = windowsVolume "F852327652323A28" "NVME128";
  };
}
