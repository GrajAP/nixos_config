{
  lib,
  modulesPath,
  pkgs,
  ...
}: {
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-graphical-base.nix")
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "grajpap-iso";

  boot.loader.grub.enable = lib.mkForce false;

  boot.consoleLogLevel = lib.mkForce 4;
  boot.initrd.verbose = lib.mkForce true;

  boot.kernelParams = lib.mkForce [
    "root=/dev/nix/root"
    "rd.overlay=0"
    "loglevel=4"
  ];

  image.fileName = "grajpap-live-${pkgs.stdenv.hostPlatform.system}.iso";

  isoImage.squashfsCompression = "zstd -Xcompression-level 6";

  boot.blacklistedKernelModules = [
    "hv_balloon"
    "hv_vmbus"
    "hv_storvsc"
    "hv_utils"
    "hv_netvsc"
    "virtio_balloon"
    "virtio_blk"
    "virtio_scsi"
    "virtio_net"
    "virtio_pci"
    "virtio_mmio"
    "virtio_console"
    "vmw_balloon"
    "vmw_vmci"
    "vmw_vsock_vmci_transport"
    "vmxnet3"
  ];

  users.users.grajpap = {
    initialPassword = "nixos";
    hashedPassword = lib.mkForce null;
  };

  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "24.11";
}
