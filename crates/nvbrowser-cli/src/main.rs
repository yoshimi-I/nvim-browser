use std::{fs, io::Cursor, path::PathBuf};

use base64::{engine::general_purpose, Engine};
use clap::{Parser, Subcommand};
use image::ImageFormat;
use nvbrowser_core::{
    inspect_target, kitty_image_escape, render_markdown_document,
    renderer::chromium::{render_url_png, ChromiumOptions},
    FrameArtifact, KittyImageTransfer, Viewport,
};

#[derive(Debug, Parser)]
#[command(name = "nvbrowser")]
#[command(about = "Backend runtime for the nvim-browser plugin")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    Inspect {
        target: String,
    },
    RenderMd {
        path: PathBuf,
    },
    ShowImage {
        path: PathBuf,
    },
    Browse {
        url: String,
        #[arg(long, default_value_t = 1024)]
        width: u32,
        #[arg(long, default_value_t = 768)]
        height: u32,
    },
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
        Command::ShowImage { path } => {
            let image = image::open(path)?;
            let mut png = Cursor::new(Vec::new());
            image.write_to(&mut png, ImageFormat::Png)?;
            let encoded = general_purpose::STANDARD.encode(png.into_inner());
            print!("{}", kitty_image_escape(&encoded));
        }
        Command::Browse { url, width, height } => {
            let viewport = Viewport::new(width, height);
            let frame = render_url_png(&url, viewport, ChromiumOptions::detect())?;
            let FrameArtifact::Png(png) = frame.artifact else {
                return Err("Chromium renderer returned a non-PNG artifact".into());
            };
            let encoded = general_purpose::STANDARD.encode(png);
            print!(
                "{}",
                KittyImageTransfer::new(1, viewport.width, viewport.height, encoded).escape()
            );
        }
    }

    Ok(())
}
