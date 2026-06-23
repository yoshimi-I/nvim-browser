use std::{
    fs,
    io::{self, BufRead, Cursor, Write},
    path::PathBuf,
};

use base64::{engine::general_purpose, Engine};
use clap::{Parser, Subcommand, ValueEnum};
use image::{imageops::FilterType, DynamicImage, GenericImageView, ImageFormat, Rgba};
use nvbrowser_core::{
    inspect_target, kitty_image_escape, render_markdown_document,
    renderer::chromium::{render_url_png, ChromiumOptions},
    BrowserSession, ChromiumRenderer, ClickPointRequest, FocusSelectorRequest, FrameArtifact,
    HistoryNavigationRequest, KeyPressRequest, KittyImageTransfer, NavigateRequest, ReloadRequest,
    RenderFrameRequest, RenderedFrame, Renderer, ScrollRequest, SessionId, TextInputRequest,
    Viewport,
};
use serde::{Deserialize, Serialize};

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
    Serve {
        #[arg(long, value_enum, default_value_t = ImageOutput::KittyUnicode)]
        output: ImageOutput,
        #[arg(long, default_value_t = 80)]
        columns: u32,
        #[arg(long, default_value_t = 24)]
        rows: u32,
        #[arg(long, default_value_t = 800)]
        width: u32,
        #[arg(long, default_value_t = 480)]
        height: u32,
        #[arg(long)]
        url: Option<String>,
    },
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, ValueEnum)]
enum ImageOutput {
    Kitty,
    KittyUnicode,
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
                ImageOutput::KittyUnicode => {
                    return Err("kitty-unicode output is only supported by browse".into());
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
                ImageOutput::KittyUnicode => {
                    let encoded = general_purpose::STANDARD.encode(png);
                    print!(
                        "{}",
                        kitty_unicode_browse_escape(encoded, viewport, columns, rows)
                    );
                }
                ImageOutput::Ansi => {
                    let image = image::load_from_memory_with_format(&png, ImageFormat::Png)?;
                    print!("{}", image_to_ansi_halfblocks(&image, columns));
                }
            }
        }
        Command::Serve {
            output,
            columns,
            rows,
            width,
            height,
            url,
        } => {
            let options = ServeOptions {
                output,
                columns,
                rows,
                viewport: Viewport::new(width, height),
                initial_url: url,
            };
            serve_stdio(options)?;
        }
    }

    Ok(())
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum ServeRequest {
    Navigate {
        id: u64,
        url: String,
    },
    Capture {
        id: u64,
    },
    Scroll {
        id: u64,
        delta_x: i32,
        delta_y: i32,
    },
    Reload {
        id: u64,
    },
    Back {
        id: u64,
    },
    Forward {
        id: u64,
    },
    TextInput {
        id: u64,
        text: String,
    },
    KeyPress {
        id: u64,
        key: String,
    },
    FocusSelector {
        id: u64,
        selector: String,
    },
    ClickPoint {
        id: u64,
        x: f64,
        y: f64,
    },
    Resize {
        id: u64,
        columns: u32,
        rows: u32,
        width: u32,
        height: u32,
    },
    Quit {
        id: u64,
    },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
struct ServeResponse {
    id: u64,
    status: ServeStatus,
    #[serde(skip_serializing_if = "Option::is_none")]
    payload: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
enum ServeStatus {
    Ok,
    Error,
}

fn parse_serve_request(line: &str) -> Result<ServeRequest, serde_json::Error> {
    serde_json::from_str(line)
}

fn encode_serve_response(response: &ServeResponse) -> String {
    serde_json::to_string(response).expect("serve responses should serialize")
}

#[derive(Debug, Clone, PartialEq)]
struct ServeOptions {
    output: ImageOutput,
    columns: u32,
    rows: u32,
    viewport: Viewport,
    initial_url: Option<String>,
}

struct ServeRuntime<R: Renderer> {
    renderer: R,
    session: BrowserSession,
    columns: u32,
    rows: u32,
    output: ImageOutput,
}

impl<R: Renderer> ServeRuntime<R> {
    fn new(renderer: R, options: ServeOptions) -> Self {
        Self {
            renderer,
            session: BrowserSession::new(SessionId::new(1), options.viewport),
            columns: options.columns,
            rows: options.rows,
            output: options.output,
        }
    }

    fn handle(&mut self, request: ServeRequest) -> ServeResponse {
        let id = request.id();
        match self.try_handle(request) {
            Ok(payload) => ServeResponse {
                id,
                status: ServeStatus::Ok,
                payload,
                url: self.session.active_page().url().map(str::to_string),
                error: None,
            },
            Err(error) => ServeResponse {
                id,
                status: ServeStatus::Error,
                payload: None,
                url: self.session.active_page().url().map(str::to_string),
                error: Some(error.to_string()),
            },
        }
    }

    fn try_handle(
        &mut self,
        request: ServeRequest,
    ) -> Result<Option<String>, Box<dyn std::error::Error>> {
        match request {
            ServeRequest::Navigate { url, .. } => {
                let navigation = self.renderer.navigate(NavigateRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    url,
                ))?;
                self.session.navigate_active_page(navigation.url);
                self.session.finish_active_page_load();
                self.capture_payload().map(Some)
            }
            ServeRequest::Capture { .. } => self.capture_payload().map(Some),
            ServeRequest::Scroll {
                delta_x, delta_y, ..
            } => {
                self.renderer.scroll(ScrollRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    delta_x,
                    delta_y,
                ))?;
                self.capture_payload().map(Some)
            }
            ServeRequest::Reload { .. } => {
                let reload = self.renderer.reload(ReloadRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                ))?;
                self.session.navigate_active_page(reload.url);
                self.session.finish_active_page_load();
                self.capture_payload().map(Some)
            }
            ServeRequest::Back { .. } => {
                let navigation = self.renderer.go_back(HistoryNavigationRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                ))?;
                self.session.navigate_active_page(navigation.url);
                self.session.finish_active_page_load();
                self.capture_payload().map(Some)
            }
            ServeRequest::Forward { .. } => {
                let navigation = self.renderer.go_forward(HistoryNavigationRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                ))?;
                self.session.navigate_active_page(navigation.url);
                self.session.finish_active_page_load();
                self.capture_payload().map(Some)
            }
            ServeRequest::TextInput { text, .. } => {
                self.renderer.input_text(TextInputRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    text,
                ))?;
                self.settle_after_interaction()?;
                self.capture_payload().map(Some)
            }
            ServeRequest::KeyPress { key, .. } => {
                self.renderer.press_key(KeyPressRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    key,
                ))?;
                self.settle_after_interaction()?;
                self.capture_payload().map(Some)
            }
            ServeRequest::FocusSelector { selector, .. } => {
                self.renderer.focus_selector(FocusSelectorRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    selector,
                ))?;
                self.settle_after_interaction()?;
                self.capture_payload().map(Some)
            }
            ServeRequest::ClickPoint { x, y, .. } => {
                self.renderer.click_point(ClickPointRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    x,
                    y,
                ))?;
                self.settle_after_interaction()?;
                self.capture_payload().map(Some)
            }
            ServeRequest::Resize {
                columns,
                rows,
                width,
                height,
                ..
            } => {
                self.columns = columns;
                self.rows = rows;
                self.session
                    .update_active_viewport(Viewport::new(width, height));
                self.capture_payload().map(Some)
            }
            ServeRequest::Quit { .. } => {
                self.renderer.shutdown()?;
                Ok(None)
            }
        }
    }

    fn capture_payload(&mut self) -> Result<String, Box<dyn std::error::Error>> {
        let frame = self.renderer.render_frame(RenderFrameRequest::new(
            self.session.id(),
            self.session.active_page_id(),
            self.session.active_page().viewport(),
        ))?;
        self.session.set_active_page_frame(frame.metadata.clone());
        frame_to_payload(frame, self.output, self.columns, Some(self.rows))
    }

    fn settle_after_interaction(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let settled = self.renderer.settle_after_interaction()?;
        self.session.navigate_active_page(settled.url);
        self.session.finish_active_page_load();
        Ok(())
    }
}

impl ServeRequest {
    fn id(&self) -> u64 {
        match self {
            ServeRequest::Navigate { id, .. }
            | ServeRequest::Capture { id }
            | ServeRequest::Scroll { id, .. }
            | ServeRequest::Reload { id }
            | ServeRequest::Back { id }
            | ServeRequest::Forward { id }
            | ServeRequest::TextInput { id, .. }
            | ServeRequest::KeyPress { id, .. }
            | ServeRequest::FocusSelector { id, .. }
            | ServeRequest::ClickPoint { id, .. }
            | ServeRequest::Resize { id, .. }
            | ServeRequest::Quit { id } => *id,
        }
    }
}

fn frame_to_payload(
    frame: RenderedFrame,
    output: ImageOutput,
    columns: u32,
    rows: Option<u32>,
) -> Result<String, Box<dyn std::error::Error>> {
    let FrameArtifact::Png(png) = frame.artifact else {
        return Err("renderer returned a non-PNG artifact".into());
    };
    let viewport = frame.metadata.viewport;
    match output {
        ImageOutput::Kitty => {
            let encoded = general_purpose::STANDARD.encode(png);
            Ok(kitty_browse_escape(encoded, viewport, columns, rows))
        }
        ImageOutput::KittyUnicode => {
            let encoded = general_purpose::STANDARD.encode(png);
            Ok(kitty_unicode_browse_escape(
                encoded, viewport, columns, rows,
            ))
        }
        ImageOutput::Ansi => {
            let image = image::load_from_memory_with_format(&png, ImageFormat::Png)?;
            Ok(image_to_ansi_halfblocks(&image, columns))
        }
    }
}

fn serve_stdio(options: ServeOptions) -> Result<(), Box<dyn std::error::Error>> {
    let mut runtime = ServeRuntime::new(
        ChromiumRenderer::launch(options.viewport, ChromiumOptions::detect())?,
        options.clone(),
    );
    let stdout = io::stdout();
    let mut writer = stdout.lock();

    if let Some(url) = options.initial_url {
        writeln!(
            writer,
            "{}",
            encode_serve_response(&runtime.handle(ServeRequest::Navigate { id: 0, url }))
        )?;
        writer.flush()?;
    }

    for line in io::stdin().lock().lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }
        let request = match parse_serve_request(&line) {
            Ok(request) => request,
            Err(error) => {
                writeln!(
                    writer,
                    "{}",
                    encode_serve_response(&ServeResponse {
                        id: 0,
                        status: ServeStatus::Error,
                        payload: None,
                        url: None,
                        error: Some(error.to_string()),
                    })
                )?;
                writer.flush()?;
                continue;
            }
        };
        let should_quit = matches!(request, ServeRequest::Quit { .. });
        let response = runtime.handle(request);
        writeln!(writer, "{}", encode_serve_response(&response))?;
        writer.flush()?;
        if should_quit {
            break;
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

    transfer.placed_escape(1, columns, rows)
}

fn kitty_unicode_browse_escape(
    encoded_png: String,
    viewport: Viewport,
    columns: u32,
    rows: Option<u32>,
) -> String {
    let transfer = KittyImageTransfer::new(1, viewport.width, viewport.height, encoded_png);
    transfer.virtual_placement_escape(columns, rows.unwrap_or(1))
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
    use nvbrowser_core::{
        FrameId, FrameMetadata, HistoryNavigationResult, InputResult, InteractionSettleResult,
        NavigationResult, ReloadResult, RendererError, RendererErrorKind, ScrollResult,
        ShutdownResult,
    };

    struct FakeRenderer {
        url: Option<String>,
        captures: u64,
        scrolls: Vec<(i32, i32)>,
        text_inputs: Vec<String>,
        key_presses: Vec<String>,
        focused_selectors: Vec<String>,
        clicked_points: Vec<(f64, f64)>,
        operations: Vec<&'static str>,
        history: Vec<String>,
        history_index: Option<usize>,
        settled_url: Option<String>,
        final_navigation_url: Option<String>,
        final_reload_url: Option<String>,
        shutdown: bool,
    }

    impl FakeRenderer {
        fn new() -> Self {
            Self {
                url: None,
                captures: 0,
                scrolls: Vec::new(),
                text_inputs: Vec::new(),
                key_presses: Vec::new(),
                focused_selectors: Vec::new(),
                clicked_points: Vec::new(),
                operations: Vec::new(),
                history: Vec::new(),
                history_index: None,
                settled_url: None,
                final_navigation_url: None,
                final_reload_url: None,
                shutdown: false,
            }
        }
    }

    impl Renderer for FakeRenderer {
        fn navigate(
            &mut self,
            request: NavigateRequest,
        ) -> Result<NavigationResult, RendererError> {
            let url = self.final_navigation_url.clone().unwrap_or(request.url);
            if let Some(index) = self.history_index {
                self.history.truncate(index + 1);
            }
            self.history.push(url.clone());
            self.history_index = Some(self.history.len() - 1);
            self.url = Some(url.clone());
            Ok(NavigationResult {
                session_id: request.session_id,
                page_id: request.page_id,
                url,
            })
        }

        fn render_frame(
            &mut self,
            request: RenderFrameRequest,
        ) -> Result<RenderedFrame, RendererError> {
            let url = self.url.clone().ok_or_else(|| {
                RendererError::new(RendererErrorKind::InvalidState, "missing url")
            })?;
            self.operations.push("capture");
            self.captures += 1;
            Ok(RenderedFrame {
                metadata: FrameMetadata::new(
                    FrameId::new(self.captures),
                    request.session_id,
                    request.page_id,
                    url,
                    request.viewport,
                    1000 + self.captures,
                ),
                artifact: FrameArtifact::Png(tiny_png()),
            })
        }

        fn scroll(&mut self, request: ScrollRequest) -> Result<ScrollResult, RendererError> {
            self.scrolls.push((request.delta_x, request.delta_y));
            Ok(ScrollResult {
                session_id: request.session_id,
                page_id: request.page_id,
                delta_x: request.delta_x,
                delta_y: request.delta_y,
            })
        }

        fn reload(&mut self, request: ReloadRequest) -> Result<ReloadResult, RendererError> {
            let url = self
                .final_reload_url
                .clone()
                .or_else(|| self.url.clone())
                .unwrap_or_else(|| "about:blank".to_string());
            self.url = Some(url.clone());
            Ok(ReloadResult {
                session_id: request.session_id,
                page_id: request.page_id,
                url,
            })
        }

        fn go_back(
            &mut self,
            request: HistoryNavigationRequest,
        ) -> Result<HistoryNavigationResult, RendererError> {
            self.operations.push("back");
            let index = self.history_index.ok_or_else(|| {
                RendererError::new(RendererErrorKind::InvalidState, "no browser history")
            })?;
            let previous = index.checked_sub(1).ok_or_else(|| {
                RendererError::new(RendererErrorKind::InvalidState, "no back history entry")
            })?;
            self.history_index = Some(previous);
            let url = self.history[previous].clone();
            self.url = Some(url.clone());
            Ok(HistoryNavigationResult {
                session_id: request.session_id,
                page_id: request.page_id,
                url,
            })
        }

        fn go_forward(
            &mut self,
            request: HistoryNavigationRequest,
        ) -> Result<HistoryNavigationResult, RendererError> {
            self.operations.push("forward");
            let index = self.history_index.ok_or_else(|| {
                RendererError::new(RendererErrorKind::InvalidState, "no browser history")
            })?;
            let next = index + 1;
            if next >= self.history.len() {
                return Err(RendererError::new(
                    RendererErrorKind::InvalidState,
                    "no forward history entry",
                ));
            }
            self.history_index = Some(next);
            let url = self.history[next].clone();
            self.url = Some(url.clone());
            Ok(HistoryNavigationResult {
                session_id: request.session_id,
                page_id: request.page_id,
                url,
            })
        }

        fn input_text(&mut self, request: TextInputRequest) -> Result<InputResult, RendererError> {
            self.operations.push("text_input");
            self.text_inputs.push(request.text);
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn press_key(&mut self, request: KeyPressRequest) -> Result<InputResult, RendererError> {
            self.operations.push("key_press");
            self.key_presses.push(request.key);
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn focus_selector(
            &mut self,
            request: FocusSelectorRequest,
        ) -> Result<InputResult, RendererError> {
            self.operations.push("focus_selector");
            self.focused_selectors.push(request.selector);
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn click_point(
            &mut self,
            request: ClickPointRequest,
        ) -> Result<InputResult, RendererError> {
            self.operations.push("click_point");
            self.clicked_points.push((request.x, request.y));
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn settle_after_interaction(&mut self) -> Result<InteractionSettleResult, RendererError> {
            self.operations.push("settle");
            let url = self.settled_url.clone().unwrap_or_else(|| {
                self.url
                    .clone()
                    .unwrap_or_else(|| "about:blank".to_string())
            });
            self.url = Some(url.clone());
            Ok(InteractionSettleResult::new(url))
        }

        fn shutdown(&mut self) -> Result<ShutdownResult, RendererError> {
            self.shutdown = true;
            Ok(ShutdownResult {})
        }
    }

    #[test]
    fn kitty_browse_escape_includes_placement_when_rows_are_provided() {
        let escape = kitty_browse_escape(
            "iVBORw0KGgo=".to_string(),
            Viewport::new(800, 600),
            80,
            Some(24),
        );

        assert!(escape.contains("a=T,i=1"));
        assert!(!escape.contains("a=t,i=1"));
        assert!(escape.contains("s=800,v=600"));
        assert!(escape.contains("p=1,c=80,r=24"));
        assert!(!escape.contains("a=p"));
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

    #[test]
    fn kitty_unicode_browse_escape_creates_quiet_virtual_placement() {
        let escape = kitty_unicode_browse_escape(
            "iVBORw0KGgo=".to_string(),
            Viewport::new(800, 600),
            80,
            Some(24),
        );

        assert!(escape.contains("a=T"));
        assert!(escape.contains("q=2"));
        assert!(escape.contains("U=1"));
        assert!(escape.contains("i=1,c=80,r=24"));
        assert!(escape.contains("s=800,v=600"));
    }

    #[test]
    fn serve_request_parses_navigate_and_resize_jsonl() {
        assert_eq!(
            parse_serve_request(r#"{"type":"navigate","id":1,"url":"https://example.com"}"#)
                .expect("navigate request should parse"),
            ServeRequest::Navigate {
                id: 1,
                url: "https://example.com".to_string(),
            }
        );

        assert_eq!(
            parse_serve_request(
                r#"{"type":"resize","id":2,"columns":80,"rows":24,"width":800,"height":480}"#
            )
            .expect("resize request should parse"),
            ServeRequest::Resize {
                id: 2,
                columns: 80,
                rows: 24,
                width: 800,
                height: 480,
            }
        );

        assert_eq!(
            parse_serve_request(r#"{"type":"back","id":9}"#).expect("back request should parse"),
            ServeRequest::Back { id: 9 }
        );

        assert_eq!(
            parse_serve_request(r#"{"type":"forward","id":10}"#)
                .expect("forward request should parse"),
            ServeRequest::Forward { id: 10 }
        );
    }

    #[test]
    fn serve_request_parses_text_input_and_key_press_jsonl() {
        assert_eq!(
            parse_serve_request(r#"{"type":"text_input","id":3,"text":"hello \"world\"\n"}"#)
                .expect("text input request should parse"),
            ServeRequest::TextInput {
                id: 3,
                text: "hello \"world\"\n".to_string(),
            }
        );

        assert_eq!(
            parse_serve_request(r#"{"type":"key_press","id":4,"key":"Enter"}"#)
                .expect("key press request should parse"),
            ServeRequest::KeyPress {
                id: 4,
                key: "Enter".to_string(),
            }
        );
    }

    #[test]
    fn serve_request_parses_focus_selector_and_click_point_jsonl() {
        assert_eq!(
            parse_serve_request(
                r##"{"type":"focus_selector","id":5,"selector":"input[name=\"q\"]"}"##
            )
            .expect("focus selector request should parse"),
            ServeRequest::FocusSelector {
                id: 5,
                selector: "input[name=\"q\"]".to_string(),
            }
        );

        assert_eq!(
            parse_serve_request(r##"{"type":"click_point","id":6,"x":120.5,"y":240.25}"##)
                .expect("click point request should parse"),
            ServeRequest::ClickPoint {
                id: 6,
                x: 120.5,
                y: 240.25,
            }
        );
    }

    #[test]
    fn serve_response_encodes_single_json_line() {
        let response = ServeResponse {
            id: 7,
            status: ServeStatus::Ok,
            payload: Some("frame".to_string()),
            url: None,
            error: None,
        };

        assert_eq!(
            encode_serve_response(&response),
            r#"{"id":7,"status":"ok","payload":"frame"}"#
        );
    }

    #[test]
    fn serve_response_encodes_current_url_when_present() {
        let response = ServeResponse {
            id: 8,
            status: ServeStatus::Ok,
            payload: Some("frame".to_string()),
            url: Some("https://example.com".to_string()),
            error: None,
        };

        assert_eq!(
            encode_serve_response(&response),
            r#"{"id":8,"status":"ok","payload":"frame","url":"https://example.com"}"#
        );
    }

    #[test]
    fn serve_runtime_navigates_and_returns_frame_payload() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
            },
        );

        let response = runtime.handle(ServeRequest::Navigate {
            id: 3,
            url: "https://example.com".to_string(),
        });

        assert_eq!(response.id, 3);
        assert_eq!(response.status, ServeStatus::Ok);
        assert_eq!(response.url, Some("https://example.com".to_string()));
        assert!(response.payload.expect("payload").contains("▀"));
    }

    #[test]
    fn serve_runtime_returns_final_url_after_navigation_redirect() {
        let mut renderer = FakeRenderer::new();
        renderer.final_navigation_url = Some("https://example.com/final".to_string());
        let mut runtime = ServeRuntime::new(
            renderer,
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
            },
        );

        let response = runtime.handle(ServeRequest::Navigate {
            id: 3,
            url: "https://example.com/redirect".to_string(),
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert_eq!(response.url, Some("https://example.com/final".to_string()));
        assert_eq!(
            runtime.session.active_page().url(),
            Some("https://example.com/final")
        );
    }

    #[test]
    fn serve_runtime_returns_final_url_after_reload_redirect() {
        let mut renderer = FakeRenderer::new();
        renderer.final_reload_url = Some("https://example.com/reloaded".to_string());
        let mut runtime = ServeRuntime::new(
            renderer,
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com/before".to_string(),
        });
        let response = runtime.handle(ServeRequest::Reload { id: 2 });

        assert_eq!(response.status, ServeStatus::Ok);
        assert_eq!(
            response.url,
            Some("https://example.com/reloaded".to_string())
        );
        assert_eq!(
            runtime.session.active_page().url(),
            Some("https://example.com/reloaded")
        );
        assert_eq!(
            runtime
                .session
                .active_page()
                .last_frame()
                .expect("frame")
                .url,
            "https://example.com/reloaded"
        );
    }

    #[test]
    fn serve_runtime_goes_back_and_forward_in_browser_history() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com/one".to_string(),
        });
        runtime.handle(ServeRequest::Navigate {
            id: 2,
            url: "https://example.com/two".to_string(),
        });

        let back = runtime.handle(ServeRequest::Back { id: 3 });

        assert_eq!(back.status, ServeStatus::Ok);
        assert_eq!(back.url, Some("https://example.com/one".to_string()));
        assert_eq!(
            runtime.session.active_page().url(),
            Some("https://example.com/one")
        );

        let forward = runtime.handle(ServeRequest::Forward { id: 4 });

        assert_eq!(forward.status, ServeStatus::Ok);
        assert_eq!(forward.url, Some("https://example.com/two".to_string()));
        assert_eq!(
            runtime.session.active_page().url(),
            Some("https://example.com/two")
        );
        assert_eq!(
            runtime.renderer.operations,
            vec!["capture", "capture", "back", "capture", "forward", "capture"]
        );
    }

    #[test]
    fn serve_runtime_reports_history_edge_without_replacing_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com/one".to_string(),
        });
        let frame_before = runtime
            .session
            .active_page()
            .last_frame()
            .expect("initial frame")
            .clone();
        let response = runtime.handle(ServeRequest::Back { id: 2 });

        assert_eq!(response.id, 2);
        assert_eq!(response.status, ServeStatus::Error);
        assert_eq!(response.payload, None);
        assert_eq!(response.url, Some("https://example.com/one".to_string()));
        assert!(response
            .error
            .expect("error")
            .contains("no back history entry"));
        assert_eq!(
            runtime.session.active_page().last_frame(),
            Some(&frame_before)
        );
    }

    #[test]
    fn serve_runtime_scrolls_before_capturing_next_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::Scroll {
            id: 2,
            delta_x: 0,
            delta_y: 100,
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_some());
        assert_eq!(runtime.renderer.scrolls, vec![(0, 100)]);
    }

    #[test]
    fn serve_runtime_applies_text_input_before_capturing_next_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::TextInput {
            id: 2,
            text: "hello".to_string(),
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_some());
        assert_eq!(runtime.renderer.text_inputs, vec!["hello"]);
        assert_eq!(runtime.renderer.captures, 2);
        assert_eq!(
            runtime.renderer.operations,
            vec!["capture", "text_input", "settle", "capture"]
        );
    }

    #[test]
    fn serve_runtime_applies_key_press_before_capturing_next_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::KeyPress {
            id: 2,
            key: "Enter".to_string(),
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_some());
        assert_eq!(runtime.renderer.key_presses, vec!["Enter"]);
        assert_eq!(runtime.renderer.captures, 2);
        assert_eq!(
            runtime.renderer.operations,
            vec!["capture", "key_press", "settle", "capture"]
        );
    }

    #[test]
    fn serve_runtime_focuses_selector_before_capturing_next_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::FocusSelector {
            id: 2,
            selector: "input[name=\"q\"]".to_string(),
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_some());
        assert_eq!(
            runtime.renderer.focused_selectors,
            vec!["input[name=\"q\"]"]
        );
        assert_eq!(runtime.renderer.captures, 2);
        assert_eq!(
            runtime.renderer.operations,
            vec!["capture", "focus_selector", "settle", "capture"]
        );
    }

    #[test]
    fn serve_runtime_clicks_point_before_capturing_next_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::ClickPoint {
            id: 2,
            x: 120.5,
            y: 240.25,
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_some());
        assert_eq!(runtime.renderer.clicked_points, vec![(120.5, 240.25)]);
        assert_eq!(runtime.renderer.captures, 2);
        assert_eq!(
            runtime.renderer.operations,
            vec!["capture", "click_point", "settle", "capture"]
        );
    }

    #[test]
    fn serve_runtime_syncs_session_url_after_interaction_settle() {
        let mut renderer = FakeRenderer::new();
        renderer.settled_url = Some("https://example.com/after-submit".to_string());
        let mut runtime = ServeRuntime::new(
            renderer,
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com/form".to_string(),
        });
        let response = runtime.handle(ServeRequest::KeyPress {
            id: 2,
            key: "Enter".to_string(),
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert_eq!(
            response.url,
            Some("https://example.com/after-submit".to_string())
        );
        assert_eq!(
            runtime.session.active_page().url(),
            Some("https://example.com/after-submit")
        );
        assert_eq!(
            runtime
                .session
                .active_page()
                .last_frame()
                .expect("frame")
                .url,
            "https://example.com/after-submit"
        );
    }

    fn tiny_png() -> Vec<u8> {
        const PNG: &str = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==";
        general_purpose::STANDARD
            .decode(PNG)
            .expect("embedded PNG should decode")
    }
}
