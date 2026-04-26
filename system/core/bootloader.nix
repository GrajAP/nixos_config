{
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkDefault;
in {
  environment.systemPackages = with pkgs; [
    # For debugging and troubleshooting Secure Boot.
    os-prober
    sbctl
  ];
  boot = {
    binfmt.emulatedSystems = ["aarch64-linux"];
    blacklistedKernelModules = ["ntfs3"];
    tmp = {
      cleanOnBoot = true;
      useTmpfs = false;
    };
    # some kernel parameters, i dont remember what half of this shit does but who cares
    consoleLogLevel = mkDefault 0;
    initrd.verbose = false;
    kernelPackages = mkDefault pkgs.linuxPackages;
    kernelParams = [
      "psmouse.synaptics_intertouch=1"
      "intel_pstate=disable"
    ];
    extraModprobeConfig = ''
      options i915 enable_fbc=1 enable_guc=2
      options snd-intel-dspcfg dsp_driver=1
      options snd_hda_intel enable=1,1 power_save=1 power_save_controller=Y
    '';
    supportedFilesystems = ["ntfs"];
    loader = {
      efi.canTouchEfiVariables = true;
      efi.efiSysMountPoint = "/boot";
      grub = {
        enable = true;
        device = "nodev";
        useOSProber = true;
        efiSupport = true;
      };
    };
  };
}
