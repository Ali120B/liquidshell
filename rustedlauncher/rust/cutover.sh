#!/usr/bin/env bash
# Interactive cutover: original Quickshell launcher -> rustedlauncher.
# Run it from a terminal on the Hyprland session. It changes nothing without
# asking, and every step names its rollback.
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$DIR/rust/target/release/rustedlauncher"
ORIGINAL="${RUSTEDLAUNCHER_ORIGINAL_DIR:-$HOME/.config/quickshell/mylauncher}"
ORIGINAL_PATTERN="quickshell.*-p.*quickshell/mylauncher"

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok()  { printf '\033[32mOK\033[0m  %s\n' "$*"; }
warn(){ printf '\033[33mWARN\033[0m %s\n' "$*"; }
die() { printf '\033[31mFAIL\033[0m %s\n' "$*" >&2; exit 1; }
pause() { read -r -p "Press Enter to continue (Ctrl-C aborts)… " _; }
ask() { local answer; read -r -p "$1 [y/N] " answer; [[ "$answer" == [yY]* ]]; }

say "rustedLauncher cutover"
echo "new app:  $BIN"
echo "original: $ORIGINAL"
echo "rollback: start the original again; it is untouched."

# --- 1. build -------------------------------------------------------------
say "1/6 Build the release binary"
cargo build --release --manifest-path "$DIR/rust/Cargo.toml" || die "build failed"
[[ -x "$BIN" ]] || die "binary missing after build: $BIN"
ok "built $BIN"
pause

# --- 2. stop the original -------------------------------------------------
say "2/6 Stop the original launcher"
if pgrep -af "$ORIGINAL_PATTERN" >/dev/null 2>&1; then
    pgrep -af "$ORIGINAL_PATTERN" || true
    echo "The original is a resident Quickshell instance that also serves the"
    echo "SUPER keybind. Stopping it closes the old launcher."
    if ask "Stop the original Quickshell launcher now?"; then
        pkill -f "$ORIGINAL_PATTERN" || warn "could not stop every original process"
        sleep 1
        ok "original launcher stopped"
        echo "rollback: quickshell -n -d -p \"$ORIGINAL\" &"
    else
        warn "left running; both launchers will answer the IPC of their own app"
    fi
else
    ok "no original launcher running"
fi
pause

# --- 3. start the new app -------------------------------------------------
say "3/6 Start rustedlauncher"
if pgrep -x rustedlauncher >/dev/null 2>&1; then
    ok "already running"
else
    nohup "$DIR/run.sh" >/tmp/rustedlauncher.log 2>&1 &
    sleep 2
fi
if ! "$BIN" isVisible >/dev/null 2>/tmp/rustedlauncher.err; then
    cat /tmp/rustedlauncher.err >&2 || true
    cat /tmp/rustedlauncher.log >&2 || true
    die "the launcher did not answer on its socket"
fi
ok "launcher is answering ($("$BIN" isVisible))"
echo "rollback: pkill -x rustedlauncher; quickshell -n -d -p \"$ORIGINAL\" &"
pause

# --- 4. verify ------------------------------------------------------------
say "4/6 Verify the panel"
if ask "Open the panel now?"; then
    "$BIN" open
    echo "Type to filter, ↑/↓ to move, Enter to launch, Esc to close."
    echo "There is no click-outside dismissal in this port (DECISIONS.md ADR-009)."
    pause
    if "$BIN" isVisible | grep -qx true; then
        if ask "Does the panel look right and close on Esc?"; then
            ok "panel verified"
        else
            warn "check /tmp/rustedlauncher.log and DECISIONS.md"
        fi
        "$BIN" hide
    else
        ok "panel closed"
    fi
else
    warn "skipped the visual check"
fi
pause

# --- 5. autostart ---------------------------------------------------------
say "5/6 Autostart"
cat <<EOF
Replace the old launcher's start line with one of these.

Hyprland Lua config:

  hl.exec_cmd("\$HOME/proj/rustedLauncher/run.sh")

Classic hyprland.conf:

  exec-once = ~/proj/rustedLauncher/run.sh

Remove the old line that starts
  quickshell -n -d -p \$HOME/.config/quickshell/mylauncher
so the original does not start again. The rest of the quickshell config is
unaffected.
EOF
pause

# --- 6. keybind -----------------------------------------------------------
say "6/6 SUPER keybind"
cat <<EOF
Replace the old toggle line:

  hl.bind("SUPER + SUPER_L",
      hl.dsp.exec_cmd("quickshell ipc -p " .. home .. "/.config/quickshell/mylauncher call mylauncher toggle"),
      { release = true })

with:

  hl.bind("SUPER + SUPER_L",
      hl.dsp.exec_cmd(home .. "/proj/rustedLauncher/rust/target/release/rustedlauncher toggle"),
      { release = true })

The blur layer rule needs no change: the panel keeps the namespace
"quickshell:mylauncher".
EOF
if ask "Reload Hyprland now (hyprctl reload) to pick up the edits?"; then
    hyprctl reload >/dev/null 2>&1 && ok "reloaded" || warn "hyprctl reload failed"
fi
ok "cutover steps done"
echo
echo "Rollback at any time:"
echo "  pkill -x rustedlauncher"
echo "  quickshell -n -d -p \"$ORIGINAL\" &"
echo "  restore the old keybind and autostart lines"
