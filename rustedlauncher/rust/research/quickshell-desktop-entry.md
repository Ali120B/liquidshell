# Quickshell `DesktopEntry` / `DesktopEntries` — implementation notes

Researched from source only (no blog posts), 2026-11-28.

| What | Where |
|---|---|
| Implementation | `src/core/desktopentry.cpp`, `src/core/desktopentry.hpp`, `src/core/desktopentrymonitor.cpp` |
| Launch path | `src/core/qmlglobal.cpp`, `src/io/processcore.cpp`, `src/io/processcore.hpp`, `src/core/common.hpp`, `src/launch/launch.cpp` |
| Versions checked | `master` (as of 2026-11-28) and release `v0.3.2` (2026-10-08) |

URLs:

- https://github.com/quickshell-mirror/quickshell/blob/master/src/core/desktopentry.cpp
- https://github.com/quickshell-mirror/quickshell/blob/master/src/core/desktopentry.hpp
- https://github.com/quickshell-mirror/quickshell/blob/master/src/core/desktopentrymonitor.cpp
- https://github.com/quickshell-mirror/quickshell/blob/master/src/core/qmlglobal.cpp
- https://github.com/quickshell-mirror/quickshell/blob/master/src/io/processcore.cpp

`v0.3.2` vs `master`: the only difference in `desktopentry.cpp` is that master trims each line
(`30a5d60a31 "core/desktopentry: trim lines in desktop entries when parsing"`, 2026-10-17, after the
0.3.2 release). Everything below otherwise applies to both. See "Semantic traps" #11.

---

## 1. How `DesktopEntries.applications` is populated

### 1.1 Directories

`DesktopEntryManager::desktopPaths()` (`desktopentry.cpp`):

```cpp
auto dataHome = qEnvironmentVariable("XDG_DATA_HOME");
if (dataHome.isEmpty() && qEnvironmentVariableIsSet("HOME"))
    dataHome = qEnvironmentVariable("HOME") + "/.local/share";
if (!dataHome.isEmpty()) dataPaths.append(dataHome + "/applications");

auto dataDirs = qEnvironmentVariable("XDG_DATA_DIRS");
if (dataDirs.isEmpty()) dataDirs = "/usr/local/share:/usr/share";

for (const auto& dir: dataDirs.split(':', Qt::SkipEmptyParts)) {
    dataPaths.append(dir + "/applications");
}
```

So: `$XDG_DATA_HOME/applications` (default `~/.local/share/applications`), then each entry of
`$XDG_DATA_DIRS` (default `/usr/local/share:/usr/share`) plus `/applications`.
This list is a **function-local `static`**, computed once on first use and never refreshed if the
environment changes later.

### 1.2 Recursive scan, id from relative path

```cpp
for (const auto& path: desktopPaths | std::views::reverse) {
    auto file = QFileInfo(path);
    if (!file.isDir()) continue;
    this->scanDirectory(QDir(path), QString(), scanResults);
}
```

`scanDirectory` recurses into every subdirectory and derives the id from the path *relative to the
applications dir*:

```cpp
if (entry.isDir()) {
    auto subdirPrefix = idPrefix.isEmpty() ? entry.fileName() : idPrefix + '-' + entry.fileName();
    this->scanDirectory(QDir(entry.absoluteFilePath()), subdirPrefix, entries);
} else if (entry.isFile()) {
    auto path = entry.filePath();
    if (!path.endsWith(".desktop")) { ... continue; }

    auto basename = QFileInfo(entry.fileName()).completeBaseName();
    auto id = idPrefix.isEmpty() ? basename : idPrefix + '-' + basename;
    auto content = QString::fromUtf8(file.readAll());

    auto data = DesktopEntry::parseText(id, content);
    entries.append(std::move(data));
}
```

- Recursive: yes, unlimited depth.
- Filter: file name must end in exactly `.desktop` (case-sensitive, on the full path).
- Only the *file name* is used for the id; the directory part becomes a dash-separated prefix.

### 1.3 Dedupe: last scanned wins, and the scan order is reversed

Paths are scanned in **reverse** `desktopPaths()` order (lowest priority first), and in
`onScanCompleted` a later duplicate replaces an earlier one:

```cpp
auto conflictingId = newEntries.contains(data.id);
if (conflictingId) {
    qCDebug(logDesktopEntry) << "Replacing old entry for" << data.id;
    if (auto* victim = newEntries.take(data.id)) victim->deleteLater();
    newLowercaseEntries.remove(lowerId);
}
newEntries.insert(data.id, dentry);
```

Result: `$XDG_DATA_HOME` beats `$XDG_DATA_DIRS[0]` beats `$XDG_DATA_DIRS[n]`, i.e. the standard
XDG precedence. (Note this is the opposite of how a naive forward scan would behave.)

### 1.4 Filters actually applied

| Spec feature | Implemented? | Where |
|---|---|---|
| `Type=Application` | yes, exact + case-sensitive | `finishCategory()`: `if (entries.value("Type").second != "Application") return;` |
| `Hidden=true` | yes, masks lower-priority entry with same id | `onScanCompleted`, `data.hidden` branch |
| `NoDisplay=true` | yes, excluded from `applications()` only | `for (auto* entry: ...) if (!entry->bNoDisplay) newApplications.append(entry);` |
| empty `Name` | yes, entry dropped (`isValid()`) | `bool DesktopEntry::isValid() const { return !this->bName.value().isEmpty(); }` |
| `OnlyShowIn` / `NotShowIn` | **no** — zero hits for either string in the repo | — |
| `TryExec` | **no** — zero hits for `TryExec` in the repo | — |

`Hidden` handling is order-dependent and *not* an unconditional "delete":

```cpp
if (data.hidden) {
    if (auto* victim = newEntries.take(data.id)) victim->deleteLater();
    newLowercaseEntries.remove(lowerId);
    ...
    qCDebug(logDesktopEntry) << "Masking hidden desktop entry" << data.id;
    continue;
}
```

A `Hidden=true` file only removes an entry that was **already** inserted, i.e. one from a
lower-priority directory (scanned earlier). This matches the spec, where `Hidden` is a
"delete this id" marker in the higher-priority directory.

`applications()` is a `ObjectModel<DesktopEntry>*` built from `QHash::values()`:

```cpp
auto newApplications = QVector<DesktopEntry*>();
for (auto* entry: this->desktopEntries.values())
    if (!entry->bNoDisplay) newApplications.append(entry);
this->mApplications.diffUpdate(newApplications);
```

`ObjectModel::diffUpdate` preserves the given order, so the model order is **`QHash` iteration
order** — arbitrary and not stable across rescans. There is no sorting anywhere.

Also: the manager is a lazily created singleton, and its constructor runs the first scan
**synchronously** on the calling thread:

```cpp
DesktopEntryManager::DesktopEntryManager(): monitor(new DesktopEntryMonitor(this)) {
    ...
    DesktopEntryScanner(this).run();
}
```

### 1.5 Change monitoring

`desktopentrymonitor.cpp` watches each `applications` dir, its immediate subdirectories, and all
parent directories, debounces 100 ms, then triggers a full rescan. Deeper subdirectories are not
watched individually (a change there is only picked up if the immediate parent's mtime changes).

---

## 2. Localized keys (`Name[xx]`)

`parseText` splits `key[locale]` and keeps the best-scoring value per base key:

```cpp
auto localeIdx = key.indexOf('[');
Locale locale;
if (localeIdx != -1 && localeIdx != key.length() - 1) {
    locale = Locale(key.sliced(localeIdx + 1, key.length() - localeIdx - 2));
    key = key.sliced(0, localeIdx);
}

if (entries.contains(key)) {
    const auto& old = entries.value(key);
    auto oldScore = system.matchScore(old.first);
    auto newScore = system.matchScore(locale);
    if (newScore > oldScore || (oldScore == 0 && !locale.isValid())) {
        entries.insert(key, qMakePair(locale, value));
    }
} else {
    entries.insert(key, qMakePair(locale, value));
}
```

System locale:

```cpp
auto lstr = qEnvironmentVariable("LC_MESSAGES");
if (lstr.isEmpty()) lstr = qEnvironmentVariable("LANG");
locale = new Locale(lstr);
```

Matching (`Locale::matchScore`) requires the language to match, then rejects a candidate whose
modifier or territory is set but different, then scores:

```cpp
if (this->language != other.language) return 0;
if (!other.modifier.isEmpty() && this->modifier != other.modifier) return 0;
if (!other.territory.isEmpty() && this->territory != other.territory) return 0;

auto score = 1;
if (!other.territory.isEmpty()) score += 2;
if (!other.modifier.isEmpty()) score += 1;
return score;
```

Effective behaviour (system `de_DE`):

| key | score |
|---|---|
| `Name` (no locale) | 0 |
| `Name[de]` | 1 |
| `Name[de_DE]` | 3 |
| `Name[de_AT]` | 0 (territory mismatch) |
| `Name[fr]` | 0 |
| `Name[sr@latin]` on `sr` | 0 (modifier set but different) |

The plain `Name` wins only when no localized key scores > 0 — that is the
`(oldScore == 0 && !locale.isValid())` clause, which lets an unlocalized key replace an
unmatched localized one regardless of file order. Equal scores keep whichever came **first** in
the file. Only `Name`, `GenericName`, `Comment`, `Keywords` (and any other key) go through this;
`Exec`, `Icon`, etc. are localized too, per the spec's rules, since the same generic loop applies.

Not supported: `LANGUAGE` (glibc's real lookup order), codeset matching, `LC_ALL`.

---

## 3. `DesktopEntry.execute()`

```cpp
void DesktopEntry::execute() const {
    DesktopEntry::doExec(this->bCommand.value(), this->bWorkingDirectory.value());
}

void DesktopEntry::doExec(const QList<QString>& execString, const QString& workingDirectory) {
    qs::io::process::ProcessContext ctx;
    ctx.setCommand(execString);
    ctx.setWorkingDirectory(workingDirectory);
    QuickshellGlobal::execDetached(ctx);
}
```

### 3.1 Exec parsing — hand-written tokenizer, not `QProcess::splitCommand`

`parseExecString` is a custom state machine (no `QProcess::splitCommand`, no shell):

- `"` **and** `'` both start/stop a quoted section and are otherwise equivalent.
- Backslash escapes: `\s`→space, `\n`, `\t`, `\r`, `\\`→`\`, anything else → warning + the literal
  char. Inside quotes `\\` is a literal backslash; outside quotes a backslash just drops itself
  and takes the next char literally.
- Whitespace (only `' '`) separates arguments; empty arguments are discarded
  (`if (!currentArgument.isEmpty()) arguments.push_back(...)`).
- No line-continuation handling; no `\;` escaping in lists.

Field codes:

```cpp
} else if (percent) {
    if (c == '%') {
        currentArgument += '%';
    } // else discard
    percent = false;
} else if (c == '%') {
    percent = true;
}
```

**All field codes are deleted, not expanded.** `%f %F %u %U %i %c %k` simply vanish; only `%%`
produces a literal `%`. Consequences:

- `Exec=foo --file=%f` becomes `["foo", "--file="]`.
- `Exec=foo %U` becomes `["foo"]` (the whole token disappears).
- `%i` (icon) and `%c` (translated name) are dropped too, although the spec says to expand them.

This is documented in the header:

```cpp
/// Run the application. Currently ignores @@runInTerminal and field codes.
// currently ignores all field codes.
static QVector<QString> parseExecString(const QString& execString);
```

### 3.2 `Terminal=true`

Parsed into `bRunInTerminal`, exposed as `runInTerminal`, and **never used**:

```cpp
else if (key == "Terminal") data.terminal = value == "true";
...
/// > [!NOTE]	The provided command does not invoke a terminal even if @@runInTerminal is true.
```

`grep` for `runInTerminal` in the whole repo hits only `desktopentry.cpp` / `desktopentry.hpp`.
There is **no** terminal emulator lookup, and `$TERMINAL` is never read anywhere in the codebase.
The caller (your QML) must wrap the command itself.

### 3.3 `Path` (working directory)

`else if (key == "Path") data.workingDirectory = value;` → passed to `ProcessContext` →
`process.setWorkingDirectory(workingDirectory)` only if non-empty. No validation, no `~`
expansion.

### 3.4 `TryExec`

Not read at all (no hits in the repo). A missing binary is not detected at scan time; the entry
is listed, and the launch fails silently (see 3.6).

### 3.5 Environment

```cpp
void setupProcessEnvironment(QProcess* process, bool clear, const QHash<QString, QVariant>& envChanges) {
    const auto& sysenv = qs::Common::INITIAL_ENVIRONMENT;
    auto env = clear ? QProcessEnvironment() : sysenv;
    ...
}
```

`ProcessContext` defaults: `clearEnvironment = false`, `environment` empty, `unbindStdout = true`.
`INITIAL_ENVIRONMENT` is a snapshot taken at Quickshell startup:

```cpp
// src/launch/launch.cpp
Common::INITIAL_ENVIRONMENT = QProcessEnvironment::systemEnvironment();
```

So launched apps get the environment Quickshell was started with — **not** the current process
environment, and not variables set later via `Quickshell.env`.

Stdio: stdin is always `QProcess::nullDevice()`, and because `unbindStdout` defaults to true,
stdout **and stderr are also redirected to `/dev/null`**:

```cpp
process.setStandardInputFile(QProcess::nullDevice());
if (context.unbindStdout) {
    process.setStandardOutputFile(QProcess::nullDevice());
    process.setStandardErrorFile(QProcess::nullDevice());
}
```

### 3.6 Detached?

Yes, fully. `QProcess::startDetached()` (member) on Unix does `setsid()` plus a double fork
(`src/corelib/io/qprocess_unix.cpp`, `QProcessPrivate::startDetached`):

```cpp
pid_t childPid = childProcess.doFork([&] {
    ::setsid();
    ...
    if (childProcess.startChild(&doubleForkPid) == -1)
```

The child is reparented, gets its own session, and survives Quickshell. But:

```cpp
process.startDetached();
```

the boolean return value is **discarded** and the `QProcess` is a stack local, so a failed exec
(nonexistent program, bad `Path`) produces no error anywhere. This is the practical consequence
of not implementing `TryExec`.

---

## 4. The `id` property

`id` = the file's path **relative to its `applications` directory**, with `/` replaced by `-`,
and the final `.desktop` suffix removed via `completeBaseName()`:

- `~/.local/share/applications/firefox.desktop` → `firefox`
- `/usr/share/applications/kde4/kate.desktop` → `kde4-kate`
- `/usr/share/applications/org.kde.foo.desktop` → `org.kde.foo` (only the last suffix is stripped)

`Q_PROPERTY(QString id MEMBER mId CONSTANT);` — immutable, set once at parse time.

Lookup: `byId()` is exact, then case-insensitive (`lowercaseDesktopEntries`), with a warning when
two ids collide case-insensitively. `heuristicLookup()` additionally matches `StartupWMClass`
(exact, then case-insensitive).

---

## Semantic traps

1. **Field codes are removed, not expanded.** `%f/%F/%u/%U/%i/%c/%k` all disappear. Passing a
   file/URL argument yourself is required; `--file=%f` becomes `--file=`.
2. **`Terminal=true` does nothing.** No `$TERMINAL`, no terminal detection. `execute()` will run
   a TUI app with no TTY (stdin is `/dev/null`), so it usually exits immediately.
3. **No `TryExec`, no `OnlyShowIn`/`NotShowIn`.** Dead entries appear in the list; GNOME/KDE-only
   apps appear on Hyprland. Launch failures are invisible because `startDetached()`'s result is
   ignored.
4. **`NoDisplay` is not "hidden".** `NoDisplay=true` entries are removed from `applications()`
   but remain resolvable via `DesktopEntries.byId()` (documented in the header). `Hidden=true` is
   the one that deletes the id.
5. **Dedupe depends on the reversed scan.** If you reimplement this, scanning forward and
   "first wins" gives the wrong answer for `~/.local/share` overrides.
6. **`id` collisions are possible by construction**: `foo/bar.desktop` and `foo-bar.desktop` both
   produce `foo-bar`. Later-scanned (higher priority) wins silently.
7. **Order is `QHash` order.** `DesktopEntries.applications` is not alphabetical and can change
   between rescans. Sort by `name` yourself if you need stable ordering.
8. **Locale matching is not glibc's.** `LANGUAGE` is ignored; `LC_ALL` is ignored; only
   `LC_MESSAGES` then `LANG`; a key with a modifier (`sr@latin`) never matches a system locale
   without it; equal scores keep the first key in file order.
9. **The Exec tokenizer is not the spec's.** Single quotes == double quotes, no `\;` list
   escaping, empty arguments dropped, unknown escapes warn and keep the character. Do not feed it
   shell syntax; it will silently mangle it.
10. **Environment is a startup snapshot.** Exporting a var after Quickshell starts does not reach
    launched apps. stdout/stderr go to `/dev/null` by default (`unbindStdout = true`), so you
    cannot debug a broken `.desktop` Exec from Quickshell's output.
11. **On v0.3.2, lines are not trimmed.** Master added `line.trimmed()` on 2026-10-17
    (commit `30a5d60a31`). On 0.3.2 a CRLF `.desktop` file yields values ending in `\r`, so
    `Type == "Application"`, `Hidden == "true"`, `NoDisplay == "true"`, `Terminal == "true"` all
    fail, and indented lines/group headers are not recognized. Relevant if you pin 0.3.2.
12. **First access blocks.** `DesktopEntryManager`'s constructor runs the scan synchronously; the
    first `DesktopEntries.applications` access pays the full scan cost on that thread.
13. **`Type` must be exactly `Application`.** `Type=Application ` (trailing space, pre-0.3.3) or
    `type=application` is dropped, as is any `[Desktop Entry]` group without `Type`.
14. **`Path` is used verbatim**; no `~`, no env expansion, and an invalid path makes the launch
    fail silently.

## Unconfirmed

- Whether symlinked directories under `applications/` can cause unbounded recursion. `scanDirectory`
  uses `QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot` (no `NoSymLinks`), so symlinked dirs are
  followed; Qt's `QDir` docs say symlinks to directories are listed as directories. No loop guard
  is visible in the code, but I did not test it.
- Whether the `DesktopEntries` docs page (quickshell.org) documents `OnlyShowIn` as intentionally
  unsupported. Source shows no support; the docs were not checked line by line.
