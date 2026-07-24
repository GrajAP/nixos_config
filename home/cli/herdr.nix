{
  config,
  lib,
  pkgs,
  ...
}: {
  home.packages = [pkgs.herdr];

  xdg.configFile."herdr/config.toml".text = ''
    onboarding = false

    [theme]
    name = "catppuccin"
    auto_switch = false

    [theme.custom]
    accent = "${config.lib.stylix.colors.withHashtag.base0D}"
    blue = "${config.lib.stylix.colors.withHashtag.base0D}"
    green = "${config.lib.stylix.colors.withHashtag.base0B}"
    red = "${config.lib.stylix.colors.withHashtag.base08}"
    yellow = "${config.lib.stylix.colors.withHashtag.base0A}"

    [terminal]
    default_shell = "${lib.getExe pkgs.zsh}"
    shell_mode = "non_login"
    new_cwd = "follow"

    [update]
    channel = "stable"
    version_check = false
    manifest_check = true

    [keys]
    prefix = "ctrl+space"
    help = "prefix+?"
    settings = "prefix+s"
    detach = "prefix+q"
    reload_config = "prefix+shift+r"
    workspace_picker = "prefix+w"
    goto = "prefix+g"
    new_workspace = "prefix+shift+n"
    new_worktree = "prefix+shift+g"
    rename_workspace = "prefix+shift+w"
    close_workspace = "prefix+shift+d"
    new_tab = "prefix+c"
    rename_tab = "prefix+shift+t"
    previous_tab = "prefix+p"
    next_tab = "prefix+n"
    switch_tab = "prefix+1..9"
    close_tab = "prefix+shift+x"
    rename_pane = "prefix+shift+p"
    edit_scrollback = "prefix+e"
    focus_pane_left = "prefix+h"
    focus_pane_down = "prefix+j"
    focus_pane_up = "prefix+k"
    focus_pane_right = "prefix+l"
    cycle_pane_next = "prefix+tab"
    cycle_pane_previous = "prefix+shift+tab"
    split_vertical = "prefix+v"
    split_horizontal = "prefix+minus"
    close_pane = "prefix+x"
    zoom = "prefix+z"
    resize_mode = "prefix+r"
    toggle_sidebar = "prefix+b"
    navigate_workspace_up = "k"
    navigate_workspace_down = "j"
    navigate_pane_left = "h"
    navigate_pane_right = "l"

    [ui]
    accent = "${config.lib.stylix.colors.withHashtag.base0D}"
    mouse_capture = true
    copy_on_select = true
    pane_borders = true
    pane_gaps = true
    show_agent_labels_on_pane_borders = true
    agent_panel_sort = "priority"

    [ui.toast]
    delivery = "system"
    delay_seconds = 1

    [ui.toast.clipboard]
    enabled = true
    position = "bottom-center"

    [session]
    resume_agents_on_restore = true

    [remote]
    manage_ssh_config = true

    [experimental]
    pane_history = false
  '';
}
