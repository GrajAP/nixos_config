{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkDefault mkIf;
  inherit (config.fleet) bootloader dualBoot;
  grubBoot = bootloader == "grub";
in {
  options.fleet = {
    dualBoot = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether this host dual-boots Windows alongside NixOS.

        Only meaningful when `fleet.bootloader` is `grub`, which is where the
        hand-written "Windows Boot Manager" menu entry lives. Leave it off for
        single-boot hosts.

        It also gates the kernel parameters that exist only to coax a Windows
        disk out of an unready PCIe/NVMe controller. On battery-powered
        machines `pcie_aspm=off` and `nvme.noacpi=1` are actively harmful: they
        pin link power management off, which measurably raises idle draw.
      '';
    };

    bootloader = lib.mkOption {
      type = lib.types.enum ["grub" "systemd-boot"];
      default = "grub";
      description = ''
        Which EFI bootloader this host uses.

        This is a per-host decision and must match what is already installed.
        Switching a machine from one to the other is a manual, non-remotable
        operation, so get it wrong and the host does not come back: systemd-boot
        manages `/boot/loader` and writes one `.efi` entry per kernel, whereas
        GRUB keeps a single `grub.cfg` and needs the Windows chainloader entry
        when dual-booting.

        - `grub`: the desktop default. grajpap has always been GRUB.
        - `systemd-boot`: dell was installed with systemd-boot.
      '';
    };
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
        ++ lib.optionals dualBoot [
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
      supportedFilesystems = mkIf dualBoot ["ntfs"];
      loader =
        {
          efi.canTouchEfiVariables = true;
          efi.efiSysMountPoint = "/boot";
          timeout = 1;
        }
        // {
          grub = mkIf grubBoot {
            enable = true;
            # Entry 0 is NixOS. On a dual-boot host that shifts to 1 once the
            # Windows entry is appended below.
            default =
              if dualBoot
              then 1
              else 0;
            device = "nodev";
            useOSProber = false;
            efiSupport = true;
            extraConfig = mkIf dualBoot ''
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
          # systemd-boot is the default on most modern installs, so the opt-in has
          # to win explicitly rather than merely being absent.
          systemd-boot = {
            enable = mkIf (!grubBoot) true;
            editor = false;
          };
        };
    };
  };
}
