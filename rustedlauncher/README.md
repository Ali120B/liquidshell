# rustedLauncher

A standalone Rust rewrite of **mylauncher**, the wofi/rofi-style application
launcher for Hyprland: tap SUPER, type, launch. Fuzzy search with
most-used-first ordering, app icons with a letter fallback, no animations.

The original Quickshell/QML implementation stays at
`~/.config/quickshell/mylauncher` as reference. This app is one binary and runs
no original code.

## What it does

- Centred 360 × 470 panel on the monitor under the pointer, overlay layer,
  transparent dark glass (`#A8141414`, 1 px `#14FFFFFF` border), same
  namespace (`quickshell:mylauncher`) so the existing blur rule applies.
- Search entry with the `search` placeholder, `↑`/`↓` to move, `Enter` to
  launch, `Esc` to close. One filter pass per 80 ms typing burst.
- Ranking copied tier by tier from the original: exact name, prefix, contains,
  generic name, comment, exec string, keywords, then subsequence match; ties
  broken by launch count, then name.
- Usage history in `~/.local/state/mylauncher/history.json`, the original path
  and format, so existing counts carry over.
- Desktop entries scanned from `$XDG_DATA_HOME` and `$XDG_DATA_DIRS` with the
  same filter set the original inherited from Quickshell: `Type=Application`,
  not `Hidden`, not `NoDisplay`, non-empty name, one entry per id.
- Icons resolve through the icon theme, then `~/.local/share/icons` and
  `/usr/share/pixmaps`, then the generic chain; otherwise the first letter.

### Intentional differences from the original

Per the port decisions (`rust/DECISIONS.md`):

- **No click-outside dismissal** (ADR-009). Close with `Esc` or by tapping
  SUPER again. The original relied on Hyprland's keyboard-grab protocol, which
  a layer-shell GTK surface cannot use.
- **No `quickshell ipc`** (ADR-004). Use `rustedlauncher toggle|open|hide|
  isVisible`; update the keybind.
- **`Terminal=true` entries open a terminal**, and field codes (`%i`, `%c`,
  `%k`, …) expand per the Desktop Entry spec, where Quickshell dropped them
  and ignored `Terminal` (ADR-007).
- Name ties use case-insensitive Unicode order instead of Qt's
  `localeCompare` (ADR-008); identical for ASCII names.
- The 120 ms highlight glide is gone: GTK's list has no such animation.

## Requirements

- Hyprland (wlr-layer-shell).
- Rust 1.93+ (edition 2024).
- GTK 4 and `gtk4-layer-shell` (Arch: `gtk4 gtk4-layer-shell`).
- Optional: `hyprctl` (ships with Hyprland) for multi-monitor placement.

## Build and run

```sh
./run.sh
```

`run.sh` builds `rust/target/release/rustedlauncher` if missing and execs
`rustedlauncher run`.

```sh
rustedlauncher toggle       # show/hide
rustedlauncher open
rustedlauncher hide
rustedlauncher isVisible    # prints true / false
```

## Hyprland wiring

Add the daemon to your Hyprland autostart:

```lua
hl.exec_cmd("$HOME/proj/rustedLauncher/run.sh")
```

Classic `hyprland.conf`:

```conf
exec-once = ~/proj/rustedLauncher/run.sh
```

Bind SUPER-tap to the launcher (this replaces the old
`quickshell ipc … call mylauncher toggle` line):

```lua
hl.bind("SUPER + SUPER_L",
    hl.dsp.exec_cmd("$HOME/proj/rustedLauncher/rust/target/release/rustedlauncher toggle"),
    { release = true })
```

The glass blur rule needs no change; the panel keeps the original namespace:

```lua
hl.layer_rule({
    match = { namespace = "quickshell:mylauncher" },
    blur = true,
    ignore_alpha = 0.15,
})
```

`rust/cutover.sh` walks through all of this, with the rollback at each step.

## Credit

- Original QML: [Ali120B](https://github.com/Ali120B), alibashmail2010@yahoo.com
