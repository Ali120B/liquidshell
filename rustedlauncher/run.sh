#!/usr/bin/env bash
# Build rustedLauncher once, then run the launcher daemon.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$DIR/rust/target/release/rustedlauncher"

if [[ ! -x "$BIN" ]]; then
    cargo build --release --manifest-path "$DIR/rust/Cargo.toml"
fi

exec "$BIN" run
