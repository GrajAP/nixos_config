{
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkDefault;
in {
  environment.systemPackages = with pkgs; [
    # For debugging and troubleshooting Secure Boot.
    sbctl
  ];
  boot = {
    binfmt.emulatedSystems = ["aarch64-linux"];
    blacklistedKernelModules = ["ntfs3"];
    tmp = {
      cleanOnBoot = true;
      useTmpfs = false;
    };
    consoleLogLevel = mkDefault 0;
    initrd.verbose = false;
    kernelPackages = mkDefault pkgs.linuxPackages_zen;
    kernelParams = [
      "8250.nr_uarts=0"
      "psmouse.synaptics_intertouch=1"
      # One Realtek RTS5765DL NVMe controller can stay in a not-ready state
      # during Linux probe; avoid aggressive PCIe/NVMe power management so the
      # Windows disk behind it has a chance to enumerate before GRUB/Linux use it.
      "nvme_core.default_ps_max_latency_us=0"
      "nvme_core.admin_timeout=60"
      "nvme.noacpi=1"
      "pcie_aspm=off"
    ];
    extraModprobeConfig = ''
      options snd_hda_intel enable=1,1 power_save=1 power_save_controller=Y
    '';
    supportedFilesystems = ["ntfs"];
    loader = {
      efi.canTouchEfiVariables = true;
      efi.efiSysMountPoint = "/boot";
      timeout = 1;
      grub = {
        enable = true;
        default = 1;
        device = "nodev";
        useOSProber = false;
        efiSupport = true;
        extraConfig = ''
          # Dual-boot Windows entry without running os-prober at boot.
          menuentry "Windows Boot Manager" {
            insmod part_gpt
            insmod fat
            insmod chain
            search --file --set=root /EFI/Microsoft/Boot/bootmgfw.efi
            chainloader /EFI/Microsoft/Boot/bootmgfw.efi
          }
        '';
      };
    };
  };
}
