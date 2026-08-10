{pkgs, ...}: {
  boot.kernelModules = ["kvm_amd"];

  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    virt-manager
    virt-viewer
    spice-gtk
    spice-protocol
    virtio-win
    win-spice
  ];

  users.users.grajpap.extraGroups = ["libvirtd"];
}
