//! Icon candidate chain, mirroring `shell.qml`'s `iconChain`.

use std::path::{Path, PathBuf};

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum IconSource {
    Theme(String),
    File(PathBuf),
}

/// Generic fallbacks, in the original's order.
pub const GENERIC: [&str; 5] = [
    "image-missing",
    "application-x-executable",
    "exec",
    "application-default-icon",
    "system-run",
];

/// Candidates in try order. Theme names are checked against the icon theme
/// by the caller; file candidates are checked for existence.
#[must_use]
pub fn chain(icon: Option<&str>, home: &Path) -> Vec<IconSource> {
    let mut out = Vec::new();
    let name = icon.unwrap_or("");
    if !name.is_empty() {
        if name.starts_with('/') {
            out.push(IconSource::File(PathBuf::from(name)));
        } else {
            out.push(IconSource::Theme(name.to_owned()));
            let mut stripped = "";
            if let Some(dot) = name.rfind('.').filter(|dot| *dot > 0) {
                let extension = name[dot..].to_ascii_lowercase();
                if matches!(extension.as_str(), ".png" | ".svg" | ".xpm") {
                    stripped = &name[..dot];
                }
            }
            if !stripped.is_empty() {
                out.push(IconSource::Theme(stripped.to_owned()));
            }
            let bases: &[&str] = if stripped.is_empty() {
                &[name]
            } else {
                &[name, stripped]
            };
            let dirs = [
                home.join(".local/share/icons"),
                PathBuf::from("/usr/share/pixmaps"),
            ];
            for dir in &dirs {
                for base in bases {
                    let lower = base.to_ascii_lowercase();
                    if lower.ends_with(".png") || lower.ends_with(".svg") || lower.ends_with(".xpm")
                    {
                        out.push(IconSource::File(dir.join(base)));
                    } else {
                        out.push(IconSource::File(dir.join(format!("{base}.png"))));
                        out.push(IconSource::File(dir.join(format!("{base}.svg"))));
                        out.push(IconSource::File(dir.join(format!("{base}.xpm"))));
                    }
                }
            }
        }
    }
    out.extend(
        GENERIC
            .iter()
            .map(|name| IconSource::Theme((*name).to_owned())),
    );
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn home() -> PathBuf {
        PathBuf::from("/home/user")
    }

    #[test]
    fn absolute_path_is_the_only_file_candidate_before_generic() {
        let candidates = chain(Some("/opt/app/icon.png"), &home());
        assert_eq!(
            candidates[0],
            IconSource::File(PathBuf::from("/opt/app/icon.png"))
        );
        assert_eq!(candidates.len(), 1 + GENERIC.len());
    }

    #[test]
    fn theme_name_with_extension_tries_stripped_theme_and_files() {
        let candidates = chain(Some("steam.png"), &home());
        assert_eq!(candidates[0], IconSource::Theme("steam.png".to_owned()));
        assert_eq!(candidates[1], IconSource::Theme("steam".to_owned()));
        assert!(candidates.contains(&IconSource::File(PathBuf::from(
            "/home/user/.local/share/icons/steam.png"
        ))));
        assert!(candidates.contains(&IconSource::File(PathBuf::from(
            "/usr/share/pixmaps/steam.svg"
        ))));
    }

    #[test]
    fn plain_name_gets_extension_variants() {
        let candidates = chain(Some("firefox"), &home());
        assert!(candidates.contains(&IconSource::File(PathBuf::from(
            "/home/user/.local/share/icons/firefox.png"
        ))));
        assert!(candidates.contains(&IconSource::File(PathBuf::from(
            "/usr/share/pixmaps/firefox.xpm"
        ))));
    }

    #[test]
    fn missing_icon_is_only_generic() {
        let candidates = chain(None, &home());
        assert_eq!(candidates.len(), GENERIC.len());
        assert_eq!(candidates[0], IconSource::Theme("image-missing".to_owned()));
    }
}
