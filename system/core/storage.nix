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

  ssd2Disk = "/dev/disk/by-id/ata-SSDPR-CX400-512_GT9010423";
in {
  environment.systemPackages = with pkgs; [
    ntfs3g
    xfsprogs
  ];

  # LVM-VDO (dedup + LZ4 compression) backing the SSD2 XFS volume.
  services.lvm.boot.vdo.enable = true;
  boot.kernelModules = ["dm-vdo"];

  systemd.services.ssd2-vdo-provision = {
    description = "One-time LVM-VDO + XFS provisioning of the SSD2 drive";
    wantedBy = ["multi-user.target"];
    after = ["systemd-modules-load.service"];
    unitConfig.ConditionVirtualization = "!container";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = with pkgs; [lvm2_vdo xfsprogs util-linux kmod];
    script = ''
      modprobe dm_vdo 2>/dev/null || true

      # Idempotent: only touch the disk while the VG is absent.  The VG name
      # doubles as the guard against ever re-wiping a provisioned volume.
      if ! vgs ssd2 >/dev/null 2>&1; then
        disk="$(readlink -f "${ssd2Disk}")"

        # Release stale automounts (GVfs/udisks) holding the disk busy.
        for attempt in 1 2 3 4 5; do
          busy=0
          while read -r src tgt; do
            case "$src" in
              "$disk" | "$disk"[0-9]* | "${ssd2Disk}" | "${ssd2Disk}"-part[0-9]*)
                umount "$tgt" 2>/dev/null || umount -l "$tgt" 2>/dev/null || true
                busy=1
                ;;
            esac
          done < <(findmnt -rno SOURCE,TARGET)
          [[ "$busy" == 0 ]] && break
          sleep 1
        done

        wipefs -a "${ssd2Disk}-part1" 2>/dev/null || true
        wipefs -a "${ssd2Disk}"
        partprobe "${ssd2Disk}" 2>/dev/null || true

        pvcreate -f "${ssd2Disk}"
        vgcreate ssd2 "${ssd2Disk}"
        lvcreate --type vdo --name vdo0 --virtualsize 700G --yes ssd2
        mkfs.xfs -L SSD2 -K /dev/ssd2/vdo0
        mkdir -p /mnt/SSD2
        mount /dev/ssd2/vdo0 /mnt/SSD2
        chown grajpap:users /mnt/SSD2
        umount /mnt/SSD2
      fi
    '';
  };

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
    "/mnt/SSD2" = {
      device = "/dev/mapper/ssd2--vdo0";
      fsType = "xfs";
      options = [
        "discard"
        "nofail"
        "x-systemd.requires=ssd2-vdo-provision.service"
        "x-gvfs-show"
        "x-gvfs-name=SSD2"
      ];
    };
  };
}
