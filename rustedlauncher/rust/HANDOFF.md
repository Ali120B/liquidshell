# rustedLauncher handoff

Written at the end of the whole-app port, 2026-11-28.

## Where the port stands

- Units U1–U6 are `done` in `MAP.md`; the app is complete and runs.
- Shipped artifact: one standalone binary,
  `rust/target/release/rustedlauncher` (~1.0 MB, GTK4 + gtk4-layer-shell).
- No original code runs at run time: no QML, no Quickshell, no fallback path
  (ADR-011). The original stays at `~/.config/quickshell/mylauncher` as
  reference until the user cuts over.
- Gate: `cargo fmt --check`, `cargo clippy --workspace --all-targets -- -D
  warnings` and `cargo test --workspace` all pass (22 `launcher-core` tests,
  1 `app` test).
- Last live checkpoint: panel maps centred at 360 × 470 under namespace
  `quickshell:mylauncher`, usage-ordered rows with icons, typing filters,
  `Esc` hides, `Enter` launches and records history, IPC verbs answer. Full
  record in `MAP.md`.

## How to run

```sh
~/proj/rustedLauncher/run.sh                  # build if missing, then run
~/proj/rustedLauncher/rust/target/release/rustedlauncher toggle
~/proj/rustedLauncher/rust/target/release/rustedlauncher isVisible
```

The daemon must be running for `toggle`/`open`/`hide`/`isVisible`; `run` is
the default subcommand.

## What is left

- User cutover: run `rust/cutover.sh`, then repoint the SUPER keybind at
  `rustedlauncher toggle` and the autostart line at `run.sh`.
- Known difference: clicking outside the panel does not dismiss it (ADR-009).
  Use `Esc` or tap SUPER again.
- Optional: a second monitor and fractional scaling are reasoned about
  (monitor chosen under the pointer, clamped per monitor) but the test
  machine is one 1920 × 1080 output at scale 1.
- Optional: `hyprland_focus_grab_v1` support to restore click-outside
  dismissal (ADR-009) — a new unit, not a patch.
- Optional reshape after cutover: `launcher-core` / `app` split mirrors the
  original QML split and can be flattened now that nothing has to match
  internals.

## Links

- Plan and claims: `MAP.md`
- Decisions: `DECISIONS.md` (ADR-003 namespace, ADR-005 entry filters,
  ADR-007 Exec, ADR-009 click-outside, ADR-012 startup)
- Vocabulary: `GLOSSARY.md`
- Research: `research/quickshell-desktop-entry.md`
- Cutover: `cutover.sh`
- Original reference: `~/.config/quickshell/mylauncher`
