mod ipc;
mod launch;
mod ui;

use std::process::ExitCode;

use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(
    name = "rustedlauncher",
    version,
    about = "A minimal wofi/rofi-style application launcher for Hyprland"
)]
struct Cli {
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    /// Run the launcher daemon (default).
    Run,
    /// Toggle the launcher.
    Toggle,
    /// Open the launcher.
    Open,
    /// Hide the launcher.
    Hide,
    /// Print whether the launcher is visible.
    #[command(name = "isVisible", alias = "is-visible")]
    IsVisible,
}

impl Commands {
    fn verb(&self) -> Option<&'static str> {
        match self {
            Self::Run => None,
            Self::Toggle => Some("toggle"),
            Self::Open => Some("open"),
            Self::Hide => Some("hide"),
            Self::IsVisible => Some("isVisible"),
        }
    }
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    let command = cli.command.unwrap_or(Commands::Run);
    let Some(verb) = command.verb() else {
        return ui::run();
    };
    match ipc::send(verb) {
        Ok(response) => {
            if !response.is_empty() {
                println!("{response}");
            }
            ExitCode::SUCCESS
        }
        Err(error) => {
            eprintln!("rustedlauncher: {error}");
            ExitCode::FAILURE
        }
    }
}
