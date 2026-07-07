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

## Motion

- Use shared theme timing tokens instead of literal durations when possible.
- Micro feedback, such as icon hover, pressed states, and small list movement, should use `Theme.motionFast`.
- Inline UI transitions, such as selection changes and compact controls, should use `Theme.motionMedium`.
- Bar widgets and anchored panels should use `Theme.motionPanel`; keep them calm enough to read, but never slower than the user action.
- Fullscreen overlays and modal surfaces should use `Theme.motionModal`.
- Prefer `Easing.OutQuart` for anchored panel open/close movement and `Easing.OutCubic` for small opacity or hover feedback. Avoid springy or bouncing easing unless the surface is explicitly playful.
- Hover-open widgets may use a short close delay so moving from the bar icon into the panel does not accidentally dismiss it.

## File layout

- `shell.qml` owns global state, IPC handlers, processes, shared functions, the bar, notification history, widgets and lock surface.
- `*Window.qml` files are standalone overlay windows extracted from the main shell. They receive `shell` as a required property and should not duplicate global state.
- `default.nix` wires generated helper scripts, theme values, QML files and the systemd user service.
- New large overlays should be added as their own `SomethingWindow.qml` file and registered in `default.nix` and `qmldir`.
