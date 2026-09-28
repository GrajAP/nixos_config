{
  inputs,
  config,
  lib,
  ...
}: {
  imports = [
    ./system
    ./theme
  ];

  options.fleet.heavy.enable = lib.mkEnableOption "PC-only heavy extras (gaming, Android Studio, hosting)";

  config = {
    stylix.enableReleaseChecks = false;

    home-manager = {
      backupFileExtension = "hm-backup";
      extraSpecialArgs = {
        inherit inputs;
        heavy = config.fleet.heavy.enable;
      };
      useGlobalPkgs = true;
      useUserPackages = true;
      users.grajpap = {
        home.stateVersion = "24.11";
        home.enableNixpkgsReleaseCheck = false;
        imports = [
          ./home
        ];
      };
    };
  };
}
