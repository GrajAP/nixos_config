{
  config,
  lib,
  ipc,
}: let
  mod = "SUPER";
  modshift = "${mod} SHIFT";

  binding = mode: category: combo: dispatcher: description: {
    inherit mode category combo dispatcher description;
  };

  workspaces = builtins.concatLists (builtins.genList (
      x: let
        ws = let
          c = (x + 1) / 10;
        in
          toString (x + 1 - (c * 10));
        number = toString (x + 1);
      in [
        (binding "bind" "Workspaces" "${mod}, ${ws}" "workspace, ${number}" "Switch to workspace ${number}")
        (binding "bind" "Workspaces" "${mod} SHIFT, ${ws}" "movetoworkspace, ${number}" "Move active window to workspace ${number}")
      ]
    )
    10);

  entries =
    [
      (binding "bind" "Launchers" "${mod}, RETURN" ''exec, foot${lib.optionalString config.programs.foot.server.enable "client"} -e sh -c 'exec tmux' '' "Open terminal")
      (binding "bind" "Launchers" "${mod}, SPACE" "global, quickshell:launcher" "Toggle application launcher")
      (binding "bind" "Launchers" "${mod}, F" ''exec, helium --profile-path="${config.home.homeDirectory}/.config/net.imput.helium/Default"'' "Open Helium browser")
      (binding "bind" "Launchers" "${mod}, D" "exec, vesktop" "Open Vesktop")
      (binding "bind" "Launchers" "${mod}, E" "exec, nemo" "Open file manager")
      (binding "bind" "Launchers" "${mod}, PERIOD" "exec, emote" "Open emoji picker")

      (binding "bind" "Windows" "${mod}, C" "killactive" "Close active window")
      (binding "bind" "Windows" "${mod}, V" "togglefloating" "Toggle floating")
      (binding "bind" "Windows" "${mod}, F11" "fullscreen" "Toggle fullscreen")
      (binding "bind" "Windows" "${modshift}, H" "movewindow, l" "Move window left")
      (binding "bind" "Windows" "${modshift}, J" "movetoworkspace, +1" "Move window to next workspace")
      (binding "bind" "Windows" "${modshift}, K" "movetoworkspace, -1" "Move window to previous workspace")
      (binding "bind" "Windows" "${modshift}, L" "movewindow, r" "Move window right")
      (binding "binde" "Windows" "${mod}, H" "movefocus, l" "Focus left")
      (binding "binde" "Windows" "${mod}, J" "movefocus, d" "Focus down")
      (binding "binde" "Windows" "${mod}, K" "movefocus, u" "Focus up")
      (binding "binde" "Windows" "${mod}, L" "movefocus, r" "Focus right")
      (binding "binde" "Windows" "${mod} Control_L, H" "resizeactive, -80 0" "Resize window narrower")
      (binding "binde" "Windows" "${mod} Control_L, J" "resizeactive, 0 80" "Resize window taller")
      (binding "binde" "Windows" "${mod} Control_L, K" "resizeactive, 0 -80" "Resize window shorter")
      (binding "binde" "Windows" "${mod} Control_L, L" "resizeactive, 80 0" "Resize window wider")
      (binding "bindm" "Windows" "${mod}, mouse:272" "movewindow" "Drag window")
      (binding "bindm" "Windows" "${mod}, mouse:273" "resizewindow" "Resize window with mouse")

      (binding "bind" "Special workspaces" "${mod}, A" "exec, toggle-special-workspace social" "Toggle social special workspace")
      (binding "bind" "Special workspaces" "${modshift}, A" "exec, move-special-workspace social" "Move window to social special workspace")
      (binding "bind" "Special workspaces" "${mod}, W" "exec, toggle-special-workspace tools" "Toggle tools special workspace")
      (binding "bind" "Special workspaces" "${modshift}, W" "exec, move-special-workspace tools" "Move window to tools special workspace")
      (binding "bind" "Special workspaces" "${mod}, Z" "exec, toggle-special-workspace scratchpad" "Toggle scratchpad")
      (binding "bind" "Special workspaces" "${modshift}, Z" "exec, move-special-workspace scratchpad" "Move window to scratchpad")
      (binding "bind" "Special workspaces" "${mod}, O" "exec, toggle-obs-special" "Toggle OBS special workspace")
      (binding "bind" "Special workspaces" "${modshift}, O" "exec, move-special-workspace obs" "Move window to OBS special workspace")

      (binding "bind" "Quickshell" "${mod}, SLASH" "global, quickshell:keybindHelp" "Show keybind help")
      (binding "bind" "Quickshell" "${mod}, SEMICOLON" "global, quickshell:powerMenu" "Open power menu")
      (binding "bind" "Quickshell" "${mod}, B" "global, quickshell:toggleBar" "Toggle desktop bar")
      (binding "bind" "Quickshell" "${mod}, N" "global, quickshell:notifications" "Toggle notification history")
      (binding "bind" "Quickshell" "${modshift}, N" "exec, ${ipc} notifications clear" "Clear notification history")
      (binding "bind" "Quickshell" "${mod}, P" "global, quickshell:clipboardHistory" "Toggle clipboard history")
      (binding "bind" "Quickshell" "${modshift}, P" "exec, ${ipc} clipboard clear" "Clear clipboard history")
      (binding "bind" "Quickshell" ", PRINT" "exec, ${ipc} tools screenshotEdit" "Select screenshot area and edit")
      (binding "bind" "Quickshell" ", PAUSE" "exec, ${ipc} tools voiceStart" "Start voice dictation")
      (binding "bindr" "Quickshell" ", PAUSE" "exec, ${ipc} tools voiceStop" "Stop voice dictation")
      (binding "bind" "Quickshell" "${mod}, Q" "exec, katana-switch" "Toggle Kanata layout")

      (binding "bindr" "Writing" "${mod}, G" "exec, spark-corrector selection" "Correct selected Polish or English text")

      (binding "bind" "Hardware" ", XF86Bluetooth" "exec, bcn" "Toggle Bluetooth")
      (binding "binde" "Hardware" ", XF86AudioRaiseVolume" "exec, pamixer -i 5 && ${ipc} osd volume" "Raise volume")
      (binding "binde" "Hardware" ", XF86AudioLowerVolume" "exec, pamixer -d 5 && ${ipc} osd volume" "Lower volume")
      (binding "binde" "Hardware" ", XF86AudioMute" "exec, pamixer -t && ${ipc} osd volume" "Mute speakers")
      (binding "binde" "Hardware" ", XF86AudioMicMute" "exec, micmute" "Mute microphone")
      (binding "binde" "Hardware" ", XF86MonBrightnessUp" "exec, brightnessctl set 10%+ && ${ipc} osd brightness" "Raise brightness")
      (binding "binde" "Hardware" ", XF86MonBrightnessDown" "exec, brightnessctl set 10%- && ${ipc} osd brightness" "Lower brightness")
      (binding "bindl" "Media" ", XF86AudioPlay" "exec, playerctl play-pause" "Play or pause media")
      (binding "bindl" "Media" ", XF86AudioPrev" "exec, playerctl previous" "Previous track")
      (binding "bindl" "Media" ", XF86AudioNext" "exec, playerctl next" "Next track")

      (binding "bind" "Zoom" "${modshift}, mouse_down" "exec, hyprctl -q keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor -j | jq '.float * 1.5')" "Zoom in")
      (binding "bind" "Zoom" "${modshift}, mouse_up" "exec, hyprctl -q keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor -j | jq '(.float / 1.5) | if . < 1 then 1 else . end')" "Zoom out")
    ]
    ++ workspaces;

  toHyprland = entry: "${entry.combo}, ${entry.dispatcher}";
  helpEntry = entry: {
    inherit (entry) category description;
    combo =
      lib.replaceStrings
      ["SUPER" "SHIFT" "Control_L" "RETURN" "SPACE" "TAB" "PERIOD" "SEMICOLON" "SLASH" "PRINT" "PAUSE" "mouse:272" "mouse:273" "mouse_down" "mouse_up"]
      ["Mod" "Shift" "Ctrl" "Enter" "Space" "Tab" "." ";" "/" "Print" "Pause" "Mouse Left" "Mouse Right" "Wheel Down" "Wheel Up"]
      entry.combo;
  };
in {
  inherit entries;
  bind = map toHyprland (builtins.filter (entry: entry.mode == "bind") entries);
  bindm = map toHyprland (builtins.filter (entry: entry.mode == "bindm") entries);
  bindr = map toHyprland (builtins.filter (entry: entry.mode == "bindr") entries);
  binde = map toHyprland (builtins.filter (entry: entry.mode == "binde") entries);
  bindl = map toHyprland (builtins.filter (entry: entry.mode == "bindl") entries);
  help = map helpEntry entries;
}
