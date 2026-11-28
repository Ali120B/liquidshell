//! Unix-socket control protocol: one text command per connection, one text
//! line back. Verbs match the original Quickshell IPC names.

use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::PathBuf;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::Sender;
use std::time::Duration;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Command {
    Toggle,
    Open,
    Hide,
    IsVisible,
}

/// `$XDG_RUNTIME_DIR/rustedlauncher.sock`, or a per-user `/tmp` fallback.
#[must_use]
pub fn socket_path() -> PathBuf {
    if let Some(dir) = std::env::var_os("XDG_RUNTIME_DIR") {
        return PathBuf::from(dir).join("rustedlauncher.sock");
    }
    let user = std::env::var("USER").unwrap_or_else(|_| "user".to_owned());
    PathBuf::from(format!("/tmp/rustedlauncher-{user}.sock"))
}

pub fn parse(line: &str) -> Result<Command, String> {
    match line.trim() {
        "toggle" => Ok(Command::Toggle),
        "open" => Ok(Command::Open),
        "hide" => Ok(Command::Hide),
        "isVisible" | "is-visible" => Ok(Command::IsVisible),
        other => Err(format!("unknown command: {other}")),
    }
}

/// Send one command to the running daemon and return its reply.
pub fn send(command: &str) -> Result<String, String> {
    let path = socket_path();
    let mut stream = UnixStream::connect(&path)
        .map_err(|error| format!("launcher is not running ({}): {error}", path.display()))?;
    let _ = stream.set_read_timeout(Some(Duration::from_secs(2)));
    let _ = stream.set_write_timeout(Some(Duration::from_secs(2)));
    writeln!(stream, "{command}")
        .map_err(|error| format!("cannot write to the launcher: {error}"))?;
    stream
        .flush()
        .map_err(|error| format!("cannot write to the launcher: {error}"))?;
    let mut response = String::new();
    BufReader::new(stream)
        .read_line(&mut response)
        .map_err(|error| format!("cannot read the launcher's reply: {error}"))?;
    Ok(response.trim_end_matches(['\r', '\n']).to_owned())
}

/// Bind the control socket and serve requests on a background thread.
pub fn serve(events: Sender<Command>, visible: Arc<AtomicBool>) -> std::io::Result<()> {
    let path = socket_path();
    if path.exists() {
        if UnixStream::connect(&path).is_ok() {
            return Err(std::io::Error::new(
                std::io::ErrorKind::AlreadyExists,
                format!("another instance is already running ({})", path.display()),
            ));
        }
        let _ = std::fs::remove_file(&path);
    }
    if let Some(parent) = path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    let listener = UnixListener::bind(&path)?;
    std::thread::spawn(move || {
        for stream in listener.incoming().flatten() {
            if let Err(error) = handle(stream, &events, &visible) {
                eprintln!("rustedlauncher: control connection failed: {error}");
            }
        }
    });
    Ok(())
}

fn handle(
    mut stream: UnixStream,
    events: &Sender<Command>,
    visible: &AtomicBool,
) -> std::io::Result<()> {
    let reader = BufReader::new(stream.try_clone()?);
    let mut line = String::new();
    let mut reader = reader;
    reader.read_line(&mut line)?;
    let response = match parse(&line) {
        Ok(Command::IsVisible) => {
            if visible.load(Ordering::Relaxed) {
                "true".to_owned()
            } else {
                "false".to_owned()
            }
        }
        Ok(command) => {
            let _ = events.send(command);
            String::new()
        }
        Err(error) => format!("error: {error}"),
    };
    writeln!(stream, "{response}")?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_the_original_verbs() {
        assert_eq!(parse("toggle\n"), Ok(Command::Toggle));
        assert_eq!(parse("open"), Ok(Command::Open));
        assert_eq!(parse("hide"), Ok(Command::Hide));
        assert_eq!(parse("isVisible"), Ok(Command::IsVisible));
        assert_eq!(parse("is-visible"), Ok(Command::IsVisible));
        assert!(parse("bogus").is_err());
    }
}
