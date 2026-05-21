{pkgs, ...}: {
  boot.kernelModules = ["ntfs3"];

  environment.systemPackages = with pkgs; [
    ntfs3g
  ];

  services.udisks2.enable = true;

  services.devmon.enable = true;

  services.gvfs.enable = true;
}
