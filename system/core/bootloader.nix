{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkDefault mkIf;
in {
  options.fleet.dualBoot = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Whether this host dual-boots Windows alongside NixOS.

      GRUB stays enabled either way (it is already installed on every desktop
      host, and swapping bootloaders is a manual, non-remotable operation).
      What this flag actually controls is the hand-written "Windows Boot
      Manager" menu entry and the kernel parameters that exist only to coax a
      Windows disk out of an unready PCIe/NVMe controller.

      Leave it off for single-boot hosts. On battery-powered machines the
      `pcie_aspm=off` / `nvme.noacpi=1` workarounds are actively harmful:
      they pin link power management off, which measurably raises idle draw.
    '';
  };

  config = {
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
      # Zen everywhere, on purpose: better scheduler and preemption behaviour
      # for interactive desktop work, and the best-behaved kernel for battery
      # life (it parks cores properly instead of spinning them at low load).
      kernelPackages = mkDefault pkgs.linuxPackages_zen;
      kernelParams =
        [
          "8250.nr_uarts=0"
          "psmouse.synaptics_intertouch=1"
        ]
        ++ lib.optionals config.fleet.dualBoot [
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
      # ntfs-3g is only needed to touch a Windows partition, and shipping it on a
      # single-boot host just widens the attack surface for no benefit.
      supportedFilesystems = mkIf config.fleet.dualBoot ["ntfs"];
      loader = {
        efi.canTouchEfiVariables = true;
        efi.efiSysMountPoint = "/boot";
        timeout = 1;
        grub = {
          enable = true;
          # Entry 0 is NixOS. On a dual-boot host that shifts to 1 once the
          # Windows entry is appended below.
          default =
            if config.fleet.dualBoot
            then 1
            else 0;
          device = "nodev";
          useOSProber = false;
          efiSupport = true;
          extraConfig = mkIf config.fleet.dualBoot ''
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
  };
}
