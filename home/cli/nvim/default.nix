_: {
  xdg.configFile = {
    "nvim/init.lua".source = ./init.lua;
    "nvim/.luarc.json".source = ./.luarc.json;
    "nvim/lazy-lock.json".source = ./lazy-lock.json;
    "nvim/lua".source = ./lua;
  };

  home.file.".vim/undodir/.keep".text = "";
}
