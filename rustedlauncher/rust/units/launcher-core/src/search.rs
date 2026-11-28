//! Ranking, copied tier by tier from `AppProvider.qml`.

use std::cmp::Ordering;

use crate::desktop::AppEntry;
use crate::history::History;

/// Score one entry against a raw query. `-1` means "does not match".
#[must_use]
pub fn score(query: &str, entry: &AppEntry) -> i32 {
    let query = query.to_lowercase();
    let query = query.trim();
    if query.is_empty() {
        return 50;
    }
    let name = entry.name.to_lowercase();
    if name == query {
        return 100;
    }
    if name.starts_with(query) {
        return 80;
    }
    if name.contains(query) {
        return 60;
    }
    if let Some(generic) = &entry.generic_name
        && generic.to_lowercase().contains(query)
    {
        return 45;
    }
    if let Some(comment) = &entry.comment
        && comment.to_lowercase().contains(query)
    {
        return 35;
    }
    if !entry.exec.is_empty() && entry.exec.to_lowercase().contains(query) {
        return 25;
    }
    if entry
        .keywords
        .iter()
        .any(|keyword| keyword.to_lowercase().contains(query))
    {
        return 20;
    }
    if fuzzy_match(query, &name) {
        return 10;
    }
    -1
}

/// Subsequence match on lowercased text, as in the original.
#[must_use]
pub fn fuzzy_match(query_lower: &str, text_lower: &str) -> bool {
    let mut query = query_lower.chars();
    let Some(mut wanted) = query.next() else {
        return true;
    };
    for ch in text_lower.chars() {
        if ch == wanted {
            match query.next() {
                Some(next) => wanted = next,
                None => return true,
            }
        }
    }
    false
}

/// Indices into `apps` in display order for `query`.
#[must_use]
pub fn search_indices(apps: &[AppEntry], query: &str, history: &History) -> Vec<usize> {
    let mut indices: Vec<usize> = if query.is_empty() {
        (0..apps.len()).collect()
    } else {
        (0..apps.len())
            .filter(|&index| score(query, &apps[index]) >= 0)
            .collect()
    };
    indices.sort_by(|&left, &right| compare(query, &apps[left], &apps[right], history));
    indices
}

fn compare(query: &str, left: &AppEntry, right: &AppEntry, history: &History) -> Ordering {
    if !query.is_empty() {
        let left_score = score(query, left);
        let right_score = score(query, right);
        if left_score != right_score {
            return right_score.cmp(&left_score);
        }
    }
    history
        .count(&right.id)
        .cmp(&history.count(&left.id))
        .then_with(|| locale_cmp(&left.name, &right.name))
}

/// Case-insensitive Unicode ordering with the raw name as tiebreak. Qt's
/// `localeCompare` is locale-aware; this is the closest deterministic rule
/// and is recorded as a known difference.
#[must_use]
pub fn locale_cmp(left: &str, right: &str) -> Ordering {
    left.to_lowercase()
        .cmp(&right.to_lowercase())
        .then_with(|| left.cmp(right))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn entry(id: &str, name: &str) -> AppEntry {
        AppEntry {
            id: id.to_owned(),
            name: name.to_owned(),
            generic_name: None,
            comment: None,
            keywords: Vec::new(),
            icon: None,
            exec: format!("{id} %u"),
            path: None,
            terminal: false,
            try_exec: None,
            desktop_path: PathBuf::from(format!("/tmp/{id}.desktop")),
        }
    }

    fn history() -> History {
        History::from_pairs(
            PathBuf::from("/tmp/none.json"),
            &[("zen", 98), ("steam", 8)],
        )
    }

    #[test]
    fn score_tiers_match_the_original() {
        let mut app = entry("firefox", "Firefox");
        assert_eq!(score("", &app), 50);
        assert_eq!(score("   ", &app), 50);
        assert_eq!(score("firefox", &app), 100);
        assert_eq!(score("fire", &app), 80);
        assert_eq!(score("fox", &app), 60);
        app.generic_name = Some("Web Browser".to_owned());
        assert_eq!(score("browser", &app), 45);
        app.comment = Some("Browse the web".to_owned());
        assert_eq!(score("the web", &app), 35);
        assert_eq!(score("firefox %u", &app), 25);
        app.keywords = vec!["internet".to_owned()];
        assert_eq!(score("internet", &app), 20);
        assert_eq!(score("ffx", &app), 10);
        assert_eq!(score("zzz", &app), -1);
    }

    #[test]
    fn fuzzy_is_a_subsequence() {
        assert!(fuzzy_match("ffx", "firefox"));
        assert!(fuzzy_match("", "anything"));
        assert!(!fuzzy_match("xff", "firefox"));
        assert!(!fuzzy_match("firefoxes", "firefox"));
    }

    #[test]
    fn empty_query_orders_by_usage_then_name() {
        let apps = vec![
            entry("zen", "Zen"),
            entry("steam", "Steam"),
            entry("firefox", "Firefox"),
        ];
        let order = search_indices(&apps, "", &history());
        let names: Vec<_> = order
            .iter()
            .map(|&index| apps[index].name.as_str())
            .collect();
        assert_eq!(names, ["Zen", "Steam", "Firefox"]);
    }

    #[test]
    fn query_orders_by_score_then_usage() {
        let apps = vec![
            entry("firefox", "Firefox"),
            entry("files", "Files"),
            entry("zen", "Zen"),
        ];
        let order = search_indices(&apps, "fi", &history());
        assert_eq!(
            apps[order[0]].id, "files",
            "prefix score 80 beats contains 60"
        );
        let order = search_indices(&apps, "e", &history());
        let ids: Vec<_> = order.iter().map(|&index| apps[index].id.as_str()).collect();
        assert_eq!(ids, ["zen", "files", "firefox"]);
    }

    #[test]
    fn case_insensitive_name_match() {
        let apps = vec![entry("code", "Visual Studio Code")];
        assert_eq!(search_indices(&apps, "VISUAL", &history()), [0]);
        assert!(search_indices(&apps, "vim", &history()).is_empty());
    }
}
