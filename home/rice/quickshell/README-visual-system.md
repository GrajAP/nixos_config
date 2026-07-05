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
