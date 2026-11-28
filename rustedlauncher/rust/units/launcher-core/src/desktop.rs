//! XDG desktop-entry discovery and parsing.
//!
//! Mirrors what Quickshell's desktop-entry database handed the original:
//! `Type=Application`, not `Hidden`, not `NoDisplay`, a non-empty localized
//! `Name`, one entry per desktop-file id, user data dirs winning.

use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::{Path, PathBuf};

/// One launchable application.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct AppEntry {
    /// Desktop-file id: relative path below `applications/` with `/` turned
    /// into `-` and the `.desktop` suffix removed.
    pub id: String,
    pub name: String,
    pub generic_name: Option<String>,
    pub comment: Option<String>,
    pub keywords: Vec<String>,
    pub icon: Option<String>,
    /// Raw `Exec` value from the file.
    pub exec: String,
    pub path: Option<PathBuf>,
    pub terminal: bool,
    pub try_exec: Option<String>,
    pub desktop_path: PathBuf,
}

/// Locale candidates, most specific first (`ar_SA@mod`, `ar_SA`, `ar@mod`,
/// `ar`), derived from `LC_ALL`, `LC_MESSAGES` or `LANG`.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Locale {
    pub candidates: Vec<String>,
}

impl Locale {
    #[must_use]
    pub fn from_env() -> Self {
        let raw = ["LC_ALL", "LC_MESSAGES", "LANG"]
            .iter()
            .find_map(|key| std::env::var(key).ok().filter(|value| !value.is_empty()));
        raw.map_or_else(Self::default, |raw| Self::parse(&raw))
    }

    #[must_use]
    pub fn parse(raw: &str) -> Self {
        let base = raw.split('.').next().unwrap_or("");
        if base.is_empty() || base == "C" || base == "POSIX" {
            return Self::default();
        }
        let (language_country, modifier) = match base.split_once('@') {
            Some((head, modifier)) => (head, Some(modifier)),
            None => (base, None),
        };
        let (language, country) = match language_country.split_once('_') {
            Some((language, country)) => (language, Some(country)),
            None => (language_country, None),
        };
        let mut candidates = Vec::new();
        if let Some(country) = country {
            if let Some(modifier) = modifier {
                candidates.push(format!("{language}_{country}@{modifier}"));
            }
            candidates.push(format!("{language}_{country}"));
        }
        if let Some(modifier) = modifier {
            candidates.push(format!("{language}@{modifier}"));
        }
        if !language.is_empty() {
            candidates.push(language.to_owned());
        }
        candidates.dedup();
        Self { candidates }
    }
}

/// `$XDG_DATA_HOME` then `$XDG_DATA_DIRS`, in lookup order.
#[must_use]
pub fn data_dirs() -> Vec<PathBuf> {
    let home = std::env::var_os("HOME").map(PathBuf::from);
    let mut dirs = Vec::new();
    let data_home = std::env::var_os("XDG_DATA_HOME")
        .map(PathBuf::from)
        .or_else(|| home.map(|home| home.join(".local/share")));
    if let Some(data_home) = data_home {
        dirs.push(data_home);
    }
    let data_dirs =
        std::env::var("XDG_DATA_DIRS").unwrap_or_else(|_| "/usr/local/share:/usr/share".to_owned());
    for dir in data_dirs.split(':').filter(|dir| !dir.is_empty()) {
        dirs.push(PathBuf::from(dir));
    }
    dirs
}

/// Load the desktop-entry index from the standard XDG locations.
#[must_use]
pub fn load_entries() -> Vec<AppEntry> {
    load_entries_from(&data_dirs(), &Locale::from_env())
}

/// Load the desktop-entry index from explicit data directories.
#[must_use]
pub fn load_entries_from(dirs: &[PathBuf], locale: &Locale) -> Vec<AppEntry> {
    let mut seen: HashSet<String> = HashSet::new();
    let mut entries = Vec::new();
    for dir in dirs {
        let applications = dir.join("applications");
        let mut files = Vec::new();
        collect_desktop_files(&applications, 0, &mut files);
        files.sort();
        for file in files {
            let Some(id) = desktop_id(&applications, &file) else {
                continue;
            };
            if seen.contains(&id) {
                continue;
            }
            let Ok(content) = fs::read_to_string(&file) else {
                continue;
            };
            match parse_entry(&content, &id, &file, locale) {
                Some(entry) => {
                    seen.insert(id);
                    entries.push(entry);
                }
                // `Hidden=true` and `NoDisplay=true` delete the id, so a
                // higher-priority copy hides the lower-priority one.
                None if masks_lower_priority(&content) => {
                    seen.insert(id);
                }
                None => {}
            }
        }
    }
    entries
}

/// A `Type=Application` file that declares itself hidden or not displayed.
fn masks_lower_priority(content: &str) -> bool {
    let fields = Fields::parse(content);
    fields.get("Type").as_deref() == Some("Application")
        && (fields.boolean("Hidden") || fields.boolean("NoDisplay"))
}

fn collect_desktop_files(dir: &Path, depth: usize, out: &mut Vec<PathBuf>) {
    if depth > 8 {
        return;
    }
    let Ok(read_dir) = fs::read_dir(dir) else {
        return;
    };
    for entry in read_dir.flatten() {
        let path = entry.path();
        let Ok(file_type) = entry.file_type() else {
            continue;
        };
        if file_type.is_dir() {
            collect_desktop_files(&path, depth + 1, out);
        } else if (file_type.is_file() || file_type.is_symlink())
            && path.extension().is_some_and(|ext| ext == "desktop")
        {
            out.push(path);
        }
    }
}

fn desktop_id(applications: &Path, file: &Path) -> Option<String> {
    let relative = file.strip_prefix(applications).ok()?;
    let mut id = String::new();
    for (index, component) in relative.components().enumerate() {
        let component = component.as_os_str().to_str()?;
        let component = if index == 0 {
            component
        } else {
            if !id.is_empty() {
                id.push('-');
            }
            component
        };
        id.push_str(component);
    }
    id.strip_suffix(".desktop").map(ToOwned::to_owned)
}

/// Parse one desktop file. Returns `None` when the entry is not a visible
/// application.
#[must_use]
pub fn parse_entry(
    content: &str,
    id: &str,
    desktop_path: &Path,
    locale: &Locale,
) -> Option<AppEntry> {
    let fields = Fields::parse(content);
    if fields.get("Type").as_deref() != Some("Application") {
        return None;
    }
    if fields.boolean("Hidden") || fields.boolean("NoDisplay") {
        return None;
    }
    let name = fields.localized("Name", locale)?;
    if name.trim().is_empty() {
        return None;
    }
    let keywords = fields
        .localized("Keywords", locale)
        .map(|value| {
            value
                .split(';')
                .map(str::trim)
                .filter(|keyword| !keyword.is_empty())
                .map(ToOwned::to_owned)
                .collect()
        })
        .unwrap_or_default();
    Some(AppEntry {
        id: id.to_owned(),
        name,
        generic_name: fields.localized("GenericName", locale),
        comment: fields.localized("Comment", locale),
        keywords,
        icon: fields.get("Icon").filter(|icon| !icon.is_empty()),
        exec: fields.get("Exec").unwrap_or_default(),
        path: fields
            .get("Path")
            .filter(|path| !path.is_empty())
            .map(PathBuf::from),
        terminal: fields.boolean("Terminal"),
        try_exec: fields.get("TryExec").filter(|value| !value.is_empty()),
        desktop_path: desktop_path.to_path_buf(),
    })
}

/// Key/value pairs of the `[Desktop Entry]` group.
struct Fields {
    values: HashMap<String, String>,
}

impl Fields {
    fn parse(content: &str) -> Self {
        let mut values = HashMap::new();
        let mut in_group = false;
        for line in content.lines() {
            let line = line.trim_end_matches('\r');
            if line.starts_with('[') {
                in_group = line == "[Desktop Entry]";
                continue;
            }
            if !in_group || line.is_empty() || line.starts_with('#') {
                continue;
            }
            let Some((key, value)) = line.split_once('=') else {
                continue;
            };
            values.insert(key.trim().to_owned(), unescape(value));
        }
        Self { values }
    }

    fn get(&self, key: &str) -> Option<String> {
        self.values.get(key).cloned()
    }

    fn boolean(&self, key: &str) -> bool {
        self.values
            .get(key)
            .is_some_and(|value| value.eq_ignore_ascii_case("true") || value == "1")
    }

    fn localized(&self, key: &str, locale: &Locale) -> Option<String> {
        for candidate in &locale.candidates {
            if let Some(value) = self.values.get(&format!("{key}[{candidate}]")) {
                return Some(value.clone());
            }
        }
        self.get(key)
    }
}

/// Undo the desktop-entry value escapes (`\s`, `\n`, `\t`, `\r`, `\\`).
fn unescape(value: &str) -> String {
    let mut out = String::with_capacity(value.len());
    let mut chars = value.chars();
    while let Some(ch) = chars.next() {
        if ch != '\\' {
            out.push(ch);
            continue;
        }
        match chars.next() {
            Some('s') => out.push(' '),
            Some('n') => out.push('\n'),
            Some('t') => out.push('\t'),
            Some('r') => out.push('\r'),
            Some('\\') => out.push('\\'),
            Some(other) => {
                out.push('\\');
                out.push(other);
            }
            None => out.push('\\'),
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn locale() -> Locale {
        Locale::parse("en_US.UTF-8")
    }

    fn parse(content: &str) -> Option<AppEntry> {
        parse_entry(content, "test", Path::new("/tmp/test.desktop"), &locale())
    }

    #[test]
    fn locale_candidates_are_most_specific_first() {
        assert_eq!(
            Locale::parse("ar_SA@mod.UTF-8").candidates,
            ["ar_SA@mod", "ar_SA", "ar@mod", "ar"]
        );
        assert_eq!(Locale::parse("en_US.UTF-8").candidates, ["en_US", "en"]);
        assert!(Locale::parse("C").candidates.is_empty());
    }

    #[test]
    fn parses_a_visible_application() {
        let entry = parse(
            "[Desktop Entry]\n\
             Type=Application\n\
             Name=Firefox\n\
             Name[en_US]=Firefox US\n\
             GenericName=Web Browser\n\
             Comment=Browse the web\n\
             Keywords=internet;browser;\n\
             Icon=firefox\n\
             Exec=firefox %u\n\
             Terminal=false\n",
        )
        .expect("visible entry");
        assert_eq!(entry.name, "Firefox US");
        assert_eq!(entry.generic_name.as_deref(), Some("Web Browser"));
        assert_eq!(entry.comment.as_deref(), Some("Browse the web"));
        assert_eq!(entry.keywords, ["internet", "browser"]);
        assert_eq!(entry.icon.as_deref(), Some("firefox"));
        assert_eq!(entry.exec, "firefox %u");
        assert!(!entry.terminal);
    }

    #[test]
    fn skips_hidden_nodisplay_and_non_applications() {
        for content in [
            "[Desktop Entry]\nType=Application\nName=X\nHidden=true\n",
            "[Desktop Entry]\nType=Application\nName=X\nNoDisplay=true\n",
            "[Desktop Entry]\nType=Link\nName=X\n",
            "[Desktop Entry]\nType=Application\nName=\n",
        ] {
            assert!(parse(content).is_none(), "should skip: {content}");
        }
    }

    #[test]
    fn ignores_other_groups_and_unescapes_values() {
        let entry = parse(
            "[Desktop Entry]\nType=Application\nName=A\\sB\n\
             [Desktop Action new]\nName=Ignored\nExec=ignored\n",
        )
        .expect("entry");
        assert_eq!(entry.name, "A B");
        assert_eq!(entry.exec, "");
    }

    #[test]
    fn hidden_and_nodisplay_mask_lower_priority_entries() {
        let root = std::env::temp_dir().join(format!("rustedlauncher-mask-{}", std::process::id()));
        let user = root.join("user");
        let system = root.join("system");
        fs::create_dir_all(user.join("applications")).expect("mkdir");
        fs::create_dir_all(system.join("applications")).expect("mkdir");
        for (name, marker) in [("hidden", "Hidden"), ("nodisplay", "NoDisplay")] {
            fs::write(
                system.join(format!("applications/{name}.desktop")),
                format!("[Desktop Entry]\nType=Application\nName=System {name}\n"),
            )
            .expect("write");
            fs::write(
                user.join(format!("applications/{name}.desktop")),
                format!("[Desktop Entry]\nType=Application\nName=User {name}\n{marker}=true\n"),
            )
            .expect("write");
        }
        let entries = load_entries_from(&[user, system], &locale());
        assert!(entries.is_empty(), "both ids are masked: {entries:?}");
        let _ = fs::remove_dir_all(root);
    }

    #[test]
    fn discovery_prefers_user_directory_and_dedupes() {
        let root =
            std::env::temp_dir().join(format!("rustedlauncher-discovery-{}", std::process::id()));
        let user = root.join("user");
        let system = root.join("system");
        fs::create_dir_all(user.join("applications/sub")).expect("mkdir");
        fs::create_dir_all(system.join("applications/sub")).expect("mkdir");
        fs::write(
            user.join("applications/same.desktop"),
            "[Desktop Entry]\nType=Application\nName=User Same\n",
        )
        .expect("write");
        fs::write(
            system.join("applications/same.desktop"),
            "[Desktop Entry]\nType=Application\nName=System Same\n",
        )
        .expect("write");
        fs::write(
            system.join("applications/sub/nested.desktop"),
            "[Desktop Entry]\nType=Application\nName=Nested\n",
        )
        .expect("write");
        let entries = load_entries_from(&[user, system], &locale());
        let names: Vec<_> = entries.iter().map(|entry| entry.name.as_str()).collect();
        assert!(names.contains(&"User Same"));
        assert!(!names.contains(&"System Same"));
        let nested = entries
            .iter()
            .find(|entry| entry.id == "sub-nested")
            .expect("nested id uses dashes");
        assert_eq!(nested.name, "Nested");
        let _ = fs::remove_dir_all(root);
    }
}
