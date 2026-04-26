{pkgs, ...}: {
  home.packages = with pkgs; [
    android-studio
    scrcpy
  ];

  home.sessionVariables = {
    EXPO_CLI_PASSWORD_PROMPT = "false";
    REACT_NATIVE_PACKAGER_HOSTNAME = "localhost";
  };
}
