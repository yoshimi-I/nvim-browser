use std::{fs, io::Cursor, path::PathBuf};

use base64::{engine::general_purpose, Engine};
use clap::{Parser, Subcommand, ValueEnum};
use image::{imageops::FilterType, DynamicImage, GenericImageView, ImageFormat, Rgba};
use nvbrowser_core::{
    inspect_target, kitty_image_escape, render_markdown_document,
    renderer::chromium::{render_url_png, ChromiumOptions},
    FrameArtifact, KittyImagePlacement, KittyImageTransfer, Viewport,
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
        #[arg(long, value_enum, default_value_t = ImageOutput::Kitty)]
        output: ImageOutput,
        #[arg(long, default_value_t = 100)]
        columns: u32,
    },
    Browse {
        url: String,
        #[arg(long, default_value_t = 1024)]
        width: u32,
        #[arg(long, default_value_t = 768)]
        height: u32,
        #[arg(long, value_enum, default_value_t = ImageOutput::Kitty)]
        output: ImageOutput,
        #[arg(long, default_value_t = 100)]
        columns: u32,
        #[arg(long)]
        rows: Option<u32>,
    },
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, ValueEnum)]
enum ImageOutput {
    Kitty,
    Ansi,
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
        Command::ShowImage {
            path,
            output,
            columns,
        } => {
            let image = image::open(path)?;
            match output {
                ImageOutput::Kitty => {
                    let mut png = Cursor::new(Vec::new());
                    image.write_to(&mut png, ImageFormat::Png)?;
                    let encoded = general_purpose::STANDARD.encode(png.into_inner());
                    print!("{}", kitty_image_escape(&encoded));
                }
                ImageOutput::Ansi => {
                    print!("{}", image_to_ansi_halfblocks(&image, columns));
                }
            }
        }
        Command::Browse {
            url,
            width,
            height,
            output,
            columns,
            rows,
        } => {
            let viewport = Viewport::new(width, height);
            let frame = render_url_png(&url, viewport, ChromiumOptions::detect())?;
            let FrameArtifact::Png(png) = frame.artifact else {
                return Err("Chromium renderer returned a non-PNG artifact".into());
            };
            match output {
                ImageOutput::Kitty => {
                    let encoded = general_purpose::STANDARD.encode(png);
                    print!("{}", kitty_browse_escape(encoded, viewport, columns, rows));
                }
                ImageOutput::Ansi => {
                    let image = image::load_from_memory_with_format(&png, ImageFormat::Png)?;
                    print!("{}", image_to_ansi_halfblocks(&image, columns));
                }
            }
        }
    }

    Ok(())
}

fn kitty_browse_escape(
    encoded_png: String,
    viewport: Viewport,
    columns: u32,
    rows: Option<u32>,
) -> String {
    let transfer = KittyImageTransfer::new(1, viewport.width, viewport.height, encoded_png);
    let Some(rows) = rows else {
        return transfer.escape();
    };

    format!(
        "{}{}",
        transfer.upload_escape(),
        KittyImagePlacement::new(1, 1, columns.max(1), rows.max(1)).escape()
    )
}

fn image_to_ansi_halfblocks(image: &DynamicImage, columns: u32) -> String {
    let columns = columns.max(1);
    let (width, height) = image.dimensions();
    let aspect = height as f32 / width.max(1) as f32;
    let mut target_height = (aspect * columns as f32).round().max(2.0) as u32;
    if !target_height.is_multiple_of(2) {
        target_height += 1;
    }

    let resized = image
        .resize_exact(columns, target_height, FilterType::Triangle)
        .to_rgba8();
    let mut output = String::new();

    for y in (0..target_height).step_by(2) {
        for x in 0..columns {
            let top = rgba_to_rgb(*resized.get_pixel(x, y));
            let bottom = rgba_to_rgb(*resized.get_pixel(x, y + 1));
            output.push_str(&format!(
                "\x1b[38;2;{};{};{}m\x1b[48;2;{};{};{}m▀",
                top.0, top.1, top.2, bottom.0, bottom.1, bottom.2
            ));
        }
        output.push_str("\x1b[0m\n");
    }

    output
}

fn rgba_to_rgb(pixel: Rgba<u8>) -> (u8, u8, u8) {
    let [r, g, b, a] = pixel.0;
    if a == 255 {
        return (r, g, b);
    }

    let alpha = a as f32 / 255.0;
    (
        (r as f32 * alpha) as u8,
        (g as f32 * alpha) as u8,
        (b as f32 * alpha) as u8,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn kitty_browse_escape_includes_placement_when_rows_are_provided() {
        let escape = kitty_browse_escape(
            "iVBORw0KGgo=".to_string(),
            Viewport::new(800, 600),
            80,
            Some(24),
        );

        assert!(escape.contains("a=t,i=1"));
        assert!(!escape.contains("a=T,i=1"));
        assert!(escape.contains("s=800,v=600"));
        assert!(escape.contains("a=p,i=1,p=1,c=80,r=24"));
    }

    #[test]
    fn kitty_browse_escape_preserves_legacy_transfer_without_rows() {
        let escape = kitty_browse_escape(
            "iVBORw0KGgo=".to_string(),
            Viewport::new(800, 600),
            80,
            None,
        );

        assert!(escape.contains("a=T,i=1"));
        assert!(!escape.contains("a=p"));
    }
}
