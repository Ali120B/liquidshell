#!/usr/bin/env bash
# check-config.sh — validate rice configs before `hyprctl reload`.
# Usage: check-config.sh [--quiet]
# Exit 0 = all good, 1 = something is broken (do NOT reload).
set -uo pipefail

QUIET=0
[[ "${1:-}" == "--quiet" ]] && QUIET=1

HYPR_DIR="$HOME/.config/hypr"
# When run from a repo checkout, validate the repo files too
REPO_DIR="$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)"
[[ "$REPO_DIR" == */liquidshell ]] || REPO_DIR=""

FAIL=0
say()  { [[ $QUIET -eq 1 ]] || echo "$*"; }
pass() { say "  ✓ $1"; }
fail() { echo "  ✗ $1"; FAIL=1; }
# CHECK_SCOPE=live|repo|all (default all). The installer uses repo-only so a
# broken live system never blocks deploying known-good files.

check_lua_dir() {
    local dir="$1" label="$2"
    [[ -d "$dir" ]] || { say "  - $label: $dir missing, skipped"; return; }
    for f in "$dir"/hyprland.lua "$dir"/keybinds.lua "$dir"/rules.lua; do
        # hyprland.conf is a symlink to hyprland.lua; luac follows it fine,
        # but checking the real files is enough
        [[ -f "$f" ]] || { fail "$label: missing $f"; continue; }
        if luac -p "$f" 2>/tmp/check-config-lua-err; then
            pass "$label: $(basename "$f")"
        else
            fail "$label: $(basename "$f"): $(cat /tmp/check-config-lua-err)"
        fi
    done
    # Duplicate keybinds catch real breakage (later bind wins silently)
    local dupes
    dupes=$(grep -oP 'hl\.bind\("\K[^"]+' "$dir/keybinds.lua" 2>/dev/null | sort | uniq -d || true)
    if [[ -n "$dupes" ]]; then
        fail "$label: duplicate binds: $(echo "$dupes" | tr '\n' ' ')"
    else
        pass "$label: no duplicate binds"
    fi
}

check_bash_dir() {
    local dir="$1" label="$2"
    [[ -d "$dir" ]] || { say "  - $label: $dir missing, skipped"; return; }
    local f
    for f in "$dir"/*.sh; do
        [[ -e "$f" ]] || continue
        if bash -n "$f" 2>/tmp/check-config-bash-err; then
            pass "$label: $(basename "$f")"
        else
            fail "$label: $(basename "$f"): $(cat /tmp/check-config-bash-err)"
        fi
    done
}

check_waybar() {
    local cfg="$1" label="$2"
    [[ -f "$cfg" ]] || { say "  - $label: waybar config missing, skipped"; return; }
    if python3 - "$cfg" <<'EOF' 2>/tmp/check-config-json-err
import json, re, sys
text = open(sys.argv[1]).read()
text = re.sub(r'//.*', '', text)  # jsonc line comments
json.loads(text)
EOF
    then
        pass "$label: waybar config.jsonc parses"
    else
        fail "$label: waybar config.jsonc: $(cat /tmp/check-config-json-err | head -n 3 | tr '\n' ' ')"
    fi
}

say "── hypr (live) ──"
if [[ "${CHECK_SCOPE:-all}" == "all" || "${CHECK_SCOPE:-all}" == "live" ]]; then
check_lua_dir "$HYPR_DIR" "live"
check_bash_dir "$HYPR_DIR/scripts" "live-scripts"
check_waybar "$HOME/.config/waybar/config.jsonc" "live"
fi

if [[ -n "$REPO_DIR" ]]; then
if [[ "${CHECK_SCOPE:-all}" == "all" || "${CHECK_SCOPE:-all}" == "repo" ]]; then
    say "── liquidshell repo ──"
    check_lua_dir "$REPO_DIR/hypr" "repo"
    check_bash_dir "$REPO_DIR/hypr/scripts" "repo-scripts"
    check_waybar "$REPO_DIR/waybar/config.jsonc" "repo"
    if [[ -f "$REPO_DIR/install.sh" ]]; then
        if bash -n "$REPO_DIR/install.sh" 2>/tmp/check-config-install-err; then
            pass "repo: install.sh"
        else
            fail "repo: install.sh: $(cat /tmp/check-config-install-err)"
        fi
    fi
fi
fi

if [[ $FAIL -eq 0 ]]; then
    say "OK: all configs valid — safe to run: hyprctl reload"
else
    echo "FAIL: fix the above before running: hyprctl reload"
fi
exit $FAIL
