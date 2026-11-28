//! GTK4 + wlr-layer-shell overlay: the launcher window itself.

use std::cell::RefCell;
use std::collections::HashMap;
use std::path::PathBuf;
use std::rc::{Rc, Weak};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::{Duration, Instant};

use gtk::gdk;
use gtk::glib;
use gtk::prelude::*;
use gtk4_layer_shell::{KeyboardMode, Layer, LayerShell};
use launcher_core::desktop::{self, AppEntry};
use launcher_core::history::History;
use launcher_core::icon::{self, IconSource};
use launcher_core::search;

use crate::ipc;
use crate::launch;

const WIDTH: i32 = 360;
const HEIGHT: i32 = 470;
const MARGIN: i32 = 14;
const SPACING: i32 = 8;
const ENTRY_HEIGHT: i32 = 40;
const ROW_HEIGHT: i32 = 44;
const ICON_SIZE: i32 = 24;
const FILTER_DELAY: Duration = Duration::from_millis(80);

const CSS: &str = "
window.launcher-window { background-color: transparent; }
.panel {
    background-color: rgba(20, 20, 20, 0.659);
    border: 1px solid rgba(255, 255, 255, 0.078);
}
entry.search {
    background-color: rgba(255, 255, 255, 0.078);
    border: 1px solid rgba(255, 255, 255, 0.122);
    border-radius: 0;
    box-shadow: none;
    color: #8AB4FF;
    caret-color: #8AB4FF;
    font-size: 15px;
    padding: 0 14px;
    min-height: 0;
    outline: none;
}
entry.search:focus, entry.search:focus-within {
    outline: none;
    box-shadow: none;
    border-color: rgba(255, 255, 255, 0.122);
}
entry.search > text > placeholder, entry.search placeholder {
    color: rgba(255, 255, 255, 0.333);
}
list.app-list { background-color: transparent; }
list.app-list > row {
    background-color: transparent;
    border-radius: 0;
    padding: 0;
    min-height: 0;
}
list.app-list > row:hover {
    background-color: rgba(255, 255, 255, 0.078);
}
list.app-list > row:selected,
list.app-list > row:selected:hover,
list.app-list > row:selected:backdrop {
    background-color: rgba(255, 255, 255, 0.165);
}
label.app-name { color: #FFFFFF; font-size: 14px; }
label.app-letter {
    color: rgba(255, 255, 255, 0.439);
    font-size: 15px;
    font-weight: bold;
}
scrollbar { background: transparent; border: none; }
scrollbar slider {
    background: rgba(255, 255, 255, 0.15);
    min-width: 6px;
    min-height: 20px;
    border-radius: 3px;
}
";

#[derive(Clone)]
enum ResolvedIcon {
    Theme(String),
    File(PathBuf),
}

struct Ui {
    window: gtk::Window,
    entry: gtk::Entry,
    list: gtk::ListBox,
    scroll: gtk::ScrolledWindow,
    apps: Vec<AppEntry>,
    filtered: Vec<usize>,
    selected: usize,
    history: History,
    visible: Arc<AtomicBool>,
    last_shown: Instant,
    generation: u64,
    pending: bool,
    suppress: bool,
    icon_cache: HashMap<String, Option<ResolvedIcon>>,
    /// Modification times of the `applications` directories at the last scan.
    /// Re-parsing every desktop file on each open costs more than it is worth.
    scan_stamp: Vec<(PathBuf, Option<std::time::SystemTime>)>,
    icon_theme: gtk::IconTheme,
    home: PathBuf,
    monitor: Option<gdk::Monitor>,
    me: Weak<RefCell<Ui>>,
    _hold: gtk::gio::ApplicationHoldGuard,
}

impl Ui {
    fn build(app: &gtk::Application, visible: Arc<AtomicBool>) -> Rc<RefCell<Self>> {
        let window = gtk::Window::builder()
            .application(app)
            .title("rustedlauncher")
            .default_width(WIDTH)
            .default_height(HEIGHT)
            .resizable(false)
            .decorated(false)
            .build();
        window.add_css_class("launcher-window");
        window.init_layer_shell();
        // The original's namespace, so `rules.lua`'s blur rule for
        // `quickshell:mylauncher` keeps applying without a config change.
        window.set_namespace(Some("quickshell:mylauncher"));
        window.set_layer(Layer::Overlay);
        window.set_keyboard_mode(KeyboardMode::Exclusive);
        window.set_exclusive_zone(-1);

        let monitor = pointer_monitor();
        if let Some(monitor) = &monitor {
            window.set_monitor(Some(monitor));
        }

        // Realize now: mapping a fresh layer surface blocks on a compositor
        // round-trip, and SUPER must show the panel immediately.
        gtk::prelude::WidgetExt::realize(&window);

        let panel = gtk::Box::new(gtk::Orientation::Vertical, 0);
        panel.add_css_class("panel");
        panel.set_size_request(WIDTH, HEIGHT);

        let content = gtk::Box::new(gtk::Orientation::Vertical, SPACING);
        content.set_margin_top(MARGIN);
        content.set_margin_bottom(MARGIN);
        content.set_margin_start(MARGIN);
        content.set_margin_end(MARGIN);
        content.set_vexpand(true);

        let entry = gtk::Entry::new();
        entry.add_css_class("search");
        entry.set_placeholder_text(Some("search"));
        entry.set_height_request(ENTRY_HEIGHT);
        entry.set_hexpand(true);

        let scroll = gtk::ScrolledWindow::new();
        scroll.set_policy(gtk::PolicyType::Never, gtk::PolicyType::Automatic);
        scroll.set_overlay_scrolling(true);
        scroll.set_has_frame(false);
        scroll.set_vexpand(true);
        scroll.set_hexpand(true);

        let list = gtk::ListBox::new();
        list.add_css_class("app-list");
        list.set_selection_mode(gtk::SelectionMode::Single);
        list.set_activate_on_single_click(true);
        scroll.set_child(Some(&list));

        content.append(&entry);
        content.append(&scroll);
        panel.append(&content);
        window.set_child(Some(&panel));

        let home = std::env::var_os("HOME").map_or_else(|| PathBuf::from("."), PathBuf::from);
        let icon_theme = gtk::IconTheme::for_display(&gdk::Display::default().expect("display"));

        let ui = Rc::new(RefCell::new(Self {
            window: window.clone(),
            entry: entry.clone(),
            list: list.clone(),
            scroll: scroll.clone(),
            apps: Vec::new(),
            filtered: Vec::new(),
            selected: 0,
            history: History::load(History::default_path()),
            visible,
            last_shown: Instant::now(),
            generation: 0,
            pending: false,
            suppress: false,
            icon_cache: HashMap::new(),
            scan_stamp: Vec::new(),
            icon_theme,
            home,
            monitor,
            me: Weak::new(),
            _hold: app.hold(),
        }));
        ui.borrow_mut().me = Rc::downgrade(&ui);
        ui.borrow_mut().reload();

        let weak = Rc::downgrade(&ui);
        entry.connect_changed(move |_| {
            let Some(ui) = weak.upgrade() else {
                return;
            };
            // `try_borrow_mut`: `open()` clears the text from inside a borrow,
            // and GTK emits `changed` synchronously from `set_text`.
            let Ok(mut this) = ui.try_borrow_mut() else {
                return;
            };
            if !this.suppress {
                this.schedule_filter();
            }
        });

        let weak = Rc::downgrade(&ui);
        list.connect_row_activated(move |_, row| {
            if let Some(ui) = weak.upgrade() {
                let index = row.index().max(0) as usize;
                ui.borrow_mut().launch(index);
            }
        });

        let weak = Rc::downgrade(&ui);
        let keys = gtk::EventControllerKey::new();
        keys.set_propagation_phase(gtk::PropagationPhase::Capture);
        keys.connect_key_pressed(move |_, key, _, _| {
            let Some(ui) = weak.upgrade() else {
                return glib::Propagation::Proceed;
            };
            let mut this = ui.borrow_mut();
            match key {
                gdk::Key::Escape => {
                    this.hide();
                    glib::Propagation::Stop
                }
                gdk::Key::Up => {
                    this.move_selection(-1);
                    glib::Propagation::Stop
                }
                gdk::Key::Down => {
                    this.move_selection(1);
                    glib::Propagation::Stop
                }
                gdk::Key::Return | gdk::Key::KP_Enter => {
                    this.launch_selected();
                    glib::Propagation::Stop
                }
                _ => glib::Propagation::Proceed,
            }
        });
        window.add_controller(keys);

        let flag = Arc::clone(&ui.borrow().visible);
        window.connect_close_request(move |window| {
            window.set_visible(false);
            flag.store(false, Ordering::Relaxed);
            glib::Propagation::Stop
        });

        ui
    }

    fn reload(&mut self) {
        self.apps = desktop::load_entries();
        self.scan_stamp = scan_stamp();
        self.history = History::load(History::default_path());
        self.icon_cache.clear();
    }

    fn open(&mut self) {
        if scan_stamp() == self.scan_stamp {
            // Nothing was installed or removed: keep the parsed index and only
            // refresh the counts, which another launcher instance may have moved.
            self.history = History::load(History::default_path());
        } else {
            self.reload();
        }
        self.update_monitor();
        self.suppress = true;
        self.entry.set_text("");
        self.suppress = false;
        self.apply_filter();
        // Set before mapping: the surface takes a compositor round-trip and
        // `isVisible` must answer for the state the caller asked for.
        self.visible.store(true, Ordering::Relaxed);
        // `present`, not `set_visible`: a layer surface only gets its configure
        // and maps through the present path.
        self.window.present();
        self.entry.grab_focus();
        self.last_shown = Instant::now();
    }

    fn hide(&mut self) {
        self.window.set_visible(false);
        self.visible.store(false, Ordering::Relaxed);
    }

    fn update_monitor(&mut self) {
        let Some(monitor) = pointer_monitor() else {
            return;
        };
        let same = self
            .monitor
            .as_ref()
            .is_some_and(|current| same_geometry(current, &monitor));
        if same {
            return;
        }
        if self.window.is_visible() {
            self.window.set_visible(false);
            gtk::prelude::NativeExt::unrealize(&self.window);
        }
        self.window.set_monitor(Some(&monitor));
        self.monitor = Some(monitor);
    }

    fn schedule_filter(&mut self) {
        self.generation = self.generation.wrapping_add(1);
        self.pending = true;
        let generation = self.generation;
        let weak = self.me.clone();
        glib::timeout_add_local_once(FILTER_DELAY, move || {
            let Some(ui) = weak.upgrade() else {
                return;
            };
            let mut this = ui.borrow_mut();
            if this.generation == generation {
                this.apply_filter();
            }
        });
    }

    fn apply_filter(&mut self) {
        self.generation = self.generation.wrapping_add(1);
        self.pending = false;
        let query = self.entry.text().to_string();
        self.filtered = search::search_indices(&self.apps, &query, &self.history);
        self.rebuild_rows();
        self.select_index(0);
    }

    fn rebuild_rows(&mut self) {
        while let Some(child) = self.list.first_child() {
            self.list.remove(&child);
        }
        for index in 0..self.filtered.len() {
            let row = self.build_row(index);
            self.list.append(&row);
        }
    }

    fn build_row(&mut self, index: usize) -> gtk::ListBoxRow {
        let entry = self.apps[self.filtered[index]].clone();
        let row = gtk::ListBoxRow::new();
        row.set_size_request(-1, ROW_HEIGHT);

        let line = gtk::Box::new(gtk::Orientation::Horizontal, 10);
        line.set_margin_start(16);
        line.set_margin_end(12);

        line.append(&self.icon_widget(&entry));

        let label = gtk::Label::new(Some(&entry.name));
        label.add_css_class("app-name");
        label.set_xalign(0.0);
        label.set_hexpand(true);
        label.set_ellipsize(gtk::pango::EllipsizeMode::End);
        line.append(&label);

        row.set_child(Some(&line));
        row
    }

    fn icon_widget(&mut self, entry: &AppEntry) -> gtk::Widget {
        match self.resolve_icon(entry.icon.as_deref()) {
            Some(ResolvedIcon::Theme(name)) => {
                let image = gtk::Image::from_icon_name(&name);
                image.set_pixel_size(ICON_SIZE);
                image.set_size_request(ICON_SIZE, ICON_SIZE);
                image.upcast()
            }
            Some(ResolvedIcon::File(path)) => {
                let image = gtk::Image::from_file(&path);
                image.set_pixel_size(ICON_SIZE);
                image.set_size_request(ICON_SIZE, ICON_SIZE);
                image.upcast()
            }
            None => letter_label(&entry.name),
        }
    }

    fn resolve_icon(&mut self, name: Option<&str>) -> Option<ResolvedIcon> {
        let key = name.unwrap_or("").to_owned();
        if let Some(cached) = self.icon_cache.get(&key) {
            return cached.clone();
        }
        let mut resolved = None;
        for source in icon::chain(name, &self.home) {
            match source {
                IconSource::Theme(theme) => {
                    if self.icon_theme.has_icon(&theme) {
                        resolved = Some(ResolvedIcon::Theme(theme));
                        break;
                    }
                }
                IconSource::File(path) => {
                    if path.is_file() {
                        resolved = Some(ResolvedIcon::File(path));
                        break;
                    }
                }
            }
        }
        self.icon_cache.insert(key, resolved.clone());
        resolved
    }

    fn select_index(&mut self, index: usize) {
        if self.filtered.is_empty() {
            self.list.unselect_all();
            self.selected = 0;
            return;
        }
        let index = index.min(self.filtered.len() - 1);
        self.selected = index;
        if let Some(row) = self.list.row_at_index(index as i32) {
            self.list.select_row(Some(&row));
        }
        self.scroll_to(index);
    }

    fn scroll_to(&self, index: usize) {
        let adjustment = self.scroll.vadjustment();
        let top = index as f64 * f64::from(ROW_HEIGHT);
        let bottom = top + f64::from(ROW_HEIGHT);
        let value = adjustment.value();
        let page = adjustment.page_size();
        if top < value {
            adjustment.set_value(top);
        } else if page > 0.0 && bottom > value + page {
            adjustment.set_value(bottom - page);
        }
    }

    fn move_selection(&mut self, delta: i32) {
        if self.filtered.is_empty() {
            return;
        }
        let next = (self.selected as i32 + delta).clamp(0, self.filtered.len() as i32 - 1);
        self.select_index(next as usize);
    }

    fn launch_selected(&mut self) {
        if self.pending {
            self.apply_filter();
        }
        self.launch(self.selected);
    }

    fn launch(&mut self, index: usize) {
        let Some(&app_index) = self.filtered.get(index) else {
            return;
        };
        let app = self.apps[app_index].clone();
        if let Err(error) = self.history.record(&app.id) {
            eprintln!("rustedlauncher: cannot save history: {error}");
        }
        match launch::spawn(&app) {
            Ok(()) => self.hide(),
            Err(error) => eprintln!("rustedlauncher: cannot launch {}: {error}", app.name),
        }
    }
}

fn letter_label(name: &str) -> gtk::Widget {
    let letter = name
        .chars()
        .next()
        .map_or('?', |ch| ch.to_uppercase().next().unwrap_or(ch));
    let label = gtk::Label::new(Some(&letter.to_string()));
    label.add_css_class("app-letter");
    label.set_size_request(ICON_SIZE, ICON_SIZE);
    label.set_halign(gtk::Align::Center);
    label.set_valign(gtk::Align::Center);
    label.upcast()
}

fn install_css() {
    let provider = gtk::CssProvider::new();
    provider.load_from_data(CSS);
    if let Some(display) = gdk::Display::default() {
        gtk::style_context_add_provider_for_display(
            &display,
            &provider,
            gtk::STYLE_PROVIDER_PRIORITY_APPLICATION,
        );
    }
}

/// Modification times of the XDG `applications` directories. Installing or
/// removing a desktop file bumps one; editing a file in place does not.
fn scan_stamp() -> Vec<(PathBuf, Option<std::time::SystemTime>)> {
    desktop::data_dirs()
        .into_iter()
        .map(|dir| {
            let path = dir.join("applications");
            let modified = std::fs::metadata(&path)
                .and_then(|meta| meta.modified())
                .ok();
            (path, modified)
        })
        .collect()
}

fn monitors() -> Vec<gdk::Monitor> {
    let Some(display) = gdk::Display::default() else {
        return Vec::new();
    };
    let list = display.monitors();
    (0..list.n_items())
        .filter_map(|index| list.item(index))
        .filter_map(|object| object.downcast::<gdk::Monitor>().ok())
        .collect()
}

fn same_geometry(left: &gdk::Monitor, right: &gdk::Monitor) -> bool {
    left.geometry() == right.geometry()
}

fn pointer_monitor() -> Option<gdk::Monitor> {
    let monitors = monitors();
    let first = monitors.first().cloned();
    // One output: nothing to choose, and no need to spawn `hyprctl` on a path
    // the launcher takes on every open.
    if monitors.len() <= 1 {
        return first;
    }
    let Some((x, y)) = pointer_position() else {
        return first;
    };
    monitors
        .into_iter()
        .find(|monitor| {
            let geometry = monitor.geometry();
            x >= geometry.x()
                && x < geometry.x() + geometry.width()
                && y >= geometry.y()
                && y < geometry.y() + geometry.height()
        })
        .or(first)
}

fn pointer_position() -> Option<(i32, i32)> {
    let output = std::process::Command::new("hyprctl")
        .args(["cursorpos", "-j"])
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let text = String::from_utf8(output.stdout).ok()?;
    if let Ok(value) = serde_json::from_str::<serde_json::Value>(&text) {
        let x = value.get("x")?.as_f64()? as i32;
        let y = value.get("y")?.as_f64()? as i32;
        return Some((x, y));
    }
    let (x, y) = text.trim().split_once(',')?;
    Some((x.trim().parse().ok()?, y.trim().parse().ok()?))
}

pub fn run() -> std::process::ExitCode {
    let visible = Arc::new(AtomicBool::new(false));
    let (events, receiver) = std::sync::mpsc::channel::<ipc::Command>();
    if let Err(error) = ipc::serve(events, Arc::clone(&visible)) {
        eprintln!("rustedlauncher: {error}");
        return std::process::ExitCode::FAILURE;
    }

    let app = gtk::Application::builder()
        .application_id("dev.ali.rustedlauncher")
        .flags(gtk::gio::ApplicationFlags::NON_UNIQUE)
        .build();
    // Register and build the windows before running the loop. `activate`
    // sometimes never fires for a daemon with no initial window, and then the
    // application exits at once with nothing wired up.
    // GApplication warns without an activate handler; the windows are built
    // below, so this exists only to satisfy it.
    app.connect_activate(|_| {});
    if let Err(error) = app.register(None::<&gtk::gio::Cancellable>) {
        eprintln!("rustedlauncher: cannot start GTK: {error}");
        return std::process::ExitCode::FAILURE;
    }
    if !gtk4_layer_shell::is_supported() {
        eprintln!("rustedlauncher: wlr-layer-shell is not supported by this compositor");
        return std::process::ExitCode::FAILURE;
    }
    install_css();
    let ui = Ui::build(&app, Arc::clone(&visible));
    let receiver = Rc::new(RefCell::new(receiver));
    glib::timeout_add_local(Duration::from_millis(16), move || {
        let receiver = receiver.borrow();
        while let Ok(command) = receiver.try_recv() {
            let mut this = ui.borrow_mut();
            match command {
                ipc::Command::Toggle => {
                    if this.window.is_visible() {
                        this.hide();
                    } else {
                        this.open();
                    }
                }
                ipc::Command::Open => this.open(),
                ipc::Command::Hide => this.hide(),
                ipc::Command::IsVisible => {}
            }
        }
        glib::ControlFlow::Continue
    });

    let code = app.run_with_args(&["rustedlauncher"]);
    if code == glib::ExitCode::SUCCESS {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::FAILURE
    }
}
