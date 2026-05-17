{inputs, ...}: {
  imports = [
    ./system
    ./theme
  ];

  home-manager = {
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {inherit inputs;};
    useUserPackages = true;
    users.grajpap = {
      home.stateVersion = "24.11";
      imports = [
        ./home
      ];
    };
  };
}
