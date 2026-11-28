//! Usage history: a compact JSON object of desktop-file id to launch count,
//! stored at the original launcher's path so existing counts carry over.

use std::collections::HashMap;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};

use serde_json::{Map, Value};

#[derive(Clone, Debug)]
pub struct History {
    path: PathBuf,
    counts: Map<String, Value>,
}

impl History {
    /// `~/.local/state/mylauncher/history.json`, the original path.
    #[must_use]
    pub fn default_path() -> PathBuf {
        let home = std::env::var_os("HOME").map_or_else(|| PathBuf::from("."), PathBuf::from);
        home.join(".local/state/mylauncher/history.json")
    }

    /// Load the history at `path`; a missing or malformed file is empty.
    #[must_use]
    pub fn load(path: PathBuf) -> Self {
        let counts = fs::read_to_string(&path)
            .ok()
            .and_then(|text| serde_json::from_str::<Value>(&text).ok())
            .and_then(|value| match value {
                Value::Object(map) => Some(map),
                _ => None,
            })
            .unwrap_or_default();
        Self { path, counts }
    }

    /// A history with explicit counts, for tests.
    #[must_use]
    pub fn from_pairs(path: PathBuf, pairs: &[(&str, u64)]) -> Self {
        let mut counts = Map::new();
        for (id, count) in pairs {
            counts.insert((*id).to_owned(), Value::from(*count));
        }
        Self { path, counts }
    }

    #[must_use]
    pub fn path(&self) -> &Path {
        &self.path
    }

    /// Launch count for `id`; malformed values count as zero.
    #[must_use]
    pub fn count(&self, id: &str) -> u64 {
        self.counts
            .get(id)
            .and_then(|value| {
                value
                    .as_u64()
                    .or_else(|| value.as_f64().map(|number| number.max(0.0) as u64))
            })
            .unwrap_or(0)
    }

    /// Increment `id` and persist the history.
    pub fn record(&mut self, id: &str) -> io::Result<()> {
        let next = self.count(id).saturating_add(1);
        self.counts.insert(id.to_owned(), Value::from(next));
        self.save()
    }

    /// Write the compact JSON object, creating the state directory.
    pub fn save(&self) -> io::Result<()> {
        if let Some(parent) = self.path.parent() {
            fs::create_dir_all(parent)?;
        }
        let text =
            serde_json::to_string(&Value::Object(self.counts.clone())).map_err(io::Error::other)?;
        fs::write(&self.path, text)
    }

    /// Counts as a plain map, for assertions.
    #[must_use]
    pub fn snapshot(&self) -> HashMap<String, u64> {
        self.counts
            .keys()
            .map(|id| (id.clone(), self.count(id)))
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_path(name: &str) -> PathBuf {
        std::env::temp_dir().join(format!(
            "rustedlauncher-history-{}-{name}.json",
            std::process::id()
        ))
    }

    #[test]
    fn round_trips_compact_json_and_preserves_order() {
        let path = temp_path("roundtrip");
        let _ = fs::remove_file(&path);
        let mut history = History::from_pairs(path.clone(), &[("zen", 98), ("steam", 8)]);
        history.record("zen").expect("record");
        history.record("firefox").expect("record");
        let text = fs::read_to_string(&path).expect("read");
        assert_eq!(text, r#"{"zen":99,"steam":8,"firefox":1}"#);
        let loaded = History::load(path.clone());
        assert_eq!(loaded.count("zen"), 99);
        assert_eq!(loaded.count("firefox"), 1);
        assert_eq!(loaded.count("missing"), 0);
        let _ = fs::remove_file(path);
    }

    #[test]
    fn malformed_history_is_empty() {
        let path = temp_path("malformed");
        fs::write(&path, "not json").expect("write");
        assert_eq!(History::load(path.clone()).count("zen"), 0);
        fs::write(&path, "[1,2,3]").expect("write");
        assert_eq!(History::load(path.clone()).count("zen"), 0);
        let _ = fs::remove_file(path);
    }
}
