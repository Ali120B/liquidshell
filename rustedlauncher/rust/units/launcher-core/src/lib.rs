//! Pure logic of the launcher: XDG desktop entries, ranking, usage history,
//! launch planning and icon candidates. No GTK, no I/O beyond reading files.

pub mod desktop;
pub mod exec;
pub mod history;
pub mod icon;
pub mod search;

pub use desktop::{AppEntry, Locale, load_entries, load_entries_from};
pub use history::History;
