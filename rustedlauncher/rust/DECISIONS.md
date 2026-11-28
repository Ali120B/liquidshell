# rustedLauncher decisions

Numbered ADRs, in the order accepted, never renumbered. A changed decision
gets a new ADR that supersedes the old one.

## ADR-001: Port the Quickshell launcher, nothing else
Status: accepted (2026-11-28)

Context: `~/.config/quickshell/mylauncher` holds `shell.qml` (panel, list,
IPC) and `AppProvider.qml` (desktop-entry index, ranking, history), 571 lines
in total, plus a README that documents the install and the Hyprland wiring.

Decision: the deliverable is `~/proj/rustedLauncher`, one Rust binary that
replaces both QML files. The original directory stays untouched as reference.
Nothing from the surrounding quickshell config (`shell.qml`, `osd.qml`,
`hypr-lens`, `custom/`) is in scope.

Consequences: the Hyprland keybind and autostart line must be repointed at the
new binary at cutover (`cutover.sh`).

## ADR-002: GTK4 overlay, Rust owns all behavior
Status: accepted (2026-11-28)

Context: the original is a Quickshell/QtQuick layer surface. A pure
smithay-client-toolkit client is possible but costly; GTK 4.24 and
libgtk4-layer-shell 1.3.0 are installed, and the sibling port `rustedPill`
already runs this stack on the same machine.

Decision: build the panel as a Rust GTK4 application using `gtk4-layer-shell`
for the layer surface. GTK is a rendering dependency, not a fallback: no QML,
no Quickshell and no original code runs at run time.

Consequences: "pure Rust" means the app and its logic are Rust; the binary
links GTK4/GDK/Pango dynamically, and font rasterisation differs from Qt by a
pixel.

## ADR-003: Keep the original layer namespace
Status: accepted (2026-11-28)

Context: the user's `rules.lua` has a Hyprland layer rule that turns on blur
for the namespace `quickshell:mylauncher` with `ignore_alpha = 0.15`.

Decision: the layer surface uses the namespace `quickshell:mylauncher`, the
same string the QML `PanelWindow` used. A different namespace would silently
lose the glass look until the user edited their compositor config.

Consequences: the name is historical; the blur rule keeps working with no
config change, and `hyprctl layers` shows the app under that namespace.

## ADR-004: Native CLI and socket instead of `quickshell ipc`
Status: accepted (2026-11-28)

Context: the original is toggled with
`quickshell ipc -p ~/.config/quickshell/mylauncher call mylauncher <verb>`.
That command only exists while a Quickshell instance owns the target, and the
Rust binary never starts one.

Decision: the binary speaks its own protocol on
`$XDG_RUNTIME_DIR/rustedlauncher.sock` (one text line per request) and exposes
the same four verbs as subcommands: `rustedlauncher toggle|open|hide|isVisible`,
with `isVisible` answering `true` / `false` on stdout. `run` starts the daemon
and is the default. `is-visible` is accepted as an alias.

Consequences: the SUPER keybind changes from the `quickshell ipc` line to
`rustedlauncher toggle` (cutover step 6). The verb names and their meaning are
kept; the transport is not.

## ADR-005: Desktop entries parsed in Rust with Quickshell's filter set
Status: accepted (2026-11-28)

Context: the original read `DesktopEntries.applications`, whose filter set the
research file records from the Quickshell source: `Type=Application`
exact, `Hidden=true` masks the id, `NoDisplay=true` is dropped from the model,
an empty `Name` is discarded, and `$XDG_DATA_HOME` beats `$XDG_DATA_DIRS`
despite the reverse scan order. `TryExec`, `OnlyShowIn` and `NotShowIn` are
not consulted at all.

Decision: `launcher-core` scans the XDG `applications` directories in priority
order, builds the id from the path (`/` → `-`, `.desktop` removed), keeps the
first id it sees, and lets a higher-priority `Hidden`/`NoDisplay` file mask a
lower-priority one. `TryExec` is parsed but not acted on, and
`OnlyShowIn`/`NotShowIn` are ignored, matching Quickshell — an entry that was
listed before is still listed.

Consequences: the visible list matches what the original showed (260 entries
here). A missing `TryExec` binary still appears in the list and fails at
launch, as before. Localized `Name[xx]`/`GenericName[xx]`/`Comment[xx]`
selection follows the locale candidates from `LC_ALL`, `LC_MESSAGES`, `LANG`.

## ADR-006: History stays at the original path and format
Status: accepted (2026-11-28)

Context: `AppProvider.qml` writes a compact JSON object of desktop-file id to
launch count at `~/.local/state/mylauncher/history.json`, deliberately not
under the config directory so it survives config moves.

Decision: same path, same compact object, insertion order preserved
(`serde_json` with `preserve_order`). A missing or malformed file loads as
empty, as the original's `try/catch` did.

Consequences: the counts the user already has (zen 98, …) drive the ordering
in the Rust app from the first launch; ordering and file contents are
byte-compatible with the original.

## ADR-007: Exec handling follows the spec, not Quickshell's stubs
Status: accepted (2026-11-28)

Context: Quickshell's `execute()` deletes every field code (`%f`, `%i`, `%c`,
`%k`, …) and never reads `Terminal`, so `Exec=app %U` runs `app` and a
`Terminal=true` entry is started without a terminal. The machine has ten
`Terminal=true` entries. No installed entry uses `%i`, `%c` or `%k`.

Decision: implement the Desktop Entry spec instead: field codes expand (`%i`
→ `--icon <icon>`, `%c` → name, `%k` → the desktop file, `%%` → `%`, the rest
dropped), and `Terminal=true` entries are wrapped in `$TERMINAL` when set,
otherwise the first known emulator found on `PATH`
(`xdg-terminal-exec`, `kitty`, `foot`, `alacritty`, `wezterm`, `ghostty`,
`konsole`, `gnome-terminal`, `xterm`).

Consequences: a deliberate behavior improvement over the original — terminal
entries now open a terminal instead of failing silently. It is a difference,
not a bug: `known-diffs.jsonl` style tolerance does not apply (there are no
recorded cases), so it is listed in `MAP.md` and the README.

## ADR-008: Ranking copied tier by tier, with one named difference
Status: accepted (2026-11-28)

Context: `AppProvider.qml` scores 100/80/60/45/35/25/20/10 and breaks ties by
usage count then `name.localeCompare`. Qt's `localeCompare` is locale-aware
and not reproducible without ICU collation.

Decision: copy the tiers and the fuzzy subsequence test exactly, and break
ties with case-insensitive Unicode ordering (raw name as the second key).

Consequences: all-ASCII names sort identically to the original. Names with
diacritics or non-Latin scripts can order differently from Qt, and that is
recorded as a known difference rather than papered over.

## ADR-009: No click-outside dismissal
Status: accepted (2026-11-28)

Context: the original closes when clicked outside because
`HyprlandFocusGrab` asks Hyprland for a keyboard grab and closes on
`onCleared`. wlr-layer-shell has no grab, and a GTK layer surface never gets
`EventControllerFocus` enter/leave, so a click that lands outside the 360 × 470
surface is delivered to whatever is below and the launcher never hears of it.
A fullscreen transparent catcher surface (Top layer, zero opacity, click
gesture) was implemented and did not map on this compositor — it never appeared
in `hyprctl layers`, so it could not catch anything.

Decision: do not ship the catcher. Dismissal is `Esc` (window-wide capture
controller), a second `SUPER` tap (`toggle`), or launching an entry. `hide`
over IPC still works for scripts.

Consequences: one honest behavior difference from the original, listed in
`MAP.md` and the README. A future fix needs the `hyprland_focus_grab_v1`
protocol (a raw Wayland client, outside GTK's surface), or a working catcher
surface; both are a new unit, not a patch.

## ADR-010: Verification is manual plus unit tests
Status: accepted (2026-11-28)

Context: `rust-anything analyze` reports the repository as TypeScript with
zero source files — QML is not a supported language, and `app record` /
`app replay` cannot drive a Wayland GUI. The sibling `rustedPill` port
recorded the same limitation as its ADR-011.

Decision: keep the whole-app port's discipline (`MAP.md`, ADRs, glossary,
per-unit implementation, fmt/clippy/test) but do not fabricate recorded cases.
The gate is `cargo fmt --check`, `cargo clippy --workspace --all-targets -D
warnings`, `cargo test --workspace`, and the manual checkpoint in `MAP.md`.
The pure logic lives in `launcher-core` where it is unit-testable: parsing,
masking, field codes, terminal detection, icon chain, history, scoring.

Consequences: no `cases.jsonl`, no fallback rate, no trycmd suite in CI. The
checkpoint record is the proof, and every difference is written down.

## ADR-011: No fallback path to the original
Status: accepted (2026-11-28)

Context: the guide's front door forwards everything not ported yet to the
original. Here the whole app is small enough to port in one pass, and running
Quickshell beside the Rust daemon would fight over the same keybind.

Decision: ship the Rust app directly. There is no `--fallback-original` flag,
no proxy and no call into Quickshell; the original stays runnable beside the
new app until the user cuts over.

Consequences: no mixed mode; rollback is starting the old Quickshell launcher
again.

## ADR-012: Startup without GTK activation, surfaces realized early
Status: accepted (2026-11-28)

Context: with the UI built inside `connect_activate`, the daemon sometimes
exited immediately with no output: `activate` never fired for a process whose
only window is created on demand, and `g_application_run` returned with
nothing wired. Mapping a fresh layer surface also blocked for 50–240 ms, which
is too long for a SUPER-key launcher. `hyprctl cursorpos` (spawned to pick the
monitor) added another 7–10 ms on every open.

Decision: register the `GtkApplication`, build and `realize()` the window
before `run_with_args`, and drop the activation handler. Pick the monitor
without spawning `hyprctl` when there is a single output. Keep the parsed
desktop-entry index across opens and rescan only when an `applications`
directory's mtime changed.

Consequences: startup is deterministic and open costs a map round-trip instead
of a map plus a file scan plus a process spawn. A newly installed application
appears on the next open because the directory mtime changes; editing a
desktop file in place is picked up on the next rescan (restart), which the
original's file monitor did handle — accepted for now.

## ADR-013: Cutover is manual
Status: accepted (2026-11-28)

Context: the launcher runs inside the user's live compositor; no package
manager or service manager is involved.

Decision: `rust/cutover.sh` walks through build, stopping the original
Quickshell launcher, starting the daemon, verifying IPC, and editing the
SUPER keybind and autostart line, with the rollback at each step. The user
runs it.

Consequences: no deploy automation. Rollback is starting the original again,
which stays installed.
