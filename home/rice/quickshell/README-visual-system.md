# Quickshell visual system

The shell should feel like a native desktop surface, not a web dashboard.

Rules:
- `Theme.qml` owns colors, radii, spacing, motion, and font roles.
- Use `Theme.fontSans` for labels and prose.
- Use `Theme.fontMono` for clocks, numbers, compact status, and diagnostic text.
- Use `Theme.fontIcon` for Nerd Font glyphs.
- Panels open from their physical anchor and use `Theme.motionPanel`.
- Hover/press feedback should be subtle: color shift plus tiny scale, never large bounce.
- Add visual effects only when they communicate state or hierarchy.

## Widget Surfaces

- Bar-launched widgets must use one of two surface classes.
- Fullscreen widgets fill the screen area outside the bar and are reserved for dense work surfaces such as Calendar and the keybind helper.
- Small widgets use the shared compact panel size and anchored bar behavior used by Spotify, audio, weather, clipboard, Codex, shutdown and tray.
- Do not introduce one-off widget dimensions unless the surface is promoted to fullscreen or deliberately moved out of the bar widget system.

## Motion

- Use shared theme timing tokens instead of literal durations when possible.
- Micro feedback, such as icon hover, pressed states, and small list movement, should use `Theme.motionFast`.
- Inline UI transitions, such as selection changes and compact controls, should use `Theme.motionMedium`.
- Bar widgets and anchored panels should use `Theme.motionPanel`; keep them calm enough to read, but never slower than the user action.
- Fullscreen overlays and modal surfaces should use `Theme.motionModal`.
- Prefer `Easing.OutCubic` for open/close movement and opacity. Avoid springy or bouncing easing unless the surface is explicitly playful.
- Hover-open widgets may use a short close delay so moving from the bar icon into the panel does not accidentally dismiss it.

## File layout

- `shell.qml` owns IPC handlers, shared actions, the bar, widget routing and lock surface.
- Event-backed runtime models belong in focused singleton files. `WorkspaceState.qml` derives workspace and client state from Quickshell's Hyprland model and raw events, without periodic `hyprctl` processes.
- Bar subviews with their own interaction model, such as workspace app grouping, clipboard history, tray or weather, should live in focused component files and receive `shell` as their state/action boundary.
- Widget routes must use `Loader` and stay inactive while their surface is closed. Heavy inline surfaces may remain in a `Component` during an incremental extraction, because `Component` keeps their object trees lazy.
- Keep extracted components medium-sized and cohesive. Split by visible surface or interaction model, not by tiny helper fragments.
- `*Window.qml` files are standalone overlay windows extracted from the main shell. They receive `shell` as a required property and should not duplicate global state.
- `default.nix` wires generated helper scripts, theme values, QML files and the systemd user service.
- New large overlays should be added as their own `SomethingWindow.qml` file and registered in `default.nix` and `qmldir`.
