{pkgs, ...}: {
  home.packages = with pkgs; [
    (writeShellScriptBin "htop" ''exec btop "$@"'')
    (writeShellScriptBin "top" ''exec btop "$@"'')
  ];

  programs.btop = {
    enable = true;
    settings = {
      proc_tree = true;
      proc_sorting = "cpu lazy";
    };
  };
}
