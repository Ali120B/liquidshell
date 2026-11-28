//! Launching a desktop entry: plan in `launcher-core`, spawn here, reap on a
//! background thread so the long-running daemon collects no zombies.

use launcher_core::AppEntry;
use launcher_core::exec;

pub fn spawn(entry: &AppEntry) -> Result<(), String> {
    let terminal = std::env::var("TERMINAL").ok();
    let path_env = std::env::var_os("PATH").unwrap_or_default();
    let plan = exec::build_plan(entry, terminal.as_deref(), &path_env)
        .map_err(|error| format!("{}: {error}", entry.name))?;
    let mut command = std::process::Command::new(&plan.argv[0]);
    // The original binds the child's stdio to /dev/null; a launcher must not
    // hold a pipe back to the daemon and must not inherit its terminal.
    command
        .args(&plan.argv[1..])
        .stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null());
    if let Some(cwd) = &plan.cwd {
        command.current_dir(cwd);
    }
    let mut child = command
        .spawn()
        .map_err(|error| format!("{}: {error}", plan.argv[0]))?;
    // Reap on a thread: the daemon outlives the app it starts, so nothing
    // else will collect the child.

    std::thread::spawn(move || {
        let _ = child.wait();
    });
    Ok(())
}
