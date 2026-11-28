# rustedLauncher port map

Goal: a standalone Rust replacement for the Quickshell launcher at
`~/.config/quickshell/mylauncher`, at `~/proj/rustedLauncher`. The original
stays in place, untouched, as reference.

## Where things are

| What | File |
| --- | --- |
| Decisions (source of truth) | `DECISIONS.md` |
| Shared vocabulary | `GLOSSARY.md` |
| Dependency research | `research/quickshell-desktop-entry.md` |
| Session handoff | `HANDOFF.md` |
| Cutover script | `cutover.sh` |
| App crate | `app/` (`rustedlauncher` binary: GTK4 UI, IPC, launch) |
| Logic crate | `units/launcher-core/` (desktop entries, ranking, history, icons, Exec) |
| Run / autostart / keybind | `../run.sh`, `../README.md` |

## Units

State values: `open`, `claimed by <session> <date>`, `done`.

| Unit | What | State |
| --- | --- | --- |
| U1 `launcher-core` | XDG desktop-entry scan and parse (locale keys, Hidden/NoDisplay masking, XDG precedence), Exec field codes and terminal wrapping, icon candidate chain, history JSON, score/fuzzy/order. | done — 22 unit tests pass |
| U2 `app::ui` | GTK4 + gtk4-layer-shell panel: 360 × 470 centred overlay, CSS palette from the QML, search entry, pooled list, icons with letter fallback, keyboard nav, 80 ms filter debounce, launching. | done — live check below |
| U3 `app::ipc` + `app::launch` | Unix-socket control (`toggle`, `open`, `hide`, `isVisible`), CLI verbs, spawn with `/dev/null` stdio and reaping. | done — IPC live-tested |
| U4 `app` integration | Layer namespace, history path, launcher-core wiring, usage ordering. | done |
| U5 `checkpoint` | fmt, clippy, tests, release build, live check next to the original. | done — see below |
| U6 `lift` | No fallback path to Quickshell exists at all; pure binary, docs and cutover. | done |

## Checkpoint (U5)

Environment: live Hyprland 0.57.2 session, one 1920×1080 output (`eDP-1`) at
scale 1, GTK 4.24.2, libgtk4-layer-shell 1.3.0.

- `cargo fmt --check`, `cargo clippy --workspace --all-targets -- -D warnings`,
  `cargo test --workspace`: pass (22 `launcher-core` tests + 1 `app` test).
- `cargo build --release`: pass, one binary,
  `rust/target/release/rustedlauncher` (~1.0 MB).
- Layer surface: namespace `quickshell:mylauncher`, layer `overlay`,
  360 × 470 at (780, 305), i.e. centred on the output, as the QML PanelWindow.
- Rows render with theme icons and the letter fallback; order is usage
  descending then name (Zen 98, Sober 53, Nautilus 45, …), matching
  `AppProvider.compareUsage`.
- Typing filters through the 80 ms debounce (`wtype` into the focused entry);
  `↑`/`↓` move the highlight; `Esc` hides.
- `Enter` launches the highlighted entry, increments its count in
  `~/.local/state/mylauncher/history.json` (zen 98 → 99) and hides.
- IPC: `rustedlauncher open|hide|toggle|isVisible` answer over
  `$XDG_RUNTIME_DIR/rustedlauncher.sock`.
- 260 visible applications out of 455 system + 45 user desktop files
  (Hidden/NoDisplay/empty-name filtered, one entry per id).

Not exercised here: a second monitor, fractional scaling, and stable timing
under heavy load (the machine was running a game during the last passes; the
daemon's startup and map round-trips stretch to seconds then).

## Behavior kept

- 360 × 470 panel centred on the monitor, `#A8141414` background, 1 px
  `#14FFFFFF` border, 14 px inner margin, 8 px spacing.
- Search row 40 px, `#14FFFFFF` fill, `#1FFFFFFF` border, 14 px side padding,
  text `#8AB4FF` at 15 px, placeholder `search` at 33 % white.
- Rows 44 px, 16/12 px side margins, 10 px spacing, 24 px icon, 14 px name,
  ellipsised; hover `#14FFFFFF` without moving the selection; selected
  `#2AFFFFFF`; letter fallback in `#70FFFFFF`.
- Ranking: empty query → usage desc, name asc; otherwise score tiers
  (100 exact, 80 prefix, 60 contains, 45 generic, 35 comment, 25 exec,
  20 keyword, 10 fuzzy subsequence) then usage then name.
- History: `~/.local/state/mylauncher/history.json`, compact JSON object of
  desktop-file id → count, written on every launch.
- Icon chain: theme name, name without a `.png/.svg/.xpm` suffix,
  `~/.local/share/icons` and `/usr/share/pixmaps` candidates, then the
  generic chain (`image-missing`, `application-x-executable`, `exec`,
  `application-default-icon`, `system-run`).
- Desktop entries: `Type=Application`, not `Hidden`, not `NoDisplay`, non-empty
  localized `Name`, one entry per id, `$XDG_DATA_HOME` before `$XDG_DATA_DIRS`.
- Keyboard: `↑`/`↓` clamp at the ends, `Enter`/`KP_Enter` flush a pending
  filter then launch, `Esc` hides.

## Behavior dropped or changed (user decisions, ADR-003 … ADR-009)

- **Click-outside does not dismiss** (ADR-009). `Esc` or another `SUPER` tap
  closes. The original used Hyprland's keyboard-grab protocol.
- **IPC is a native CLI**, not `quickshell ipc … call mylauncher …` (ADR-004).
- **`Terminal=true` entries actually open a terminal**, and `%i`, `%c`, `%k`
  expand per the Desktop Entry spec, where Quickshell silently drops every
  field code and ignores `Terminal` (ADR-007).
- Name ordering uses case-insensitive Unicode order, not Qt's `localeCompare`
  (ADR-008); identical for ASCII names.
- 120 ms highlight glide and the drag/scroll gesture tuning are not ported:
  GTK's list has no equivalent animation.

## Open questions

None. Cutover is manual (`cutover.sh`, ADR-013); the original stays as
reference until the user retires it.
