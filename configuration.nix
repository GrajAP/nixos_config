{inputs, ...}: {
  imports = [
    ./system
    ./theme
  ];

  nixpkgs.config.permittedInsecurePackages = [
    "pnpm-10.29.2"
  ];

  stylix.enableReleaseChecks = false;

  home-manager = {
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {inherit inputs;};
    useUserPackages = true;
    users.grajpap = {
      home.stateVersion = "24.11";
      home.enableNixpkgsReleaseCheck = false;
      imports = [
        ./home
      ];
    };
  };
}
