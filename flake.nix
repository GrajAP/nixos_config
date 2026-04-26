{
  description = "grajpap.nix";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    stylix.url = "github:danth/stylix";
    hyprcontrib = {
      url = "github:hyprwm/contrib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # hyprland.url = "github:hyprwm/Hyprland";
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    helium-browser = {
      url = "github:ominit/helium-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    anyrun = {
      url = "github:anyrun-org/anyrun";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    sharedModules = [
      ./configuration.nix
      inputs.stylix.nixosModules.stylix
      inputs.home-manager.nixosModules.home-manager
      inputs.spicetify-nix.nixosModules.default
    ];
  in {
    nixosConfigurations.grajpap = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs;};
      modules =
        [
          (import ./hosts/grajpap)
        ]
        ++ sharedModules;
    };

    nixosConfigurations.grajpap-iso = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs;};
      modules =
        [
          ./hosts/grajpap/iso.nix
        ]
        ++ sharedModules;
    };

    packages.${system}.grajpap-iso =
      self.nixosConfigurations.grajpap-iso.config.system.build.isoImage;
  };
}
