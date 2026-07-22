{pkgs}:
with pkgs;
  (with vscode-extensions; [
    bradlc.vscode-tailwindcss
    catppuccin.catppuccin-vsc
    catppuccin.catppuccin-vsc-icons
    dbaeumer.vscode-eslint
    hars.cppsnippets
    jnoortheen.nix-ide
    ms-ceintl.vscode-language-pack-pl
    ms-vscode.live-server
    ms-vsliveshare.vsliveshare
    naumovs.color-highlight
    prettier.prettier-vscode
    redhat.vscode-yaml
    vscodevim.vim
  ])
  ++ vscode-utils.extensionsFromVscodeMarketplace [
    {
      name = "vscode-expo-tools";
      publisher = "expo";
      version = "1.6.3";
      sha256 = "sha256-vqT/72pUyHtzl0rmUfDgbr7MO+/2dw3EcDeYTkQY/0Y=";
    }
    {
      name = "vscode-react-native";
      publisher = "msjsdiag";
      version = "1.13.0";
      sha256 = "sha256-zryzoO9sb1+Kszwup5EhnN/YDmAPz7TOQW9I/K28Fmg=";
    }
  ]
