# rustedLauncher glossary

One term per row. Rust names are the ones used in the crates.

| Term | Meaning | Rust name |
| --- | --- | --- |
| Entry | One launchable application, built from a desktop file. | `desktop::AppEntry` |
| Id | Desktop-file id: path below `applications/`, `/` → `-`, `.desktop` removed. Keys the history and dedupes the scan. | `AppEntry::id`, `desktop_id` |
| Scan | Walk `$XDG_DATA_HOME` then `$XDG_DATA_DIRS` for `applications/**/*.desktop`, one entry per id. | `desktop::load_entries`, `load_entries_from` |
| Mask | A higher-priority `Hidden` or `NoDisplay` file deleting the id for lower-priority directories. | `masks_lower_priority` |
| Locale candidates | The `Name[xx]` keys to try, most specific first (`ar_SA@mod`, `ar_SA`, `ar@mod`, `ar`). | `desktop::Locale` |
| Score | Match quality of an entry for a query: 100/80/60/45/35/25/20/10, `-1` for no match. | `search::score` |
| Fuzzy match | Subsequence test on lowercased text, scoring 10. | `search::fuzzy_match` |
| Usage | Launch count for an id, read from the history file. | `History::count` |
| Usage order | Ties broken by usage descending, then name. | `search::compare` |
| Result | Indices into the loaded entries, in display order. | `search::search_indices` |
| History | Compact JSON object id → count at `~/.local/state/mylauncher/history.json`. | `history::History` |
| Icon chain | Candidates tried in order: theme name, stripped name, `~/.local/share/icons` and `/usr/share/pixmaps` files, generic names. | `icon::chain`, `icon::IconSource` |
| Generic icons | `image-missing`, `application-x-executable`, `exec`, `application-default-icon`, `system-run`. | `icon::GENERIC` |
| Letter fallback | First character of the name, uppercased, when no icon resolves. | `letter_label` |
| Exec words | An `Exec` value split on quotes and escapes. | `exec::parse_words` |
| Field code | `%f`, `%U`, `%i`, `%c`, `%k`, `%%`, … — expanded per the Desktop Entry spec. | `exec::expand_field_codes` |
| Terminal wrap | Prefixing the command with a terminal emulator when `Terminal=true`. | `exec::Terminal`, `exec::build_plan` |
| Launch plan | The argv and working directory to spawn. | `exec::ExecPlan` |
| Panel | The 360 × 470 flat-sided dark surface at the centre of the monitor. | `.panel`, `WIDTH`, `HEIGHT` |
| Overlay layer | Hyprland layer the panel lives on, above normal windows. | `Layer::Overlay` |
| Namespace | Layer-surface name; kept as `quickshell:mylauncher` so the blur rule applies. | `set_namespace` |
| Keyboard grab | Exclusive keyboard focus for the panel. | `KeyboardMode::Exclusive` |
| Filter pass | One ranking run over the entries for the current query. | `Ui::apply_filter` |
| Filter debounce | 80 ms wait after the last keystroke before a filter pass. | `FILTER_DELAY`, `Ui::schedule_filter` |
| Selection | Index into the filtered results. | `Ui::selected` |
| IPC | Control socket at `$XDG_RUNTIME_DIR/rustedlauncher.sock`, one line per request. | `ipc::Command`, `ipc::serve` |
| Verb | `toggle`, `open`, `hide`, `isVisible`. | `ipc::parse` |
| Visibility flag | Whether the panel is currently shown, answered by `isVisible`. | `Arc<AtomicBool>` |
| Daemon | The `rustedlauncher run` process that owns the socket and the GTK loop. | `ui::run` |
