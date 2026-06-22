use std::{fs, path::PathBuf};

use clap::{Parser, Subcommand};
use nvbrowser::{inspect_target, render_markdown_document};

#[derive(Debug, Parser)]
#[command(name = "nvbrowser")]
#[command(about = "Backend runtime for the nvim-browser plugin")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    Inspect { target: String },
    RenderMd { path: PathBuf },
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();

    match cli.command {
        Command::Inspect { target } => {
            println!("{}", inspect_target(&target).to_json());
        }
        Command::RenderMd { path } => {
            let markdown = fs::read_to_string(path)?;
            print!("{}", render_markdown_document(&markdown));
        }
    }

    Ok(())
}
