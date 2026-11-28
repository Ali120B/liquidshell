//! `Exec` parsing and launch planning.
//!
//! Implements the Desktop Entry spec's field codes and `Terminal=true`
//! handling without delegating to GIO, so terminal selection is predictable
//! on a non-GNOME desktop.

use std::ffi::OsStr;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};

use crate::desktop::AppEntry;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ExecPlan {
    pub argv: Vec<String>,
    pub cwd: Option<PathBuf>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ExecError {
    Empty,
    UnclosedQuote,
    NoTerminal,
}

impl std::fmt::Display for ExecError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Empty => write!(f, "desktop entry has an empty Exec"),
            Self::UnclosedQuote => write!(f, "unclosed quote in Exec"),
            Self::NoTerminal => write!(f, "Terminal=true but no terminal emulator was found"),
        }
    }
}

impl std::error::Error for ExecError {}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Terminal {
    pub program: String,
    /// Arguments between the terminal program and the launched command.
    pub prefix: Vec<String>,
}

/// Split an `Exec` value into words, honouring double quotes, single quotes
/// and backslash escapes.
pub fn parse_words(input: &str) -> Result<Vec<String>, ExecError> {
    let mut words = Vec::new();
    let mut current = String::new();
    let mut in_word = false;
    let mut chars = input.chars();
    while let Some(ch) = chars.next() {
        match ch {
            ' ' | '\t' | '\n' => {
                if in_word {
                    words.push(std::mem::take(&mut current));
                    in_word = false;
                }
            }
            '"' => {
                in_word = true;
                loop {
                    match chars.next() {
                        None => return Err(ExecError::UnclosedQuote),
                        Some('"') => break,
                        Some('\\') => match chars.next() {
                            Some(escaped) => current.push(escaped),
                            None => return Err(ExecError::UnclosedQuote),
                        },
                        Some(other) => current.push(other),
                    }
                }
            }
            '\'' => {
                in_word = true;
                loop {
                    match chars.next() {
                        None => return Err(ExecError::UnclosedQuote),
                        Some('\'') => break,
                        Some(other) => current.push(other),
                    }
                }
            }
            '\\' => {
                in_word = true;
                match chars.next() {
                    Some(escaped) => current.push(escaped),
                    None => return Err(ExecError::UnclosedQuote),
                }
            }
            other => {
                in_word = true;
                current.push(other);
            }
        }
    }
    if in_word {
        words.push(current);
    }
    Ok(words)
}

/// Expand the spec's field codes. `%i` becomes two arguments; `%f`, `%F`,
/// `%u`, `%U` and the deprecated codes are dropped because the launcher never
/// launches with files or URLs.
#[must_use]
pub fn expand_field_codes(words: &[String], entry: &AppEntry) -> Vec<String> {
    let mut out = Vec::new();
    for word in words {
        match word.as_str() {
            "%f" | "%F" | "%u" | "%U" | "%d" | "%D" | "%n" | "%N" | "%v" | "%m" => {}
            "%i" => {
                if let Some(icon) = &entry.icon {
                    out.push("--icon".to_owned());
                    out.push(icon.clone());
                }
            }
            "%c" => out.push(entry.name.clone()),
            "%k" => out.push(entry.desktop_path.display().to_string()),
            "%%" => out.push("%".to_owned()),
            other => out.push(expand_embedded(other, entry)),
        }
    }
    out
}

fn expand_embedded(word: &str, entry: &AppEntry) -> String {
    let mut out = String::with_capacity(word.len());
    let mut chars = word.chars().peekable();
    while let Some(ch) = chars.next() {
        if ch != '%' {
            out.push(ch);
            continue;
        }
        match chars.next() {
            Some('%') => out.push('%'),
            Some('c') => out.push_str(&entry.name),
            Some('k') => out.push_str(&entry.desktop_path.to_string_lossy()),
            Some('f' | 'F' | 'u' | 'U' | 'i' | 'd' | 'D' | 'n' | 'N' | 'v' | 'm') | None => {}
            Some(other) => out.push(other),
        }
    }
    out
}

/// Terminal invocation rules for the common emulators.
#[must_use]
pub fn terminal_for(program: &str) -> Terminal {
    let basename = Path::new(program)
        .file_name()
        .and_then(OsStr::to_str)
        .unwrap_or(program);
    let prefix: &[&str] = match basename {
        "xdg-terminal-exec" | "foot" | "footclient" => &[],
        "kitty" => &["--"],
        "wezterm" => &["start", "--"],
        "gnome-terminal" | "kgx" => &["--"],
        "alacritty" | "ghostty" | "konsole" | "xterm" | "urxvt" | "st" | "sakura" => &["-e"],
        _ => &["-e"],
    };
    Terminal {
        program: program.to_owned(),
        prefix: prefix.iter().map(|arg| (*arg).to_owned()).collect(),
    }
}

/// `$TERMINAL` may carry arguments (`kitty --single-instance`).
fn terminal_from_value(value: &str) -> Option<Terminal> {
    let words = parse_words(value).ok()?;
    let (program, extra) = words.split_first()?;
    let mut terminal = terminal_for(program);
    let mut prefix = extra.to_vec();
    prefix.extend(terminal.prefix);
    terminal.prefix = prefix;
    Some(terminal)
}

const TERMINAL_CANDIDATES: [&str; 9] = [
    "xdg-terminal-exec",
    "kitty",
    "foot",
    "alacritty",
    "wezterm",
    "ghostty",
    "konsole",
    "gnome-terminal",
    "xterm",
];

/// First known terminal found in `path_env`.
#[must_use]
pub fn detect_terminal(path_env: &OsStr) -> Option<Terminal> {
    TERMINAL_CANDIDATES
        .iter()
        .find(|program| find_in_path(program, path_env).is_some())
        .map(|program| terminal_for(program))
}

/// Resolve `program` against `path_env`, requiring an executable file.
#[must_use]
pub fn find_in_path(program: &str, path_env: &OsStr) -> Option<PathBuf> {
    if program.contains('/') {
        let path = PathBuf::from(program);
        return is_executable(&path).then_some(path);
    }
    std::env::split_paths(path_env)
        .map(|dir| dir.join(program))
        .find(|candidate| is_executable(candidate))
}

fn is_executable(path: &Path) -> bool {
    path.metadata()
        .is_ok_and(|metadata| metadata.is_file() && metadata.permissions().mode() & 0o111 != 0)
}

/// Build the argv for an entry. `terminal_env` is `$TERMINAL`; `path_env` is
/// `$PATH`, used only to find a terminal and `TryExec`.
pub fn build_plan(
    entry: &AppEntry,
    terminal_env: Option<&str>,
    path_env: &OsStr,
) -> Result<ExecPlan, ExecError> {
    let words = parse_words(&entry.exec)?;
    if words.is_empty() {
        return Err(ExecError::Empty);
    }
    let mut argv = expand_field_codes(&words, entry);
    if argv.is_empty() {
        return Err(ExecError::Empty);
    }
    if entry.terminal {
        let terminal = terminal_env
            .and_then(terminal_from_value)
            .or_else(|| detect_terminal(path_env))
            .ok_or(ExecError::NoTerminal)?;
        let mut wrapped = Vec::with_capacity(1 + terminal.prefix.len() + argv.len());
        wrapped.push(terminal.program);
        wrapped.extend(terminal.prefix);
        wrapped.append(&mut argv);
        argv = wrapped;
    }
    Ok(ExecPlan {
        argv,
        cwd: entry.path.clone(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn entry(exec: &str) -> AppEntry {
        AppEntry {
            id: "test".to_owned(),
            name: "Test App".to_owned(),
            generic_name: None,
            comment: None,
            keywords: Vec::new(),
            icon: Some("test-icon".to_owned()),
            exec: exec.to_owned(),
            path: Some(PathBuf::from("/tmp")),
            terminal: false,
            try_exec: None,
            desktop_path: PathBuf::from("/usr/share/applications/test.desktop"),
        }
    }

    #[test]
    fn parses_quotes_and_escapes() {
        assert_eq!(
            parse_words(r#"app --flag "two words" 'single word' plain\ space"#).expect("words"),
            ["app", "--flag", "two words", "single word", "plain space"]
        );
        assert_eq!(parse_words("app \"\"").expect("words"), ["app", ""]);
        assert_eq!(
            parse_words(r#"app "unclosed"#),
            Err(ExecError::UnclosedQuote)
        );
    }

    #[test]
    fn expands_field_codes() {
        let entry = entry("app %f %F %u %U %i %c %k %% 100%% %d");
        assert_eq!(
            expand_field_codes(&parse_words(&entry.exec).expect("words"), &entry),
            [
                "app",
                "--icon",
                "test-icon",
                "Test App",
                "/usr/share/applications/test.desktop",
                "%",
                "100%",
            ]
        );
    }

    #[test]
    fn wraps_terminal_entries() {
        let mut entry = entry("htop");
        entry.terminal = true;
        let plan = build_plan(&entry, Some("kitty"), OsStr::new("/nonexistent")).expect("plan");
        assert_eq!(plan.argv, ["kitty", "--", "htop"]);
        assert_eq!(plan.cwd.as_deref(), Some(Path::new("/tmp")));

        let plan = build_plan(&entry, Some("alacritty --class float"), OsStr::new(""))
            .expect("plan with args");
        assert_eq!(plan.argv, ["alacritty", "--class", "float", "-e", "htop"]);
    }

    #[test]
    fn reports_missing_terminal() {
        let mut entry = entry("htop");
        entry.terminal = true;
        assert_eq!(
            build_plan(&entry, None, OsStr::new("/nonexistent")),
            Err(ExecError::NoTerminal)
        );
    }

    #[test]
    fn finds_executables_in_path() {
        let root = std::env::temp_dir().join(format!("rustedlauncher-exec-{}", std::process::id()));
        std::fs::create_dir_all(&root).expect("mkdir");
        let binary = root.join("mytool");
        std::fs::write(&binary, "#!/bin/sh\n").expect("write");
        let mut permissions = std::fs::metadata(&binary).expect("metadata").permissions();
        permissions.set_mode(0o755);
        std::fs::set_permissions(&binary, permissions).expect("chmod");
        let path = OsStr::new(root.to_str().expect("utf8"));
        assert_eq!(find_in_path("mytool", path), Some(binary));
        assert_eq!(find_in_path("absent", path), None);
        let _ = std::fs::remove_dir_all(root);
    }
}
