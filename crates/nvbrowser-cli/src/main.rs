use std::{
    fs,
    io::{self, BufRead, Cursor, Write},
    path::{Path, PathBuf},
};

use base64::{engine::general_purpose, Engine};
use clap::{Parser, Subcommand, ValueEnum};
use image::{imageops::FilterType, DynamicImage, GenericImageView, ImageFormat, Rgba};
use nvbrowser_core::{
    inspect_target, kitty_image_escape, kitty_tiled_image_delete_escape,
    render_markdown_document_with_base_url,
    renderer::chromium::{render_url_png, ChromiumOptions},
    BrowserSession, ChromiumRenderer, ClickHintRequest, ClickPointRequest, ElementHint,
    ElementHintsRequest, FindTextRequest, FocusHintRequest, FocusSelectorRequest, FocusedElement,
    FocusedElementRequest, FrameArtifact, HistoryNavigationRequest, HoverHintRequest,
    HoverPointRequest, KeyPressRequest, KittyImageDelete, KittyImageTransfer, NavigateRequest,
    PageMetrics, PageMetricsRequest, PageTextRequest, PageTextSnapshot, ReloadRequest,
    RenderFrameRequest, RenderedFrame, Renderer, RendererError, RendererErrorKind,
    RightClickHintRequest, RightClickPointRequest, ScrollRequest, SelectHintRequest,
    SelectionTextRequest, SessionId, TextInputRequest, ToggleHintRequest, UploadHintRequest,
    Viewport, WheelPointRequest, ZoomRequest,
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
        #[arg(long)]
        rows: Option<u32>,
        #[arg(long)]
        width: Option<u32>,
        #[arg(long)]
        height: Option<u32>,
        #[arg(long, value_enum, default_value_t = ImageFit::Original)]
        fit: ImageFit,
    },
    Browse {
        url: String,
        #[arg(long, default_value_t = 1024)]
        width: u32,
        #[arg(long, default_value_t = 768)]
        height: u32,
        #[arg(long)]
        cdp_ws_url: Option<String>,
        #[arg(long)]
        user_data_dir: Option<PathBuf>,
        #[arg(long, value_enum, default_value_t = ImageOutput::Kitty)]
        output: ImageOutput,
        #[arg(long, default_value_t = 100)]
        columns: u32,
        #[arg(long)]
        rows: Option<u32>,
    },
    Capture {
        url: String,
        #[arg(long, default_value_t = 1024)]
        width: u32,
        #[arg(long, default_value_t = 768)]
        height: u32,
        #[arg(long)]
        cdp_ws_url: Option<String>,
        #[arg(long)]
        user_data_dir: Option<PathBuf>,
        #[arg(long, default_value = "-")]
        output: PathBuf,
        #[arg(long)]
        metadata: Option<PathBuf>,
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
        #[arg(long)]
        markdown: Option<PathBuf>,
        #[arg(long)]
        cdp_ws_url: Option<String>,
        #[arg(long)]
        user_data_dir: Option<PathBuf>,
    },
    Doctor {
        #[arg(long)]
        json: bool,
        #[arg(long)]
        cdp_ws_url: Option<String>,
        #[arg(long)]
        user_data_dir: Option<PathBuf>,
    },
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, ValueEnum)]
#[serde(rename_all = "kebab-case")]
enum ImageOutput {
    Kitty,
    KittyUnicode,
    Ansi,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, ValueEnum)]
enum ImageFit {
    Contain,
    Original,
    Width,
    Height,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();

    match cli.command {
        Command::Inspect { target } => {
            println!("{}", inspect_target(&target).to_json());
        }
        Command::RenderMd { path } => {
            print!("{}", render_markdown_file(&path)?);
        }
        Command::ShowImage {
            path,
            output,
            columns,
            rows,
            width,
            height,
            fit,
        } => {
            let image = image::open(path)?;
            let bounds = ImageBounds {
                columns,
                rows,
                width_px: width,
                height_px: height,
            };
            let image = resize_image_for_fit(image, bounds, fit);
            match output {
                ImageOutput::Kitty => {
                    let mut png = Cursor::new(Vec::new());
                    image.write_to(&mut png, ImageFormat::Png)?;
                    let encoded = general_purpose::STANDARD.encode(png.into_inner());
                    if let Some(rows) = rows {
                        let (width_px, height_px) = image.dimensions();
                        print!(
                            "{}",
                            kitty_placed_image_escape(encoded, width_px, height_px, columns, rows)
                        );
                    } else {
                        print!("{}", kitty_image_escape(&encoded));
                    }
                }
                ImageOutput::KittyUnicode => {
                    return Err("kitty-unicode output is only supported by browse".into());
                }
                ImageOutput::Ansi => {
                    print!(
                        "{}",
                        image_to_ansi_halfblocks(&image, columns, rows.map(|rows| rows * 2))
                    );
                }
            }
        }
        Command::Browse {
            url,
            width,
            height,
            cdp_ws_url,
            user_data_dir,
            output,
            columns,
            rows,
        } => {
            let viewport = Viewport::new(width, height);
            let frame =
                render_url_png(&url, viewport, chromium_options(cdp_ws_url, user_data_dir))?;
            match output {
                ImageOutput::Kitty => {
                    print!("{}", frame_to_payload(frame, output, columns, rows)?);
                }
                ImageOutput::KittyUnicode => {
                    let FrameArtifact::Png(png) = frame.artifact else {
                        return Err("Chromium renderer returned a non-PNG artifact".into());
                    };
                    let encoded = general_purpose::STANDARD.encode(png);
                    print!(
                        "{}",
                        kitty_unicode_browse_escape(encoded, viewport, columns, rows)
                    );
                }
                ImageOutput::Ansi => {
                    let FrameArtifact::Png(png) = frame.artifact else {
                        return Err("Chromium renderer returned a non-PNG artifact".into());
                    };
                    let image = image::load_from_memory_with_format(&png, ImageFormat::Png)?;
                    print!("{}", image_to_ansi_halfblocks(&image, columns, None));
                }
            }
        }
        Command::Capture {
            url,
            width,
            height,
            cdp_ws_url,
            user_data_dir,
            output,
            metadata,
        } => {
            let viewport = Viewport::new(width, height);
            validate_capture_destinations(&output, metadata.as_deref())?;
            let frame =
                render_url_png(&url, viewport, chromium_options(cdp_ws_url, user_data_dir))?;
            let stdout = io::stdout();
            let mut writer = stdout.lock();
            write_capture_outputs(&frame, &output, metadata.as_deref(), &mut writer)?;
        }
        Command::Serve {
            output,
            columns,
            rows,
            width,
            height,
            url,
            markdown,
            cdp_ws_url,
            user_data_dir,
        } => {
            let (initial_url, markdown_preview) = match (url, markdown) {
                (Some(_), Some(_)) => {
                    return Err("serve accepts either --url or --markdown, not both".into());
                }
                (Some(url), None) => (Some(url), None),
                (None, Some(path)) => {
                    let preview = MarkdownPreviewFile::create(&path)?;
                    (Some(preview.url()), Some(preview))
                }
                (None, None) => (None, None),
            };
            let options = ServeOptions {
                output,
                columns,
                rows,
                viewport: Viewport::new(width, height),
                initial_url,
                markdown_preview,
                cdp_ws_url,
                user_data_dir,
            };
            serve_stdio(options)?;
        }
        Command::Doctor {
            json,
            cdp_ws_url,
            user_data_dir,
        } => {
            let report = DoctorReport {
                backend: chromium_options(cdp_ws_url, user_data_dir).backend_diagnostics(),
            };
            if json {
                println!("{}", serde_json::to_string(&report)?);
            } else {
                println!(
                    "backend: {} via {}",
                    report.backend.status, report.backend.source
                );
                if let Some(warning) = report.backend.warning {
                    println!("warning: {warning}");
                }
            }
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
    Zoom {
        id: u64,
        scale: f64,
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
        #[serde(default = "default_capture")]
        capture: bool,
    },
    KeyPress {
        id: u64,
        key: String,
        #[serde(default)]
        modifiers: Vec<String>,
        #[serde(default = "default_capture")]
        capture: bool,
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
    RightClickPoint {
        id: u64,
        x: f64,
        y: f64,
    },
    HoverPoint {
        id: u64,
        x: f64,
        y: f64,
    },
    WheelPoint {
        id: u64,
        x: f64,
        y: f64,
        delta_x: f64,
        delta_y: f64,
    },
    ClickHint {
        id: u64,
        hint_id: u32,
    },
    RightClickHint {
        id: u64,
        hint_id: u32,
    },
    FocusHint {
        id: u64,
        hint_id: u32,
    },
    HoverHint {
        id: u64,
        hint_id: u32,
    },
    SelectHint {
        id: u64,
        hint_id: u32,
        choice: String,
    },
    UploadHint {
        id: u64,
        hint_id: u32,
        paths: Vec<PathBuf>,
    },
    ToggleHint {
        id: u64,
        hint_id: u32,
    },
    SubmitFocused {
        id: u64,
    },
    TypePoint {
        id: u64,
        x: f64,
        y: f64,
        text: String,
        submit: bool,
    },
    TypeHint {
        id: u64,
        hint_id: u32,
        text: String,
        submit: bool,
    },
    FindText {
        id: u64,
        query: String,
        #[serde(default)]
        backwards: bool,
    },
    PageText {
        id: u64,
    },
    SelectionText {
        id: u64,
    },
    Screenshot {
        id: u64,
        path: PathBuf,
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

#[derive(Debug, Clone, PartialEq, Serialize)]
struct ServeResponse {
    id: u64,
    status: ServeStatus,
    #[serde(skip_serializing_if = "Option::is_none")]
    runtime: Option<ServeRuntimeInfo>,
    #[serde(skip_serializing_if = "Option::is_none")]
    payload: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    url: Option<String>,
    title: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    page: Option<PageMetrics>,
    #[serde(skip_serializing_if = "Option::is_none")]
    focused: Option<Option<FocusedElement>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    text: Option<PageTextSnapshot>,
    #[serde(skip_serializing_if = "Option::is_none")]
    selection: Option<String>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    hints: Vec<ElementHint>,
    #[serde(skip_serializing_if = "Option::is_none")]
    hint_error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    found: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    match_count: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
struct RuntimeCells {
    columns: u32,
    rows: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
struct RuntimeViewport {
    width: u32,
    height: u32,
    device_scale_factor: f32,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
struct ServeRuntimeInfo {
    protocol_version: u32,
    transport: &'static str,
    renderer: &'static str,
    output: ImageOutput,
    cells: RuntimeCells,
    viewport: RuntimeViewport,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
struct DoctorReport {
    backend: nvbrowser_core::ChromiumBackendDiagnostics,
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

fn default_capture() -> bool {
    true
}

fn canonicalize_upload_paths(paths: Vec<PathBuf>) -> Result<Vec<PathBuf>, RendererError> {
    if paths.is_empty() {
        return Err(RendererError::new(
            RendererErrorKind::InvalidState,
            "no upload paths were provided",
        ));
    }

    let mut canonical = Vec::with_capacity(paths.len());
    for path in paths {
        let resolved = fs::canonicalize(&path).map_err(|_| {
            RendererError::new(
                RendererErrorKind::InvalidState,
                format!("upload path does not exist: {}", path.display()),
            )
        })?;
        if !resolved.is_file() {
            return Err(RendererError::new(
                RendererErrorKind::InvalidState,
                format!("upload path is not a file: {}", path.display()),
            ));
        }
        canonical.push(resolved);
    }
    Ok(canonical)
}

fn encode_serve_response(response: &ServeResponse) -> String {
    serde_json::to_string(response).expect("serve responses should serialize")
}

fn write_capture_outputs<W: Write>(
    frame: &RenderedFrame,
    output: &Path,
    metadata: Option<&Path>,
    stdout: &mut W,
) -> Result<(), Box<dyn std::error::Error>> {
    validate_capture_destinations(output, metadata)?;

    let FrameArtifact::Png(png) = &frame.artifact else {
        return Err("Chromium renderer returned a non-PNG artifact".into());
    };

    if is_stdout_path(output) {
        stdout.write_all(png)?;
    } else {
        fs::write(output, png)?;
    }

    if let Some(metadata) = metadata {
        let json = serde_json::to_string_pretty(&frame.metadata)?;
        if is_stdout_path(metadata) {
            writeln!(stdout, "{json}")?;
        } else {
            fs::write(metadata, format!("{json}\n"))?;
        }
    }

    stdout.flush()?;
    Ok(())
}

fn validate_capture_destinations(
    output: &Path,
    metadata: Option<&Path>,
) -> Result<(), Box<dyn std::error::Error>> {
    if is_stdout_path(output) && metadata.is_some_and(is_stdout_path) {
        return Err("capture cannot write PNG and metadata to stdout simultaneously".into());
    }
    if let Some(metadata) = metadata {
        if !is_stdout_path(output) && !is_stdout_path(metadata) && output == metadata {
            return Err("capture cannot write PNG and metadata to the same file".into());
        }
    }
    Ok(())
}

fn is_stdout_path(path: &Path) -> bool {
    path == Path::new("-")
}

fn render_markdown_file(path: &Path) -> Result<String, Box<dyn std::error::Error>> {
    let markdown = fs::read_to_string(path)?;
    let base_href = markdown_base_directory(path).map(path_to_file_url);
    Ok(render_markdown_document_with_base_url(
        &markdown,
        base_href.as_deref(),
    ))
}

fn markdown_base_directory(path: &Path) -> Option<PathBuf> {
    let parent = path.parent()?;
    if parent.as_os_str().is_empty() {
        return std::env::current_dir().ok();
    }
    fs::canonicalize(parent)
        .ok()
        .or_else(|| Some(parent.to_path_buf()))
}

#[derive(Debug)]
struct MarkdownPreviewFile {
    file: tempfile::NamedTempFile,
}

impl MarkdownPreviewFile {
    fn create(path: &Path) -> Result<Self, Box<dyn std::error::Error>> {
        let html = render_markdown_file(path)?;
        let stem = path
            .file_stem()
            .and_then(|stem| stem.to_str())
            .unwrap_or("markdown");
        let mut file = tempfile::Builder::new()
            .prefix(&format!(
                "nvbrowser-{}-",
                percent_encode_path(stem).replace('/', "%2F")
            ))
            .suffix(".html")
            .tempfile()?;
        file.write_all(html.as_bytes())?;
        file.flush()?;
        Ok(Self { file })
    }

    fn path(&self) -> &Path {
        self.file.path()
    }

    fn url(&self) -> String {
        path_to_file_url(self.path())
    }
}

fn path_to_file_url(path: impl AsRef<std::path::Path>) -> String {
    let path = path.as_ref();
    let mut value = path.to_string_lossy().replace('\\', "/");
    if !value.starts_with('/') {
        value = format!("/{value}");
    }
    let encoded = percent_encode_path(&value);
    if encoded.ends_with('/') {
        format!("file://{encoded}")
    } else if path.is_dir() || path.extension().is_none() {
        format!("file://{encoded}/")
    } else {
        format!("file://{encoded}")
    }
}

fn percent_encode_path(path: &str) -> String {
    let mut encoded = String::new();
    for byte in path.bytes() {
        let keep = byte.is_ascii_alphanumeric() || matches!(byte, b'/' | b'-' | b'.' | b'_' | b'~');
        if keep {
            encoded.push(byte as char);
        } else {
            encoded.push_str(&format!("%{byte:02X}"));
        }
    }
    encoded
}

#[derive(Debug)]
struct ServeOptions {
    output: ImageOutput,
    columns: u32,
    rows: u32,
    viewport: Viewport,
    initial_url: Option<String>,
    markdown_preview: Option<MarkdownPreviewFile>,
    cdp_ws_url: Option<String>,
    user_data_dir: Option<PathBuf>,
}

struct ServeRuntime<R: Renderer> {
    renderer: R,
    session: BrowserSession,
    columns: u32,
    rows: u32,
    output: ImageOutput,
    _markdown_preview: Option<MarkdownPreviewFile>,
}

struct CapturePayload {
    payload: Option<String>,
    page: Option<PageMetrics>,
    focused: Option<Option<FocusedElement>>,
    text: Option<PageTextSnapshot>,
    selection: Option<String>,
    hints: Vec<ElementHint>,
    hint_error: Option<String>,
    found: Option<bool>,
    match_count: Option<u32>,
}

impl<R: Renderer> ServeRuntime<R> {
    fn new(renderer: R, options: ServeOptions) -> Self {
        Self {
            renderer,
            session: BrowserSession::new(SessionId::new(1), options.viewport),
            columns: options.columns,
            rows: options.rows,
            output: options.output,
            _markdown_preview: options.markdown_preview,
        }
    }

    fn handle(&mut self, request: ServeRequest) -> ServeResponse {
        let id = request.id();
        match self.try_handle(request) {
            Ok(capture) => {
                let (
                    payload,
                    page,
                    focused,
                    text,
                    selection,
                    hints,
                    hint_error,
                    found,
                    match_count,
                ) = capture
                    .map(|capture| {
                        (
                            capture.payload,
                            capture.page,
                            capture.focused,
                            capture.text,
                            capture.selection,
                            capture.hints,
                            capture.hint_error,
                            capture.found,
                            capture.match_count,
                        )
                    })
                    .unwrap_or((None, None, None, None, None, Vec::new(), None, None, None));
                ServeResponse {
                    id,
                    status: ServeStatus::Ok,
                    runtime: Some(self.runtime_info()),
                    payload,
                    url: self.session.active_page().url().map(str::to_string),
                    title: self.session.active_page().title().map(str::to_string),
                    page,
                    focused,
                    text,
                    selection,
                    hints,
                    hint_error,
                    found,
                    match_count,
                    error: None,
                }
            }
            Err(error) => ServeResponse {
                id,
                status: ServeStatus::Error,
                runtime: Some(self.runtime_info()),
                payload: None,
                url: self.session.active_page().url().map(str::to_string),
                title: self.session.active_page().title().map(str::to_string),
                page: None,
                focused: None,
                text: None,
                selection: None,
                hints: Vec::new(),
                hint_error: None,
                found: None,
                match_count: None,
                error: Some(error.to_string()),
            },
        }
    }

    fn runtime_info(&self) -> ServeRuntimeInfo {
        let viewport = self.session.active_page().viewport();
        ServeRuntimeInfo {
            protocol_version: 15,
            transport: "stdio-jsonl",
            renderer: "chromium-cdp",
            output: self.output,
            cells: RuntimeCells {
                columns: self.columns,
                rows: self.rows,
            },
            viewport: RuntimeViewport {
                width: viewport.width,
                height: viewport.height,
                device_scale_factor: viewport.device_scale_factor,
            },
        }
    }

    fn try_handle(
        &mut self,
        request: ServeRequest,
    ) -> Result<Option<CapturePayload>, Box<dyn std::error::Error>> {
        match request {
            ServeRequest::Navigate { url, .. } => {
                let navigation = self.renderer.navigate(NavigateRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    url,
                ))?;
                self.session
                    .navigate_active_page_with_title(navigation.url, navigation.title);
                self.session.finish_active_page_load();
                self.capture_payload(true).map(Some)
            }
            ServeRequest::Capture { .. } => self.capture_payload(true).map(Some),
            ServeRequest::Scroll {
                delta_x, delta_y, ..
            } => {
                self.renderer.scroll(ScrollRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    delta_x,
                    delta_y,
                ))?;
                self.capture_payload(true).map(Some)
            }
            ServeRequest::Zoom { scale, .. } => {
                self.renderer.zoom(ZoomRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    scale,
                ))?;
                self.capture_payload(true).map(Some)
            }
            ServeRequest::Reload { .. } => {
                let reload = self.renderer.reload(ReloadRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                ))?;
                self.session
                    .navigate_active_page_with_title(reload.url, reload.title);
                self.session.finish_active_page_load();
                self.capture_payload(true).map(Some)
            }
            ServeRequest::Back { .. } => {
                let navigation = self.renderer.go_back(HistoryNavigationRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                ))?;
                self.session
                    .navigate_active_page_with_title(navigation.url, navigation.title);
                self.session.finish_active_page_load();
                self.capture_payload(true).map(Some)
            }
            ServeRequest::Forward { .. } => {
                let navigation = self.renderer.go_forward(HistoryNavigationRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                ))?;
                self.session
                    .navigate_active_page_with_title(navigation.url, navigation.title);
                self.session.finish_active_page_load();
                self.capture_payload(true).map(Some)
            }
            ServeRequest::TextInput { text, capture, .. } => {
                self.renderer.input_text(TextInputRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    text,
                ))?;
                self.settle_after_interaction()?;
                if capture {
                    self.capture_payload(true).map(Some)
                } else {
                    self.interaction_metadata_payload(true).map(Some)
                }
            }
            ServeRequest::KeyPress {
                key,
                modifiers,
                capture,
                ..
            } => {
                let key = key_with_modifiers(key, modifiers);
                self.renderer.press_key(KeyPressRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    key,
                ))?;
                self.settle_after_interaction()?;
                if capture {
                    self.capture_payload(true).map(Some)
                } else {
                    self.interaction_metadata_payload(true).map(Some)
                }
            }
            ServeRequest::FocusSelector { selector, .. } => {
                self.renderer.focus_selector(FocusSelectorRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    selector,
                ))?;
                self.settle_after_interaction()?;
                self.capture_payload(true).map(Some)
            }
            ServeRequest::ClickPoint { x, y, .. } => {
                self.renderer.click_point(ClickPointRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    x,
                    y,
                ))?;
                self.settle_after_interaction()?;
                self.capture_payload(true).map(Some)
            }
            ServeRequest::RightClickPoint { x, y, .. } => {
                self.renderer
                    .right_click_point(RightClickPointRequest::new(
                        self.session.id(),
                        self.session.active_page_id(),
                        x,
                        y,
                    ))?;
                self.settle_after_interaction()?;
                self.capture_payload(true).map(Some)
            }
            ServeRequest::HoverPoint { x, y, .. } => {
                self.renderer.hover_point(HoverPointRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    x,
                    y,
                ))?;
                self.settle_after_interaction()?;
                self.capture_payload(false).map(Some)
            }
            ServeRequest::WheelPoint {
                x,
                y,
                delta_x,
                delta_y,
                ..
            } => {
                self.renderer.wheel_point(WheelPointRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    x,
                    y,
                    delta_x,
                    delta_y,
                ))?;
                self.settle_after_interaction()?;
                self.capture_payload(false).map(Some)
            }
            ServeRequest::ClickHint { hint_id, .. } => {
                self.renderer.click_hint(ClickHintRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    hint_id,
                ))?;
                self.settle_after_interaction()?;
                self.capture_payload(true).map(Some)
            }
            ServeRequest::RightClickHint { hint_id, .. } => {
                self.renderer.right_click_hint(RightClickHintRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    hint_id,
                ))?;
                self.settle_after_interaction()?;
                self.capture_payload(true).map(Some)
            }
            ServeRequest::FocusHint { hint_id, .. } => {
                self.renderer.focus_hint(FocusHintRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    hint_id,
                ))?;
                self.settle_after_interaction()?;
                self.capture_payload(true).map(Some)
            }
            ServeRequest::HoverHint { hint_id, .. } => {
                self.renderer.hover_hint(HoverHintRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    hint_id,
                ))?;
                self.settle_after_interaction()?;
                self.capture_payload(false).map(Some)
            }
            ServeRequest::SelectHint {
                hint_id, choice, ..
            } => {
                self.renderer.select_hint(SelectHintRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    hint_id,
                    choice,
                ))?;
                self.settle_after_interaction()?;
                self.capture_payload(true).map(Some)
            }
            ServeRequest::UploadHint { hint_id, paths, .. } => {
                let paths = canonicalize_upload_paths(paths)?;
                self.renderer.upload_hint(UploadHintRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    hint_id,
                    paths,
                ))?;
                self.settle_after_interaction()?;
                self.capture_payload(true).map(Some)
            }
            ServeRequest::ToggleHint { hint_id, .. } => {
                self.renderer.toggle_hint(ToggleHintRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    hint_id,
                ))?;
                self.settle_after_interaction()?;
                self.capture_payload(true).map(Some)
            }
            ServeRequest::SubmitFocused { .. } => {
                let focused = self
                    .renderer
                    .focused_element(FocusedElementRequest::new(
                        self.session.id(),
                        self.session.active_page_id(),
                    ))?
                    .ok_or_else(|| {
                        RendererError::new(
                            RendererErrorKind::InvalidState,
                            "no focused element to submit",
                        )
                    })?;
                if !focused.submittable {
                    return Err(RendererError::new(
                        RendererErrorKind::InvalidState,
                        "focused element is not submittable",
                    )
                    .into());
                }
                self.renderer.press_key(KeyPressRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    "Enter",
                ))?;
                self.settle_after_interaction()?;
                self.capture_payload(true).map(Some)
            }
            ServeRequest::TypePoint {
                x, y, text, submit, ..
            } => {
                self.renderer.click_point(ClickPointRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    x,
                    y,
                ))?;
                self.settle_after_interaction()?;
                self.renderer.input_text(TextInputRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    text,
                ))?;
                self.settle_after_interaction()?;
                if submit {
                    self.renderer.press_key(KeyPressRequest::new(
                        self.session.id(),
                        self.session.active_page_id(),
                        "Enter",
                    ))?;
                    self.settle_after_interaction()?;
                }
                self.capture_payload(true).map(Some)
            }
            ServeRequest::TypeHint {
                hint_id,
                text,
                submit,
                ..
            } => {
                self.renderer.focus_hint(FocusHintRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    hint_id,
                ))?;
                self.settle_after_interaction()?;
                self.renderer.input_text(TextInputRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                    text,
                ))?;
                self.settle_after_interaction()?;
                if submit {
                    self.renderer.press_key(KeyPressRequest::new(
                        self.session.id(),
                        self.session.active_page_id(),
                        "Enter",
                    ))?;
                    self.settle_after_interaction()?;
                }
                self.capture_payload(true).map(Some)
            }
            ServeRequest::FindText {
                query, backwards, ..
            } => {
                let result = self.renderer.find_text(
                    FindTextRequest::new(self.session.id(), self.session.active_page_id(), query)
                        .backwards(backwards),
                )?;
                let mut capture = self.capture_payload(false)?;
                capture.found = Some(result.found);
                capture.match_count = result.match_count;
                Ok(Some(capture))
            }
            ServeRequest::PageText { .. } => {
                let snapshot = self.renderer.page_text(PageTextRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                ))?;
                Ok(Some(CapturePayload {
                    payload: None,
                    page: None,
                    focused: None,
                    text: Some(snapshot),
                    selection: None,
                    hints: Vec::new(),
                    hint_error: None,
                    found: None,
                    match_count: None,
                }))
            }
            ServeRequest::SelectionText { .. } => {
                let selection = self.renderer.selection_text(SelectionTextRequest::new(
                    self.session.id(),
                    self.session.active_page_id(),
                ))?;
                Ok(Some(CapturePayload {
                    payload: None,
                    page: None,
                    focused: None,
                    text: None,
                    selection: Some(selection.text),
                    hints: Vec::new(),
                    hint_error: None,
                    found: None,
                    match_count: None,
                }))
            }
            ServeRequest::Screenshot { path, .. } => {
                self.write_screenshot(&path)?;
                Ok(Some(self.interaction_metadata_payload(true)?))
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
                self.capture_payload(false).map(Some)
            }
            ServeRequest::Quit { .. } => {
                self.renderer.shutdown()?;
                Ok(None)
            }
        }
    }

    fn capture_payload(
        &mut self,
        include_focused: bool,
    ) -> Result<CapturePayload, Box<dyn std::error::Error>> {
        let frame = self.renderer.render_frame(RenderFrameRequest::new(
            self.session.id(),
            self.session.active_page_id(),
            self.session.active_page().viewport(),
        ))?;
        self.session.set_active_page_frame(frame.metadata.clone());
        let (hints, hint_error) = match self.renderer.element_hints(ElementHintsRequest::new(
            self.session.id(),
            self.session.active_page_id(),
        )) {
            Ok(hints) => (hints, None),
            Err(error) => (Vec::new(), Some(error.message().to_string())),
        };
        let page = self.renderer.page_metrics(PageMetricsRequest::new(
            self.session.id(),
            self.session.active_page_id(),
        ))?;
        let focused = if include_focused {
            Some(
                self.renderer
                    .focused_element(FocusedElementRequest::new(
                        self.session.id(),
                        self.session.active_page_id(),
                    ))
                    .unwrap_or(None),
            )
        } else {
            None
        };
        let payload = frame_to_payload(frame, self.output, self.columns, Some(self.rows))?;
        Ok(CapturePayload {
            payload: Some(payload),
            page,
            focused,
            text: None,
            selection: None,
            hints,
            hint_error,
            found: None,
            match_count: None,
        })
    }

    fn interaction_metadata_payload(
        &mut self,
        include_focused: bool,
    ) -> Result<CapturePayload, Box<dyn std::error::Error>> {
        let page = self.renderer.page_metrics(PageMetricsRequest::new(
            self.session.id(),
            self.session.active_page_id(),
        ))?;
        let focused = if include_focused {
            Some(
                self.renderer
                    .focused_element(FocusedElementRequest::new(
                        self.session.id(),
                        self.session.active_page_id(),
                    ))
                    .unwrap_or(None),
            )
        } else {
            None
        };
        Ok(CapturePayload {
            payload: None,
            page,
            focused,
            text: None,
            selection: None,
            hints: Vec::new(),
            hint_error: None,
            found: None,
            match_count: None,
        })
    }

    fn write_screenshot(&mut self, path: &Path) -> Result<(), Box<dyn std::error::Error>> {
        if path.as_os_str().is_empty() {
            return Err("screenshot path is empty".into());
        }
        let frame = self.renderer.render_frame(RenderFrameRequest::new(
            self.session.id(),
            self.session.active_page_id(),
            self.session.active_page().viewport(),
        ))?;
        self.session.set_active_page_frame(frame.metadata.clone());
        let FrameArtifact::Png(png) = frame.artifact else {
            return Err("screenshot export requires a PNG frame".into());
        };
        fs::write(path, png)?;
        Ok(())
    }

    fn settle_after_interaction(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let settled = self.renderer.settle_after_interaction()?;
        self.session
            .navigate_active_page_with_title(settled.url, settled.title);
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
            | ServeRequest::Zoom { id, .. }
            | ServeRequest::Reload { id }
            | ServeRequest::Back { id }
            | ServeRequest::Forward { id }
            | ServeRequest::TextInput { id, .. }
            | ServeRequest::KeyPress { id, .. }
            | ServeRequest::FocusSelector { id, .. }
            | ServeRequest::ClickPoint { id, .. }
            | ServeRequest::RightClickPoint { id, .. }
            | ServeRequest::HoverPoint { id, .. }
            | ServeRequest::WheelPoint { id, .. }
            | ServeRequest::ClickHint { id, .. }
            | ServeRequest::RightClickHint { id, .. }
            | ServeRequest::FocusHint { id, .. }
            | ServeRequest::HoverHint { id, .. }
            | ServeRequest::SelectHint { id, .. }
            | ServeRequest::UploadHint { id, .. }
            | ServeRequest::ToggleHint { id, .. }
            | ServeRequest::SubmitFocused { id }
            | ServeRequest::TypePoint { id, .. }
            | ServeRequest::TypeHint { id, .. }
            | ServeRequest::FindText { id, .. }
            | ServeRequest::PageText { id }
            | ServeRequest::SelectionText { id }
            | ServeRequest::Screenshot { id, .. }
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
            if should_tile_kitty_frame(&png, viewport) {
                let rows = rows.unwrap_or_else(|| inferred_kitty_rows(viewport, columns));
                return kitty_tiled_browse_escape(&png, viewport, columns, rows, 40, 20);
            }
            let encoded = general_purpose::STANDARD.encode(png);
            Ok(format!(
                "{}{}",
                kitty_tile_cleanup_escape(),
                kitty_browse_escape(encoded, viewport, columns, rows)
            ))
        }
        ImageOutput::KittyUnicode => {
            let encoded = general_purpose::STANDARD.encode(png);
            Ok(kitty_unicode_browse_escape(
                encoded, viewport, columns, rows,
            ))
        }
        ImageOutput::Ansi => {
            let image = image::load_from_memory_with_format(&png, ImageFormat::Png)?;
            Ok(image_to_ansi_halfblocks(
                &image,
                columns,
                ansi_halfblock_target_height(rows),
            ))
        }
    }
}

fn ansi_halfblock_target_height(rows: Option<u32>) -> Option<u32> {
    rows.map(|rows| rows.saturating_mul(2).min(u32::MAX - 1))
}

fn should_tile_kitty_frame(png: &[u8], viewport: Viewport) -> bool {
    const LARGE_FRAME_BYTES: usize = 1024 * 1024;
    const LARGE_FRAME_PIXELS: u64 = 1024 * 1024;
    png.len() > LARGE_FRAME_BYTES
        || u64::from(viewport.width) * u64::from(viewport.height) > LARGE_FRAME_PIXELS
}

const MAX_KITTY_TILES: u32 = 256;

fn inferred_kitty_rows(viewport: Viewport, columns: u32) -> u32 {
    let columns = columns.max(1);
    let width = viewport.width.max(1);
    let height = viewport.height.max(1);
    ((u64::from(height) * u64::from(columns)).div_ceil(u64::from(width))) as u32
}

fn kitty_tile_cleanup_escape() -> String {
    format!(
        "{}{}",
        KittyImageDelete::new(1).escape(),
        kitty_tiled_image_delete_escape(2, MAX_KITTY_TILES)
    )
}

fn serve_stdio(options: ServeOptions) -> Result<(), Box<dyn std::error::Error>> {
    let initial_url = options.initial_url.clone();
    let mut runtime = ServeRuntime::new(
        ChromiumRenderer::launch(
            options.viewport,
            chromium_options(options.cdp_ws_url.clone(), options.user_data_dir.clone()),
        )?,
        options,
    );
    let stdout = io::stdout();
    let mut writer = stdout.lock();

    if let Some(url) = initial_url {
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
                        runtime: None,
                        payload: None,
                        url: None,
                        title: None,
                        page: None,
                        focused: None,
                        text: None,
                        selection: None,
                        hints: Vec::new(),
                        hint_error: None,
                        found: None,
                        match_count: None,
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

fn chromium_options(cdp_ws_url: Option<String>, user_data_dir: Option<PathBuf>) -> ChromiumOptions {
    let mut options = ChromiumOptions::detect();
    if let Some(cdp_ws_url) = cdp_ws_url.and_then(non_empty_cli_string) {
        options.cdp_ws_url = Some(cdp_ws_url);
    }
    if let Some(user_data_dir) = user_data_dir.and_then(non_empty_cli_path) {
        options.user_data_dir = Some(user_data_dir);
    }
    options
}

fn non_empty_cli_string(value: String) -> Option<String> {
    let value = value.trim().to_string();
    if value.is_empty() {
        None
    } else {
        Some(value)
    }
}

fn non_empty_cli_path(value: PathBuf) -> Option<PathBuf> {
    if value.as_os_str().is_empty() {
        None
    } else {
        Some(value)
    }
}

fn key_with_modifiers(key: String, modifiers: Vec<String>) -> String {
    let mut prefixes = Vec::new();
    for modifier in modifiers {
        match modifier.to_ascii_lowercase().as_str() {
            "alt" => prefixes.push("Alt"),
            "ctrl" | "control" => prefixes.push("Ctrl"),
            "meta" | "cmd" | "command" => prefixes.push("Meta"),
            "shift" => prefixes.push("Shift"),
            _ => {}
        }
    }
    if prefixes.is_empty() {
        key
    } else {
        format!("{}+{key}", prefixes.join("+"))
    }
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
    format!(
        "{}{}",
        KittyImageDelete::new(1).escape(),
        transfer.virtual_placement_escape(columns, rows.unwrap_or(1))
    )
}

fn kitty_tiled_browse_escape(
    png: &[u8],
    viewport: Viewport,
    columns: u32,
    rows: u32,
    tile_columns: u32,
    tile_rows: u32,
) -> Result<String, Box<dyn std::error::Error>> {
    let image = image::load_from_memory_with_format(png, ImageFormat::Png)?;
    let columns = columns.max(1);
    let rows = rows.max(1);
    let tile_columns = tile_columns.max(1);
    let tile_rows = tile_rows.max(1);
    let tile_count =
        u64::from(columns.div_ceil(tile_columns)) * u64::from(rows.div_ceil(tile_rows));
    if tile_count > u64::from(MAX_KITTY_TILES) {
        return Err(format!("Kitty tile count {tile_count} exceeds max {MAX_KITTY_TILES}").into());
    }

    let mut output = kitty_tile_cleanup_escape();

    let mut tile_index = 0;
    for row in (0..rows).step_by(tile_rows as usize) {
        let cell_rows = (rows - row).min(tile_rows);
        let y = cell_to_pixel(row, rows, viewport.height);
        let bottom = cell_to_pixel(row + cell_rows, rows, viewport.height);
        for column in (0..columns).step_by(tile_columns as usize) {
            let cell_columns = (columns - column).min(tile_columns);
            let x = cell_to_pixel(column, columns, viewport.width);
            let right = cell_to_pixel(column + cell_columns, columns, viewport.width);
            let tile_width = (right - x).max(1);
            let tile_height = (bottom - y).max(1);
            let tile = image.crop_imm(x, y, tile_width, tile_height);
            let mut tile_png = Cursor::new(Vec::new());
            tile.write_to(&mut tile_png, ImageFormat::Png)?;
            let encoded = general_purpose::STANDARD.encode(tile_png.into_inner());
            let transfer =
                KittyImageTransfer::new(2 + tile_index, tile_width, tile_height, encoded);
            output.push_str(&relative_cursor_move_escape(column, row));
            output.push_str(&transfer.tile_escape(1 + tile_index, cell_columns, cell_rows));
            output.push_str(&relative_cursor_restore_escape(column, row));
            tile_index += 1;
        }
    }

    Ok(output)
}

fn cell_to_pixel(cell: u32, cells: u32, pixels: u32) -> u32 {
    ((cell as u64 * pixels as u64) / cells.max(1) as u64) as u32
}

fn relative_cursor_move_escape(columns: u32, rows: u32) -> String {
    let mut escape = String::new();
    if rows > 0 {
        escape.push_str(&format!("\x1b[{rows}B"));
    }
    if columns > 0 {
        escape.push_str(&format!("\x1b[{columns}C"));
    }
    escape
}

fn relative_cursor_restore_escape(columns: u32, rows: u32) -> String {
    let mut escape = String::new();
    if columns > 0 {
        escape.push_str(&format!("\x1b[{columns}D"));
    }
    if rows > 0 {
        escape.push_str(&format!("\x1b[{rows}A"));
    }
    escape
}

fn kitty_placed_image_escape(
    encoded_png: String,
    width_px: u32,
    height_px: u32,
    columns: u32,
    rows: u32,
) -> String {
    let control = format!(
        "a=T,i=1,p=1,c={},r={},f=100,s={},v={}",
        columns.max(1),
        rows.max(1),
        width_px,
        height_px
    );
    chunked_kitty_escape(&control, &encoded_png)
}

fn chunked_kitty_escape(control: &str, payload: &str) -> String {
    const CHUNK_SIZE: usize = 4096;
    if payload.len() <= CHUNK_SIZE {
        return format!("\x1b_G{control},m=0;{payload}\x1b\\");
    }

    let mut escape = String::new();
    let mut offset = 0;
    while offset < payload.len() {
        let end = (offset + CHUNK_SIZE).min(payload.len());
        let chunk = &payload[offset..end];
        let more = if end < payload.len() { 1 } else { 0 };
        if offset == 0 {
            escape.push_str(&format!("\x1b_G{control},m={more};{chunk}\x1b\\"));
        } else {
            escape.push_str(&format!("\x1b_Gm={more};{chunk}\x1b\\"));
        }
        offset = end;
    }

    escape
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct ImageBounds {
    columns: u32,
    rows: Option<u32>,
    width_px: Option<u32>,
    height_px: Option<u32>,
}

fn resize_image_for_fit(image: DynamicImage, bounds: ImageBounds, fit: ImageFit) -> DynamicImage {
    let size = fitted_image_size(image.dimensions(), bounds, fit);
    if image.dimensions() == size {
        return image;
    }
    image.resize_exact(size.0, size.1, FilterType::Triangle)
}

fn fitted_image_size(source: (u32, u32), bounds: ImageBounds, fit: ImageFit) -> (u32, u32) {
    let (source_width, source_height) = (source.0.max(1), source.1.max(1));
    let bounds_width = bounds
        .width_px
        .unwrap_or_else(|| bounds.columns.max(1) * 10);
    let bounds_height = bounds
        .height_px
        .or_else(|| bounds.rows.map(|rows| rows.max(1) * 20))
        .unwrap_or(source_height);

    match fit {
        ImageFit::Original => (source_width, source_height),
        ImageFit::Width => scale_to_width(source, bounds_width),
        ImageFit::Height => scale_to_height(source, bounds_height),
        ImageFit::Contain => {
            let width_fit = scale_to_width(source, bounds_width);
            if width_fit.1 <= bounds_height {
                width_fit
            } else {
                scale_to_height(source, bounds_height)
            }
        }
    }
}

fn scale_to_width(source: (u32, u32), target_width: u32) -> (u32, u32) {
    let (source_width, source_height) = (source.0.max(1), source.1.max(1));
    let width = target_width.max(1);
    let height = ((source_height as f64 * width as f64) / source_width as f64)
        .round()
        .max(1.0) as u32;
    (width, height)
}

fn scale_to_height(source: (u32, u32), target_height: u32) -> (u32, u32) {
    let (source_width, source_height) = (source.0.max(1), source.1.max(1));
    let height = target_height.max(1);
    let width = ((source_width as f64 * height as f64) / source_height as f64)
        .round()
        .max(1.0) as u32;
    (width, height)
}

fn image_to_ansi_halfblocks(
    image: &DynamicImage,
    columns: u32,
    target_height: Option<u32>,
) -> String {
    if target_height == Some(0) {
        return String::new();
    }

    let columns = columns.max(1);
    let (width, height) = image.dimensions();
    let aspect = height as f32 / width.max(1) as f32;
    let mut target_height =
        target_height.unwrap_or_else(|| (aspect * columns as f32).round().max(2.0) as u32);
    target_height = target_height.max(2);
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
        ElementHintKind, ElementHintsRequest, FocusedElementRequest, FrameId, FrameMetadata,
        HistoryNavigationResult, InputResult, InteractionSettleResult, NavigationResult, PageId,
        PageMetricsRequest, PageTextRequest, ReloadResult, RendererError, RendererErrorKind,
        ScrollResult, SelectHintRequest, SelectOptionHint, SelectionTextRequest,
        SelectionTextResult, ShutdownResult, ToggleHintRequest, UploadHintRequest,
        WheelPointRequest, ZoomResult,
    };

    struct FakeRenderer {
        url: Option<String>,
        captures: u64,
        scrolls: Vec<(i32, i32)>,
        zooms: Vec<f64>,
        text_inputs: Vec<String>,
        key_presses: Vec<String>,
        focused_selectors: Vec<String>,
        focused_hints: Vec<u32>,
        clicked_hints: Vec<u32>,
        right_clicked_hints: Vec<u32>,
        hovered_hints: Vec<u32>,
        selected_hints: Vec<(u32, String)>,
        uploaded_hints: Vec<(u32, Vec<PathBuf>)>,
        toggled_hints: Vec<u32>,
        clicked_points: Vec<(f64, f64)>,
        right_clicked_points: Vec<(f64, f64)>,
        hovered_points: Vec<(f64, f64)>,
        wheeled_points: Vec<(f64, f64, f64, f64)>,
        find_queries: Vec<String>,
        find_directions: Vec<bool>,
        fail_click: bool,
        fail_click_hint: bool,
        fail_right_click_hint: bool,
        fail_hover_hint: bool,
        fail_select_hint: bool,
        fail_upload_hint: bool,
        fail_toggle_hint: bool,
        fail_hints: bool,
        fail_focus_hint: bool,
        fail_focused_element: bool,
        operations: Vec<&'static str>,
        history: Vec<String>,
        history_index: Option<usize>,
        settled_url: Option<String>,
        final_navigation_url: Option<String>,
        final_reload_url: Option<String>,
        next_frame_url: Option<String>,
        next_frame_title: Option<String>,
        hints: Vec<ElementHint>,
        focused: Option<FocusedElement>,
        shutdown: bool,
    }

    impl FakeRenderer {
        fn new() -> Self {
            Self {
                url: None,
                captures: 0,
                scrolls: Vec::new(),
                zooms: Vec::new(),
                text_inputs: Vec::new(),
                key_presses: Vec::new(),
                focused_selectors: Vec::new(),
                focused_hints: Vec::new(),
                clicked_hints: Vec::new(),
                right_clicked_hints: Vec::new(),
                hovered_hints: Vec::new(),
                selected_hints: Vec::new(),
                uploaded_hints: Vec::new(),
                toggled_hints: Vec::new(),
                clicked_points: Vec::new(),
                right_clicked_points: Vec::new(),
                hovered_points: Vec::new(),
                wheeled_points: Vec::new(),
                find_queries: Vec::new(),
                find_directions: Vec::new(),
                fail_click: false,
                fail_click_hint: false,
                fail_right_click_hint: false,
                fail_hover_hint: false,
                fail_select_hint: false,
                fail_upload_hint: false,
                fail_toggle_hint: false,
                fail_hints: false,
                fail_focus_hint: false,
                fail_focused_element: false,
                operations: Vec::new(),
                history: Vec::new(),
                history_index: None,
                settled_url: None,
                final_navigation_url: None,
                final_reload_url: None,
                next_frame_url: None,
                next_frame_title: None,
                hints: Vec::new(),
                focused: None,
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
                title: Some(url.clone()),
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
            let frame_url = self.next_frame_url.clone().unwrap_or(url.clone());
            let title = self
                .next_frame_title
                .clone()
                .or_else(|| Some(frame_url.clone()));
            Ok(RenderedFrame {
                metadata: FrameMetadata::new(
                    FrameId::new(self.captures),
                    request.session_id,
                    request.page_id,
                    frame_url,
                    title,
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

        fn zoom(&mut self, request: ZoomRequest) -> Result<ZoomResult, RendererError> {
            self.zooms.push(request.scale);
            Ok(ZoomResult {
                session_id: request.session_id,
                page_id: request.page_id,
                scale: request.scale,
            })
        }

        fn page_metrics(
            &mut self,
            _request: PageMetricsRequest,
        ) -> Result<Option<PageMetrics>, RendererError> {
            Ok(Some(PageMetrics {
                scroll_x: 0.0,
                scroll_y: 100.0,
                viewport_width: 10.0,
                viewport_height: 10.0,
                document_width: 10.0,
                document_height: 30.0,
            }))
        }

        fn focused_element(
            &mut self,
            _request: FocusedElementRequest,
        ) -> Result<Option<FocusedElement>, RendererError> {
            if self.fail_focused_element {
                self.operations.push("focused_element");
                return Err(RendererError::new(
                    RendererErrorKind::InvalidState,
                    "focused element extraction failed",
                ));
            }
            if self.focused.is_some() {
                self.operations.push("focused_element");
            }
            Ok(self.focused.clone())
        }

        fn page_text(
            &mut self,
            request: PageTextRequest,
        ) -> Result<PageTextSnapshot, RendererError> {
            self.operations.push("page_text");
            Ok(PageTextSnapshot {
                session_id: request.session_id,
                page_id: request.page_id,
                url: self
                    .url
                    .clone()
                    .unwrap_or_else(|| "https://example.com".to_string()),
                title: Some("Example".to_string()),
                text: "# Example\n\nExample body".to_string(),
                truncated: false,
            })
        }

        fn selection_text(
            &mut self,
            request: SelectionTextRequest,
        ) -> Result<SelectionTextResult, RendererError> {
            self.operations.push("selection_text");
            Ok(SelectionTextResult {
                session_id: request.session_id,
                page_id: request.page_id,
                text: "selected text".to_string(),
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
                title: Some(url.clone()),
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
                title: Some(url.clone()),
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
                title: Some(url.clone()),
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

        fn focus_hint(&mut self, request: FocusHintRequest) -> Result<InputResult, RendererError> {
            self.operations.push("focus_hint");
            self.focused_hints.push(request.hint_id);
            if self.fail_focus_hint {
                return Err(RendererError::new(
                    RendererErrorKind::InvalidState,
                    "hint focus failed",
                ));
            }
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn click_hint(&mut self, request: ClickHintRequest) -> Result<InputResult, RendererError> {
            self.operations.push("click_hint");
            self.clicked_hints.push(request.hint_id);
            if self.fail_click_hint {
                return Err(RendererError::new(
                    RendererErrorKind::InvalidState,
                    "hint click failed",
                ));
            }
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn right_click_hint(
            &mut self,
            request: RightClickHintRequest,
        ) -> Result<InputResult, RendererError> {
            self.operations.push("right_click_hint");
            self.right_clicked_hints.push(request.hint_id);
            if self.fail_right_click_hint {
                return Err(RendererError::new(
                    RendererErrorKind::InvalidState,
                    "hint right click failed",
                ));
            }
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn hover_hint(&mut self, request: HoverHintRequest) -> Result<InputResult, RendererError> {
            self.operations.push("hover_hint");
            self.hovered_hints.push(request.hint_id);
            if self.fail_hover_hint {
                return Err(RendererError::new(
                    RendererErrorKind::InvalidState,
                    "hint hover failed",
                ));
            }
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn select_hint(
            &mut self,
            request: SelectHintRequest,
        ) -> Result<InputResult, RendererError> {
            self.operations.push("select_hint");
            self.selected_hints.push((request.hint_id, request.choice));
            if self.fail_select_hint {
                return Err(RendererError::new(
                    RendererErrorKind::InvalidState,
                    "hint select failed",
                ));
            }
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn upload_hint(
            &mut self,
            request: UploadHintRequest,
        ) -> Result<InputResult, RendererError> {
            self.operations.push("upload_hint");
            self.uploaded_hints.push((request.hint_id, request.paths));
            if self.fail_upload_hint {
                return Err(RendererError::new(
                    RendererErrorKind::InvalidState,
                    "hint file upload failed",
                ));
            }
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn toggle_hint(
            &mut self,
            request: ToggleHintRequest,
        ) -> Result<InputResult, RendererError> {
            self.operations.push("toggle_hint");
            self.toggled_hints.push(request.hint_id);
            if self.fail_toggle_hint {
                return Err(RendererError::new(
                    RendererErrorKind::InvalidState,
                    "hint toggle failed",
                ));
            }
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
            if self.fail_click {
                return Err(RendererError::new(
                    RendererErrorKind::InvalidState,
                    "click failed",
                ));
            }
            self.clicked_points.push((request.x, request.y));
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn right_click_point(
            &mut self,
            request: RightClickPointRequest,
        ) -> Result<InputResult, RendererError> {
            self.operations.push("right_click_point");
            self.right_clicked_points.push((request.x, request.y));
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn hover_point(
            &mut self,
            request: HoverPointRequest,
        ) -> Result<InputResult, RendererError> {
            self.operations.push("hover_point");
            self.hovered_points.push((request.x, request.y));
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn wheel_point(
            &mut self,
            request: WheelPointRequest,
        ) -> Result<InputResult, RendererError> {
            self.operations.push("wheel_point");
            self.wheeled_points
                .push((request.x, request.y, request.delta_x, request.delta_y));
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn find_text(
            &mut self,
            request: FindTextRequest,
        ) -> Result<nvbrowser_core::FindTextResult, RendererError> {
            self.operations.push("find_text");
            self.find_queries.push(request.query.clone());
            self.find_directions.push(request.backwards);
            Ok(nvbrowser_core::FindTextResult {
                session_id: request.session_id,
                page_id: request.page_id,
                query: request.query,
                backwards: request.backwards,
                found: true,
                match_count: Some(3),
            })
        }

        fn element_hints(
            &mut self,
            _request: ElementHintsRequest,
        ) -> Result<Vec<ElementHint>, RendererError> {
            self.operations.push("hints");
            if self.fail_hints {
                return Err(RendererError::new(
                    RendererErrorKind::InvalidState,
                    "hint extraction failed",
                ));
            }
            Ok(self.hints.clone())
        }

        fn settle_after_interaction(&mut self) -> Result<InteractionSettleResult, RendererError> {
            self.operations.push("settle");
            let url = self.settled_url.clone().unwrap_or_else(|| {
                self.url
                    .clone()
                    .unwrap_or_else(|| "about:blank".to_string())
            });
            self.url = Some(url.clone());
            Ok(InteractionSettleResult::new(url.clone(), Some(url)))
        }

        fn shutdown(&mut self) -> Result<ShutdownResult, RendererError> {
            self.shutdown = true;
            Ok(ShutdownResult {})
        }
    }

    #[test]
    fn chromium_options_with_cli_cdp_ws_url_sets_attach_endpoint() {
        let options = chromium_options(
            Some("ws://127.0.0.1:9222/devtools/browser/test".to_string()),
            Some(PathBuf::from("/tmp/nvbrowser-profile")),
        );

        assert_eq!(
            options.cdp_ws_url.as_deref(),
            Some("ws://127.0.0.1:9222/devtools/browser/test")
        );
        assert_eq!(
            options.user_data_dir,
            Some(PathBuf::from("/tmp/nvbrowser-profile"))
        );
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

        assert!(escape.starts_with("\x1b_Ga=d,d=i,i=1\x1b\\"));
        assert!(escape.contains("a=T"));
        assert!(escape.contains("q=2"));
        assert!(escape.contains("U=1"));
        assert!(escape.contains("i=1,c=80,r=24"));
        assert!(escape.contains("s=800,v=600"));
    }

    #[test]
    fn image_fit_size_calculates_contain_original_width_and_height() {
        let bounds = ImageBounds {
            columns: 40,
            rows: Some(10),
            width_px: Some(400),
            height_px: Some(200),
        };

        assert_eq!(
            fitted_image_size((800, 600), bounds, ImageFit::Contain),
            (267, 200)
        );
        assert_eq!(
            fitted_image_size((800, 600), bounds, ImageFit::Original),
            (800, 600)
        );
        assert_eq!(
            fitted_image_size((800, 600), bounds, ImageFit::Width),
            (400, 300)
        );
        assert_eq!(
            fitted_image_size((800, 600), bounds, ImageFit::Height),
            (267, 200)
        );
    }

    #[test]
    fn kitty_placed_image_escape_chunks_large_payloads() {
        let escape = kitty_placed_image_escape("a".repeat(4097), 800, 600, 80, 24);

        assert!(escape.starts_with("\x1b_Ga=T,i=1,p=1,c=80,r=24,f=100,s=800,v=600,m=1;"));
        assert!(escape.contains(&format!("{}{}", "a".repeat(4096), "\x1b\\\x1b_Gm=0;a")));
    }

    #[test]
    fn kitty_tiled_browse_escape_splits_frame_into_stable_tiles() {
        let png = test_png(10, 5);
        let escape = kitty_tiled_browse_escape(&png, Viewport::new(10, 5), 5, 3, 2, 2)
            .expect("tiled kitty payload should be created");

        assert!(escape.starts_with("\x1b_Ga=d,d=i,i=1\x1b\\"));
        assert!(escape.contains("\x1b_Ga=d,d=i,i=257\x1b\\"));
        assert!(escape.contains("\x1b_Ga=d,d=i,i=7\x1b\\"));
        assert!(escape.contains("a=T,C=1,i=2,p=1,c=2,r=2,f=100,s=4,v=3"));
        assert!(escape.contains("\x1b[2C\x1b_Ga=T,C=1,i=3,p=2,c=2,r=2,f=100,s=4,v=3"));
        assert!(escape.contains("\x1b[2D"));
        assert!(escape.contains("a=T,C=1,i=7,p=6,c=1,r=1,f=100,s=2,v=2"));
        assert!(escape.contains("\x1b[2B\x1b[4C\x1b_Ga=T,C=1,i=7,p=6,c=1,r=1,f=100,s=2,v=2"));
        assert!(escape.contains("\x1b[4D\x1b[2A"));
        assert_eq!(escape.matches("a=T,C=1").count(), 6);
    }

    #[test]
    fn kitty_tiled_browse_escape_rejects_more_than_stable_tile_range() {
        let png = test_png(17, 17);
        let err = kitty_tiled_browse_escape(&png, Viewport::new(17, 17), 17, 17, 1, 1)
            .expect_err("too many tiles should be rejected");

        assert!(err.to_string().contains("exceeds max 256"));
    }

    #[test]
    fn kitty_tiled_browse_escape_rejects_tile_count_before_u32_overflow() {
        let png = tiny_png();
        let err = kitty_tiled_browse_escape(&png, Viewport::new(1, 1), u32::MAX, u32::MAX, 1, 1)
            .expect_err("overflow-sized tile grids should be rejected");

        assert!(err.to_string().contains("exceeds max 256"));
    }

    #[test]
    fn ansi_halfblocks_can_use_fitted_height() {
        let image = DynamicImage::new_rgba8(20, 200);
        let output = image_to_ansi_halfblocks(&image, 4, Some(4));

        assert_eq!(output.lines().count(), 2);
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

        assert_eq!(
            parse_serve_request(r#"{"type":"zoom","id":11,"scale":1.25}"#)
                .expect("zoom request should parse"),
            ServeRequest::Zoom {
                id: 11,
                scale: 1.25
            }
        );
    }

    #[test]
    fn markdown_preview_file_uses_parent_directory_as_base_url() {
        let directory = tempfile::tempdir().expect("tempdir should be created");
        let markdown_path = directory.path().join("README.md");
        std::fs::write(&markdown_path, "![Logo](images/logo.png)")
            .expect("markdown fixture should be written");

        let preview =
            MarkdownPreviewFile::create(&markdown_path).expect("markdown preview should render");
        let first_path = preview.path().to_path_buf();
        let second_preview =
            MarkdownPreviewFile::create(&markdown_path).expect("second preview should render");
        let url = preview.url();
        let html =
            std::fs::read_to_string(preview.path()).expect("preview html should be readable");

        assert!(url.starts_with("file://"));
        assert!(url.ends_with(".html/") || url.ends_with(".html"));
        assert_ne!(first_path, second_preview.path());
        assert!(html.contains("<base href=\"file://"));
        assert!(html.contains(directory.path().to_string_lossy().as_ref()));
        assert!(html.contains("images/logo.png"));
        drop(preview);
        assert!(
            !first_path.exists(),
            "preview file should be cleaned up when its owner is dropped"
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
                capture: true,
            }
        );
        assert_eq!(
            parse_serve_request(r#"{"type":"text_input","id":3,"text":"hi","capture":false}"#)
                .expect("quiet text input request should parse"),
            ServeRequest::TextInput {
                id: 3,
                text: "hi".to_string(),
                capture: false,
            }
        );

        assert_eq!(
            parse_serve_request(r#"{"type":"key_press","id":4,"key":"Enter"}"#)
                .expect("key press request should parse"),
            ServeRequest::KeyPress {
                id: 4,
                key: "Enter".to_string(),
                modifiers: Vec::new(),
                capture: true,
            }
        );
        assert_eq!(
            parse_serve_request(
                r#"{"type":"key_press","id":4,"key":"Tab","modifiers":["shift"],"capture":false}"#
            )
            .expect("modified key press request should parse"),
            ServeRequest::KeyPress {
                id: 4,
                key: "Tab".to_string(),
                modifiers: vec!["shift".to_string()],
                capture: false,
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
        assert_eq!(
            parse_serve_request(r##"{"type":"right_click_point","id":16,"x":120.5,"y":240.25}"##)
                .expect("right click point request should parse"),
            ServeRequest::RightClickPoint {
                id: 16,
                x: 120.5,
                y: 240.25,
            }
        );

        assert_eq!(
            parse_serve_request(r##"{"type":"hover_point","id":7,"x":120.5,"y":240.25}"##)
                .expect("hover point request should parse"),
            ServeRequest::HoverPoint {
                id: 7,
                x: 120.5,
                y: 240.25,
            }
        );
        assert_eq!(
            parse_serve_request(
                r##"{"type":"wheel_point","id":8,"x":120.5,"y":240.25,"delta_x":0,"delta_y":120}"##
            )
            .expect("wheel point request should parse"),
            ServeRequest::WheelPoint {
                id: 8,
                x: 120.5,
                y: 240.25,
                delta_x: 0.0,
                delta_y: 120.0,
            }
        );
        assert_eq!(
            parse_serve_request(r##"{"type":"click_hint","id":9,"hint_id":2}"##)
                .expect("click hint request should parse"),
            ServeRequest::ClickHint { id: 9, hint_id: 2 }
        );
        assert_eq!(
            parse_serve_request(r##"{"type":"right_click_hint","id":17,"hint_id":2}"##)
                .expect("right click hint request should parse"),
            ServeRequest::RightClickHint { id: 17, hint_id: 2 }
        );
        assert_eq!(
            parse_serve_request(r##"{"type":"hover_hint","id":10,"hint_id":3}"##)
                .expect("hover hint request should parse"),
            ServeRequest::HoverHint { id: 10, hint_id: 3 }
        );
        assert_eq!(
            parse_serve_request(r##"{"type":"focus_hint","id":13,"hint_id":5}"##)
                .expect("focus hint request should parse"),
            ServeRequest::FocusHint { id: 13, hint_id: 5 }
        );
        assert_eq!(
            parse_serve_request(
                r##"{"type":"select_hint","id":11,"hint_id":4,"choice":"Canada"}"##
            )
            .expect("select hint request should parse"),
            ServeRequest::SelectHint {
                id: 11,
                hint_id: 4,
                choice: "Canada".to_string(),
            }
        );
        assert_eq!(
            parse_serve_request(r##"{"type":"toggle_hint","id":12,"hint_id":7}"##)
                .expect("toggle hint request should parse"),
            ServeRequest::ToggleHint { id: 12, hint_id: 7 }
        );
        assert_eq!(
            parse_serve_request(
                r##"{"type":"upload_hint","id":15,"hint_id":8,"paths":["/tmp/example.txt","/tmp/file with spaces.txt"]}"##
            )
            .expect("upload hint request should parse"),
            ServeRequest::UploadHint {
                id: 15,
                hint_id: 8,
                paths: vec![
                    PathBuf::from("/tmp/example.txt"),
                    PathBuf::from("/tmp/file with spaces.txt"),
                ],
            }
        );
        assert_eq!(
            parse_serve_request(r##"{"type":"submit_focused","id":14}"##)
                .expect("submit focused request should parse"),
            ServeRequest::SubmitFocused { id: 14 }
        );
    }

    #[test]
    fn serve_request_parses_type_point_jsonl() {
        assert_eq!(
            parse_serve_request(
                r##"{"type":"type_point","id":7,"x":120.5,"y":240.25,"text":"hello \"world\"","submit":true}"##
            )
            .expect("type point request should parse"),
            ServeRequest::TypePoint {
                id: 7,
                x: 120.5,
                y: 240.25,
                text: "hello \"world\"".to_string(),
                submit: true,
            }
        );
        assert_eq!(
            parse_serve_request(
                r##"{"type":"type_hint","id":8,"hint_id":2,"text":"hello \"world\"","submit":true}"##
            )
            .expect("type hint request should parse"),
            ServeRequest::TypeHint {
                id: 8,
                hint_id: 2,
                text: "hello \"world\"".to_string(),
                submit: true,
            }
        );
    }

    #[test]
    fn serve_request_parses_find_text_jsonl() {
        assert_eq!(
            parse_serve_request(r#"{"type":"find_text","id":11,"query":"hello \"world\""}"#)
                .expect("find text request should parse"),
            ServeRequest::FindText {
                id: 11,
                query: "hello \"world\"".to_string(),
                backwards: false,
            }
        );
        assert_eq!(
            parse_serve_request(
                r#"{"type":"find_text","id":12,"query":"hello \"world\"","backwards":true}"#
            )
            .expect("backwards find text request should parse"),
            ServeRequest::FindText {
                id: 12,
                query: "hello \"world\"".to_string(),
                backwards: true,
            }
        );
        assert_eq!(
            parse_serve_request(r#"{"type":"page_text","id":13}"#)
                .expect("page text request should parse"),
            ServeRequest::PageText { id: 13 }
        );
        assert_eq!(
            parse_serve_request(r#"{"type":"selection_text","id":14}"#)
                .expect("selection text request should parse"),
            ServeRequest::SelectionText { id: 14 }
        );
        assert_eq!(
            parse_serve_request(r#"{"type":"screenshot","id":15,"path":"/tmp/page.png"}"#)
                .expect("screenshot request should parse"),
            ServeRequest::Screenshot {
                id: 15,
                path: PathBuf::from("/tmp/page.png"),
            }
        );
    }

    #[test]
    fn serve_response_encodes_single_json_line() {
        let response = ServeResponse {
            id: 7,
            status: ServeStatus::Ok,
            runtime: None,
            payload: Some("frame".to_string()),
            url: None,
            title: None,
            page: None,
            focused: None,
            text: None,
            selection: None,
            hints: Vec::new(),
            hint_error: None,
            found: None,
            match_count: None,
            error: None,
        };

        assert_eq!(
            encode_serve_response(&response),
            r#"{"id":7,"status":"ok","payload":"frame","title":null}"#
        );
    }

    #[test]
    fn serve_response_encodes_current_url_when_present() {
        let response = ServeResponse {
            id: 8,
            status: ServeStatus::Ok,
            runtime: None,
            payload: Some("frame".to_string()),
            url: Some("https://example.com".to_string()),
            title: Some("Example Domain".to_string()),
            page: None,
            focused: None,
            text: None,
            selection: None,
            hints: vec![ElementHint {
                id: 1,
                kind: ElementHintKind::Link,
                label: "Docs".to_string(),
                href: Some("https://example.com/docs".to_string()),
                checked: None,
                options: Vec::new(),
                x: 120.5,
                y: 240.0,
                width: 80.0,
                height: 24.0,
                clickable: true,
                focusable: false,
            }],
            hint_error: None,
            found: None,
            match_count: None,
            error: None,
        };

        assert_eq!(
            encode_serve_response(&response),
            r#"{"id":8,"status":"ok","payload":"frame","url":"https://example.com","title":"Example Domain","hints":[{"id":1,"kind":"link","label":"Docs","href":"https://example.com/docs","x":120.5,"y":240.0,"width":80.0,"height":24.0,"clickable":true,"focusable":false}]}"#
        );
    }

    #[test]
    fn serve_response_encodes_find_result_when_present() {
        let response = ServeResponse {
            id: 12,
            status: ServeStatus::Ok,
            runtime: None,
            payload: Some("frame".to_string()),
            url: Some("https://example.com".to_string()),
            title: Some("Example".to_string()),
            page: None,
            focused: None,
            text: None,
            selection: None,
            hints: Vec::new(),
            hint_error: None,
            found: Some(true),
            match_count: Some(3),
            error: None,
        };

        assert_eq!(
            encode_serve_response(&response),
            r#"{"id":12,"status":"ok","payload":"frame","url":"https://example.com","title":"Example","found":true,"match_count":3}"#
        );
    }

    #[test]
    fn serve_response_encodes_page_metrics_when_present() {
        let response = ServeResponse {
            id: 13,
            status: ServeStatus::Ok,
            runtime: None,
            payload: Some("frame".to_string()),
            url: Some("https://example.com".to_string()),
            title: Some("Example".to_string()),
            page: Some(PageMetrics {
                scroll_x: 0.0,
                scroll_y: 250.0,
                viewport_width: 800.0,
                viewport_height: 600.0,
                document_width: 800.0,
                document_height: 1600.0,
            }),
            focused: None,
            text: None,
            selection: None,
            hints: Vec::new(),
            hint_error: None,
            found: None,
            match_count: None,
            error: None,
        };

        assert_eq!(
            encode_serve_response(&response),
            r#"{"id":13,"status":"ok","payload":"frame","url":"https://example.com","title":"Example","page":{"scroll_x":0.0,"scroll_y":250.0,"viewport_width":800.0,"viewport_height":600.0,"document_width":800.0,"document_height":1600.0}}"#
        );
    }

    #[test]
    fn serve_response_encodes_focused_element_when_present() {
        let response = ServeResponse {
            id: 17,
            status: ServeStatus::Ok,
            runtime: None,
            payload: Some("frame".to_string()),
            url: Some("https://example.com".to_string()),
            title: Some("Example".to_string()),
            page: None,
            focused: Some(Some(FocusedElement {
                kind: ElementHintKind::Input,
                label: Some("Search".to_string()),
                value: Some("query".to_string()),
                checked: None,
                focusable: true,
                submittable: true,
            })),
            text: None,
            selection: None,
            hints: Vec::new(),
            hint_error: None,
            found: None,
            match_count: None,
            error: None,
        };

        assert_eq!(
            encode_serve_response(&response),
            r#"{"id":17,"status":"ok","payload":"frame","url":"https://example.com","title":"Example","focused":{"kind":"input","label":"Search","value":"query","focusable":true,"submittable":true}}"#
        );
    }

    #[test]
    fn serve_response_encodes_null_focused_when_checked_without_active_element() {
        let response = ServeResponse {
            id: 18,
            status: ServeStatus::Ok,
            runtime: None,
            payload: Some("frame".to_string()),
            url: Some("https://example.com".to_string()),
            title: Some("Example".to_string()),
            page: None,
            focused: Some(None),
            text: None,
            selection: None,
            hints: Vec::new(),
            hint_error: None,
            found: None,
            match_count: None,
            error: None,
        };

        assert_eq!(
            encode_serve_response(&response),
            r#"{"id":18,"status":"ok","payload":"frame","url":"https://example.com","title":"Example","focused":null}"#
        );
    }

    #[test]
    fn serve_response_encodes_page_text_when_present() {
        let response = ServeResponse {
            id: 14,
            status: ServeStatus::Ok,
            runtime: None,
            payload: None,
            url: Some("https://example.com".to_string()),
            title: Some("Example".to_string()),
            page: None,
            focused: None,
            text: Some(PageTextSnapshot {
                session_id: SessionId::new(1),
                page_id: PageId::new(1),
                url: "https://example.com".to_string(),
                title: Some("Example".to_string()),
                text: "# Example\n\nBody".to_string(),
                truncated: false,
            }),
            selection: None,
            hints: Vec::new(),
            hint_error: None,
            found: None,
            match_count: None,
            error: None,
        };

        assert_eq!(
            encode_serve_response(&response),
            r##"{"id":14,"status":"ok","url":"https://example.com","title":"Example","text":{"session_id":1,"page_id":1,"url":"https://example.com","title":"Example","text":"# Example\n\nBody","truncated":false}}"##
        );
    }

    #[test]
    fn serve_response_encodes_selection_when_present() {
        let response = ServeResponse {
            id: 16,
            status: ServeStatus::Ok,
            runtime: None,
            payload: None,
            url: Some("https://example.com".to_string()),
            title: Some("Example".to_string()),
            page: None,
            focused: None,
            text: None,
            selection: Some("selected text".to_string()),
            hints: Vec::new(),
            hint_error: None,
            found: None,
            match_count: None,
            error: None,
        };

        assert_eq!(
            encode_serve_response(&response),
            r#"{"id":16,"status":"ok","url":"https://example.com","title":"Example","selection":"selected text"}"#
        );
    }

    #[test]
    fn serve_response_encodes_runtime_metadata_when_present() {
        let response = ServeResponse {
            id: 15,
            status: ServeStatus::Ok,
            runtime: Some(ServeRuntimeInfo {
                protocol_version: 15,
                transport: "stdio-jsonl",
                renderer: "chromium-cdp",
                output: ImageOutput::KittyUnicode,
                cells: RuntimeCells {
                    columns: 80,
                    rows: 24,
                },
                viewport: RuntimeViewport {
                    width: 800,
                    height: 480,
                    device_scale_factor: 1.0,
                },
            }),
            payload: Some("frame".to_string()),
            url: Some("https://example.com".to_string()),
            title: Some("Example".to_string()),
            page: None,
            focused: None,
            text: None,
            selection: None,
            hints: Vec::new(),
            hint_error: None,
            found: None,
            match_count: None,
            error: None,
        };

        assert_eq!(
            encode_serve_response(&response),
            r#"{"id":15,"status":"ok","runtime":{"protocol_version":15,"transport":"stdio-jsonl","renderer":"chromium-cdp","output":"kitty-unicode","cells":{"columns":80,"rows":24},"viewport":{"width":800,"height":480,"device_scale_factor":1.0}},"payload":"frame","url":"https://example.com","title":"Example"}"#
        );
    }

    #[test]
    fn serve_runtime_attaches_runtime_metadata_to_ok_and_error_responses() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 80,
                rows: 24,
                viewport: Viewport::new(800, 480),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        let ok = runtime.handle(ServeRequest::Navigate {
            id: 21,
            url: "https://example.com".to_string(),
        });
        let runtime_info = ok
            .runtime
            .expect("ok responses should include runtime metadata");
        assert_eq!(runtime_info.protocol_version, 15);
        assert_eq!(runtime_info.transport, "stdio-jsonl");
        assert_eq!(runtime_info.renderer, "chromium-cdp");
        assert_eq!(runtime_info.output, ImageOutput::Ansi);
        assert_eq!(runtime_info.cells.columns, 80);
        assert_eq!(runtime_info.cells.rows, 24);
        assert_eq!(runtime_info.viewport.width, 800);
        assert_eq!(runtime_info.viewport.height, 480);
        assert_eq!(runtime_info.viewport.device_scale_factor, 1.0);

        let error = runtime.handle(ServeRequest::Back { id: 22 });
        assert_eq!(error.status, ServeStatus::Error);
        assert!(
            error.runtime.is_some(),
            "error responses should keep runtime diagnostics available"
        );
    }

    #[test]
    fn serve_runtime_resize_updates_cells_and_viewport_metadata() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::KittyUnicode,
                columns: 80,
                rows: 24,
                viewport: Viewport::new(800, 480),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );
        runtime.handle(ServeRequest::Navigate {
            id: 23,
            url: "https://example.com".to_string(),
        });

        let resized = runtime.handle(ServeRequest::Resize {
            id: 24,
            columns: 100,
            rows: 30,
            width: 1000,
            height: 600,
        });
        let runtime_info = resized
            .runtime
            .expect("resize responses should include updated runtime metadata");

        assert_eq!(runtime_info.output, ImageOutput::KittyUnicode);
        assert_eq!(runtime_info.cells.columns, 100);
        assert_eq!(runtime_info.cells.rows, 30);
        assert_eq!(runtime_info.viewport.width, 1000);
        assert_eq!(runtime_info.viewport.height, 600);
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
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        let response = runtime.handle(ServeRequest::Navigate {
            id: 3,
            url: "https://example.com".to_string(),
        });

        assert_eq!(response.id, 3);
        assert_eq!(response.status, ServeStatus::Ok);
        assert_eq!(response.url, Some("https://example.com".to_string()));
        assert_eq!(response.title, Some("https://example.com".to_string()));
        assert_eq!(response.focused, Some(None));
        assert_eq!(
            response.page,
            Some(PageMetrics {
                scroll_x: 0.0,
                scroll_y: 100.0,
                viewport_width: 10.0,
                viewport_height: 10.0,
                document_width: 10.0,
                document_height: 30.0,
            })
        );
        assert!(response.hints.is_empty());
        assert!(response.payload.expect("payload").contains("▀"));
    }

    #[test]
    fn serve_runtime_writes_active_session_screenshot_png() {
        let directory = tempfile::tempdir().expect("tempdir");
        let screenshot_path = directory.path().join("page.png");
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        let navigate = runtime.handle(ServeRequest::Navigate {
            id: 3,
            url: "https://example.com".to_string(),
        });
        assert_eq!(navigate.status, ServeStatus::Ok);

        let response = runtime.handle(ServeRequest::Screenshot {
            id: 4,
            path: screenshot_path.clone(),
        });

        assert_eq!(response.id, 4);
        assert_eq!(response.status, ServeStatus::Ok);
        assert_eq!(response.payload, None);
        assert_eq!(response.url, Some("https://example.com".to_string()));
        assert_eq!(
            std::fs::read(screenshot_path).expect("screenshot should be written"),
            tiny_png()
        );
    }

    #[test]
    fn serve_runtime_rejects_empty_screenshot_path() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        let response = runtime.handle(ServeRequest::Screenshot {
            id: 4,
            path: PathBuf::new(),
        });

        assert_eq!(response.status, ServeStatus::Error);
        assert!(response.error.expect("error").contains("screenshot path"));
    }

    #[test]
    fn serve_runtime_returns_self_contained_kitty_unicode_frame_payload() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::KittyUnicode,
                columns: 12,
                rows: 6,
                viewport: Viewport::new(120, 60),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        let navigate = runtime.handle(ServeRequest::Navigate {
            id: 3,
            url: "https://example.com".to_string(),
        });
        assert_eq!(navigate.status, ServeStatus::Ok);

        let response = runtime.handle(ServeRequest::Capture { id: 4 });
        let payload = response.payload.expect("payload");

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(payload.starts_with("\x1b_Ga=d,d=i,i=1\x1b\\"));
        assert!(payload.contains("a=T,q=2,U=1,i=1,c=12,r=6,f=100,s=120,v=60"));
    }

    #[test]
    fn frame_to_payload_tiles_large_kitty_browser_frames() {
        let frame = frame_with_png(1200, 900);

        let payload = frame_to_payload(frame, ImageOutput::Kitty, 120, Some(90)).expect("payload");

        assert!(payload.starts_with("\x1b_Ga=d,d=i,i=1\x1b\\"));
        assert!(payload.contains("a=T,C=1,i=2,p=1,c=40,r=20"));
        assert!(payload.matches("a=T,C=1").count() > 1);
    }

    #[test]
    fn frame_to_payload_tiles_large_kitty_browser_frames_without_explicit_rows() {
        let frame = frame_with_png(1200, 900);

        let payload = frame_to_payload(frame, ImageOutput::Kitty, 120, None).expect("payload");

        assert!(payload.starts_with("\x1b_Ga=d,d=i,i=1\x1b\\"));
        assert!(payload.contains("a=T,C=1,i=2,p=1,c=40,r=20"));
        assert!(payload.matches("a=T,C=1").count() > 1);
    }

    #[test]
    fn frame_to_payload_keeps_small_kitty_browser_frames_monolithic() {
        let frame = frame_with_png(320, 200);

        let payload = frame_to_payload(frame, ImageOutput::Kitty, 80, Some(24)).expect("payload");

        assert!(payload.starts_with("\x1b_Ga=d,d=i,i=1\x1b\\"));
        assert!(payload.contains("\x1b_Ga=d,d=i,i=257\x1b\\"));
        assert!(payload.contains("\x1b_Ga=T,i=1,p=1,c=80,r=24"));
        assert!(!payload.contains("C=1"));
    }

    #[test]
    fn frame_to_payload_ansi_browser_frames_respect_rows() {
        let frame = frame_with_png(320, 200);

        let payload = frame_to_payload(frame, ImageOutput::Ansi, 20, Some(3)).expect("payload");

        assert_eq!(payload.lines().count(), 3);
        assert!(payload.contains("\x1b[38;2;"));
        assert!(payload.contains("▀"));
        assert!(!payload.contains("\x1b_G"));
    }

    #[test]
    fn frame_to_payload_ansi_browser_frames_respect_zero_rows() {
        let frame = frame_with_png(320, 200);

        let payload = frame_to_payload(frame, ImageOutput::Ansi, 20, Some(0)).expect("payload");

        assert!(payload.is_empty());
    }

    #[test]
    fn ansi_halfblock_target_height_saturates_without_overflow() {
        assert_eq!(ansi_halfblock_target_height(Some(0)), Some(0));
        assert_eq!(ansi_halfblock_target_height(Some(3)), Some(6));
        assert_eq!(
            ansi_halfblock_target_height(Some(u32::MAX)),
            Some(u32::MAX - 1)
        );
    }

    #[test]
    fn serve_runtime_returns_hints_with_captured_frame() {
        let mut renderer = FakeRenderer::new();
        renderer.hints = vec![
            ElementHint {
                id: 1,
                kind: ElementHintKind::Button,
                label: "Search".to_string(),
                href: None,
                checked: None,
                options: Vec::new(),
                x: 50.0,
                y: 60.0,
                width: 100.0,
                height: 30.0,
                clickable: true,
                focusable: true,
            },
            ElementHint {
                id: 2,
                kind: ElementHintKind::Select,
                label: "Country".to_string(),
                href: None,
                checked: None,
                options: vec![
                    SelectOptionHint {
                        value: "jp".to_string(),
                        label: "Japan".to_string(),
                        disabled: false,
                        selected: false,
                    },
                    SelectOptionHint {
                        value: "ca".to_string(),
                        label: "Canada".to_string(),
                        disabled: false,
                        selected: true,
                    },
                ],
                x: 80.0,
                y: 90.0,
                width: 140.0,
                height: 30.0,
                clickable: true,
                focusable: true,
            },
        ];
        let mut runtime = ServeRuntime::new(
            renderer,
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        let response = runtime.handle(ServeRequest::Navigate {
            id: 3,
            url: "https://example.com".to_string(),
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert_eq!(response.hints.len(), 2);
        assert_eq!(response.hints[0].label, "Search");
        assert_eq!(response.hints[1].options[1].value, "ca");
        assert!(response.hints[1].options[1].selected);
        assert_eq!(runtime.renderer.operations, vec!["capture", "hints"]);
    }

    #[test]
    fn serve_runtime_surfaces_hint_extraction_failure_without_failing_frame() {
        let mut renderer = FakeRenderer::new();
        renderer.fail_hints = true;
        let mut runtime = ServeRuntime::new(
            renderer,
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        let response = runtime.handle(ServeRequest::Navigate {
            id: 3,
            url: "https://example.com".to_string(),
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(
            response.payload.is_some(),
            "frame payload should still render"
        );
        assert!(
            response.page.is_some(),
            "page metrics should still be attached"
        );
        assert!(
            response.hints.is_empty(),
            "failed hint extraction should not invent hints"
        );
        assert_eq!(
            response.hint_error.as_deref(),
            Some("hint extraction failed")
        );
        assert_eq!(runtime.renderer.operations, vec!["capture", "hints"]);
    }

    #[test]
    fn serve_runtime_ignores_focused_element_extraction_failure_without_failing_frame() {
        let mut renderer = FakeRenderer::new();
        renderer.fail_focused_element = true;
        let mut runtime = ServeRuntime::new(
            renderer,
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        let navigate = runtime.handle(ServeRequest::Navigate {
            id: 3,
            url: "https://example.com".to_string(),
        });
        assert_eq!(navigate.status, ServeStatus::Ok);

        let response = runtime.handle(ServeRequest::Capture { id: 4 });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(
            response.payload.is_some(),
            "frame payload should still render"
        );
        assert_eq!(response.focused, Some(None));
        assert_eq!(
            runtime.renderer.operations,
            vec![
                "capture",
                "hints",
                "focused_element",
                "capture",
                "hints",
                "focused_element"
            ]
        );
    }

    #[test]
    fn serve_runtime_refreshes_title_from_captured_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );
        let navigate = runtime.handle(ServeRequest::Navigate {
            id: 3,
            url: "https://example.com".to_string(),
        });
        assert_eq!(navigate.title, Some("https://example.com".to_string()));

        runtime.renderer.next_frame_title = Some("Async Title".to_string());
        let capture = runtime.handle(ServeRequest::Capture { id: 4 });

        assert_eq!(capture.status, ServeStatus::Ok);
        assert_eq!(capture.title, Some("Async Title".to_string()));
    }

    #[test]
    fn serve_runtime_refreshes_url_from_captured_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );
        let navigate = runtime.handle(ServeRequest::Navigate {
            id: 3,
            url: "https://example.com".to_string(),
        });
        assert_eq!(navigate.url, Some("https://example.com".to_string()));

        runtime.renderer.next_frame_url = Some("https://example.com/spa".to_string());
        let capture = runtime.handle(ServeRequest::Capture { id: 4 });

        assert_eq!(capture.status, ServeStatus::Ok);
        assert_eq!(capture.url, Some("https://example.com/spa".to_string()));
        assert_eq!(capture.title, Some("https://example.com/spa".to_string()));
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
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
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
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
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
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
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
        assert_eq!(forward.focused, Some(None));
        assert_eq!(
            runtime.session.active_page().url(),
            Some("https://example.com/two")
        );
        assert_eq!(
            runtime.renderer.operations,
            vec![
                "capture", "hints", "capture", "hints", "back", "capture", "hints", "forward",
                "capture", "hints"
            ]
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
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
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
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
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
    fn serve_runtime_applies_zoom_before_capturing_next_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::Zoom { id: 2, scale: 1.25 });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_some());
        assert_eq!(response.url.as_deref(), Some("https://example.com"));
        assert_eq!(response.title.as_deref(), Some("https://example.com"));
        assert_eq!(
            response.page,
            runtime
                .renderer
                .page_metrics(PageMetricsRequest::new(SessionId::new(1), PageId::new(1)))
                .expect("page metrics")
                .clone()
        );
        assert_eq!(runtime.renderer.zooms, vec![1.25]);
        assert!(runtime.renderer.operations.contains(&"capture"));
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
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::TextInput {
            id: 2,
            text: "hello".to_string(),
            capture: true,
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_some());
        assert_eq!(runtime.renderer.text_inputs, vec!["hello"]);
        assert_eq!(runtime.renderer.captures, 2);
        assert_eq!(
            runtime.renderer.operations,
            vec![
                "capture",
                "hints",
                "text_input",
                "settle",
                "capture",
                "hints"
            ]
        );
    }

    #[test]
    fn serve_runtime_applies_quiet_text_input_without_capturing_frame() {
        let mut renderer = FakeRenderer::new();
        renderer.focused = Some(FocusedElement {
            kind: ElementHintKind::Input,
            label: Some("Search".to_string()),
            value: Some("hello".to_string()),
            checked: None,
            focusable: true,
            submittable: true,
        });
        let mut runtime = ServeRuntime::new(
            renderer,
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        let response = runtime.handle(ServeRequest::TextInput {
            id: 2,
            text: "hello".to_string(),
            capture: false,
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_none());
        assert!(response.page.is_some());
        assert_eq!(
            response
                .focused
                .as_ref()
                .and_then(|focus| focus.as_ref())
                .and_then(|focus| focus.label.as_deref()),
            Some("Search")
        );
        assert!(response.hints.is_empty());
        assert_eq!(runtime.renderer.text_inputs, vec!["hello"]);
        assert_eq!(runtime.renderer.captures, 0);
        assert_eq!(
            runtime.renderer.operations,
            vec!["text_input", "settle", "focused_element"]
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
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::KeyPress {
            id: 2,
            key: "Enter".to_string(),
            modifiers: Vec::new(),
            capture: true,
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_some());
        assert_eq!(runtime.renderer.key_presses, vec!["Enter"]);
        assert_eq!(runtime.renderer.captures, 2);
        assert_eq!(
            runtime.renderer.operations,
            vec![
                "capture",
                "hints",
                "key_press",
                "settle",
                "capture",
                "hints"
            ]
        );
    }

    #[test]
    fn serve_runtime_submits_current_focused_element_before_capturing_next_frame() {
        let mut renderer = FakeRenderer::new();
        renderer.focused = Some(FocusedElement {
            kind: ElementHintKind::Input,
            label: Some("Search".to_string()),
            value: Some("hello".to_string()),
            checked: None,
            focusable: true,
            submittable: true,
        });
        let mut runtime = ServeRuntime::new(
            renderer,
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::SubmitFocused { id: 2 });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_some());
        assert_eq!(runtime.renderer.key_presses, vec!["Enter"]);
        assert_eq!(
            response
                .focused
                .as_ref()
                .and_then(|focus| focus.as_ref())
                .and_then(|focus| focus.label.as_deref()),
            Some("Search")
        );
        assert_eq!(
            runtime.renderer.operations,
            vec![
                "capture",
                "hints",
                "focused_element",
                "focused_element",
                "key_press",
                "settle",
                "capture",
                "hints",
                "focused_element"
            ]
        );
    }

    #[test]
    fn serve_runtime_rejects_submit_focused_when_active_element_is_not_submittable() {
        let mut renderer = FakeRenderer::new();
        renderer.focused = Some(FocusedElement {
            kind: ElementHintKind::Button,
            label: Some("Cancel".to_string()),
            value: None,
            checked: None,
            focusable: true,
            submittable: false,
        });
        let mut runtime = ServeRuntime::new(
            renderer,
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::SubmitFocused { id: 2 });

        assert_eq!(response.status, ServeStatus::Error);
        assert!(response.payload.is_none());
        assert!(runtime.renderer.key_presses.is_empty());
        assert_eq!(
            response.error.as_deref(),
            Some("InvalidState: focused element is not submittable")
        );
        assert_eq!(
            runtime.renderer.operations,
            vec!["capture", "hints", "focused_element", "focused_element"]
        );
    }

    #[test]
    fn serve_runtime_applies_quiet_key_press_without_capturing_frame() {
        let mut renderer = FakeRenderer::new();
        renderer.focused = Some(FocusedElement {
            kind: ElementHintKind::TextArea,
            label: Some("Notes".to_string()),
            value: Some("draft".to_string()),
            checked: None,
            focusable: true,
            submittable: false,
        });
        let mut runtime = ServeRuntime::new(
            renderer,
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        let response = runtime.handle(ServeRequest::KeyPress {
            id: 2,
            key: "Tab".to_string(),
            modifiers: vec!["shift".to_string()],
            capture: false,
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_none());
        assert!(response.page.is_some());
        assert_eq!(
            response
                .focused
                .as_ref()
                .and_then(|focus| focus.as_ref())
                .and_then(|focus| focus.label.as_deref()),
            Some("Notes")
        );
        assert!(response.hints.is_empty());
        assert_eq!(runtime.renderer.key_presses, vec!["Shift+Tab"]);
        assert_eq!(runtime.renderer.captures, 0);
        assert_eq!(
            runtime.renderer.operations,
            vec!["key_press", "settle", "focused_element"]
        );
    }

    #[test]
    fn serve_runtime_passes_key_modifiers_to_renderer() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::KeyPress {
            id: 2,
            key: "Tab".to_string(),
            modifiers: vec!["shift".to_string()],
            capture: true,
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert_eq!(runtime.renderer.key_presses, vec!["Shift+Tab"]);
    }

    #[test]
    fn serve_runtime_passes_multiple_key_modifiers_to_renderer() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::KeyPress {
            id: 2,
            key: "Tab".to_string(),
            modifiers: vec!["ctrl".to_string(), "shift".to_string()],
            capture: true,
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert_eq!(runtime.renderer.key_presses, vec!["Ctrl+Shift+Tab"]);
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
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
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
            vec![
                "capture",
                "hints",
                "focus_selector",
                "settle",
                "capture",
                "hints"
            ]
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
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
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
            vec![
                "capture",
                "hints",
                "click_point",
                "settle",
                "capture",
                "hints"
            ]
        );
    }

    #[test]
    fn serve_runtime_right_clicks_point_before_capturing_next_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::RightClickPoint {
            id: 2,
            x: 120.5,
            y: 240.25,
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_some());
        assert_eq!(runtime.renderer.right_clicked_points, vec![(120.5, 240.25)]);
        assert_eq!(runtime.renderer.captures, 2);
        assert_eq!(
            runtime.renderer.operations,
            vec![
                "capture",
                "hints",
                "right_click_point",
                "settle",
                "capture",
                "hints"
            ]
        );
    }

    #[test]
    fn serve_runtime_hovers_point_before_capturing_next_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::HoverPoint {
            id: 2,
            x: 120.5,
            y: 240.25,
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_some());
        assert_eq!(runtime.renderer.hovered_points, vec![(120.5, 240.25)]);
        assert_eq!(runtime.renderer.captures, 2);
        assert_eq!(
            runtime.renderer.operations,
            vec![
                "capture",
                "hints",
                "hover_point",
                "settle",
                "capture",
                "hints"
            ]
        );
    }

    #[test]
    fn serve_runtime_wheels_point_before_capturing_next_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::WheelPoint {
            id: 2,
            x: 120.5,
            y: 240.25,
            delta_x: 0.0,
            delta_y: 120.0,
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_some());
        assert_eq!(
            runtime.renderer.wheeled_points,
            vec![(120.5, 240.25, 0.0, 120.0)]
        );
        assert_eq!(runtime.renderer.captures, 2);
        assert_eq!(
            runtime.renderer.operations,
            vec![
                "capture",
                "hints",
                "wheel_point",
                "settle",
                "capture",
                "hints"
            ]
        );
    }

    #[test]
    fn serve_runtime_hovers_hint_before_capturing_next_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::HoverHint { id: 2, hint_id: 2 });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_some());
        assert_eq!(runtime.renderer.hovered_hints, vec![2]);
        assert!(runtime.renderer.hovered_points.is_empty());
        assert_eq!(runtime.renderer.captures, 2);
        assert_eq!(
            runtime.renderer.operations,
            vec![
                "capture",
                "hints",
                "hover_hint",
                "settle",
                "capture",
                "hints"
            ]
        );
    }

    #[test]
    fn serve_runtime_does_not_capture_when_hint_hover_fails() {
        let mut renderer = FakeRenderer::new();
        renderer.fail_hover_hint = true;
        let mut runtime = ServeRuntime::new(
            renderer,
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::HoverHint {
            id: 2,
            hint_id: 404,
        });

        assert_eq!(response.status, ServeStatus::Error);
        assert!(response.payload.is_none());
        assert_eq!(runtime.renderer.hovered_hints, vec![404]);
        assert!(runtime.renderer.hovered_points.is_empty());
        assert_eq!(
            runtime.renderer.operations,
            vec!["capture", "hints", "hover_hint"]
        );
    }

    #[test]
    fn serve_runtime_finds_text_before_capturing_next_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::FindText {
            id: 2,
            query: "needle".to_string(),
            backwards: true,
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_some());
        assert_eq!(response.found, Some(true));
        assert_eq!(response.match_count, Some(3));
        assert_eq!(runtime.renderer.find_queries, vec!["needle"]);
        assert_eq!(runtime.renderer.find_directions, vec![true]);
        assert_eq!(runtime.renderer.captures, 2);
        assert_eq!(
            runtime.renderer.operations,
            vec!["capture", "hints", "find_text", "capture", "hints"]
        );
    }

    #[test]
    fn serve_runtime_reads_page_text_without_capturing_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );
        let navigate = runtime.handle(ServeRequest::Navigate {
            id: 3,
            url: "https://example.com".to_string(),
        });
        assert_eq!(navigate.status, ServeStatus::Ok);
        runtime.renderer.operations.clear();
        runtime.renderer.captures = 0;

        let response = runtime.handle(ServeRequest::PageText { id: 12 });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_none());
        assert!(response.hints.is_empty());
        assert_eq!(
            response
                .text
                .as_ref()
                .map(|snapshot| snapshot.text.as_str()),
            Some("# Example\n\nExample body")
        );
        assert_eq!(runtime.renderer.operations, vec!["page_text"]);
        assert_eq!(runtime.renderer.captures, 0);
    }

    #[test]
    fn serve_runtime_reads_selection_text_without_capturing_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );
        let navigate = runtime.handle(ServeRequest::Navigate {
            id: 3,
            url: "https://example.com".to_string(),
        });
        assert_eq!(navigate.status, ServeStatus::Ok);
        runtime.renderer.operations.clear();
        runtime.renderer.captures = 0;

        let response = runtime.handle(ServeRequest::SelectionText { id: 13 });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_none());
        assert!(response.hints.is_empty());
        assert_eq!(response.selection.as_deref(), Some("selected text"));
        assert_eq!(runtime.renderer.operations, vec!["selection_text"]);
        assert_eq!(runtime.renderer.captures, 0);
    }

    #[test]
    fn serve_runtime_types_at_point_before_capturing_next_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::TypePoint {
            id: 2,
            x: 120.5,
            y: 240.25,
            text: "hello".to_string(),
            submit: true,
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_some());
        assert_eq!(runtime.renderer.clicked_points, vec![(120.5, 240.25)]);
        assert_eq!(runtime.renderer.text_inputs, vec!["hello"]);
        assert_eq!(runtime.renderer.key_presses, vec!["Enter"]);
        assert_eq!(runtime.renderer.captures, 2);
        assert_eq!(
            runtime.renderer.operations,
            vec![
                "capture",
                "hints",
                "click_point",
                "settle",
                "text_input",
                "settle",
                "key_press",
                "settle",
                "capture",
                "hints"
            ]
        );
    }

    #[test]
    fn serve_runtime_does_not_type_at_point_when_click_fails() {
        let mut renderer = FakeRenderer::new();
        renderer.fail_click = true;
        let mut runtime = ServeRuntime::new(
            renderer,
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::TypePoint {
            id: 2,
            x: 120.5,
            y: 240.25,
            text: "hello".to_string(),
            submit: true,
        });

        assert_eq!(response.status, ServeStatus::Error);
        assert!(response.payload.is_none());
        assert!(runtime.renderer.text_inputs.is_empty());
        assert!(runtime.renderer.key_presses.is_empty());
        assert_eq!(
            runtime.renderer.operations,
            vec!["capture", "hints", "click_point"]
        );
    }

    #[test]
    fn serve_runtime_clicks_hint_before_capturing_next_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::ClickHint { id: 2, hint_id: 2 });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_some());
        assert_eq!(runtime.renderer.clicked_hints, vec![2]);
        assert!(runtime.renderer.clicked_points.is_empty());
        assert_eq!(runtime.renderer.captures, 2);
        assert_eq!(
            runtime.renderer.operations,
            vec![
                "capture",
                "hints",
                "click_hint",
                "settle",
                "capture",
                "hints"
            ]
        );
    }

    #[test]
    fn serve_runtime_right_clicks_hint_before_capturing_next_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::RightClickHint { id: 2, hint_id: 2 });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_some());
        assert_eq!(runtime.renderer.right_clicked_hints, vec![2]);
        assert!(runtime.renderer.clicked_points.is_empty());
        assert!(runtime.renderer.right_clicked_points.is_empty());
        assert_eq!(runtime.renderer.captures, 2);
        assert_eq!(
            runtime.renderer.operations,
            vec![
                "capture",
                "hints",
                "right_click_hint",
                "settle",
                "capture",
                "hints"
            ]
        );
    }

    #[test]
    fn serve_runtime_does_not_capture_when_hint_click_fails() {
        let mut renderer = FakeRenderer::new();
        renderer.fail_click_hint = true;
        let mut runtime = ServeRuntime::new(
            renderer,
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::ClickHint {
            id: 2,
            hint_id: 404,
        });

        assert_eq!(response.status, ServeStatus::Error);
        assert!(response.payload.is_none());
        assert_eq!(runtime.renderer.clicked_hints, vec![404]);
        assert!(runtime.renderer.clicked_points.is_empty());
        assert_eq!(
            runtime.renderer.operations,
            vec!["capture", "hints", "click_hint"]
        );
    }

    #[test]
    fn serve_runtime_does_not_capture_when_hint_right_click_fails() {
        let mut renderer = FakeRenderer::new();
        renderer.fail_right_click_hint = true;
        let mut runtime = ServeRuntime::new(
            renderer,
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::RightClickHint {
            id: 2,
            hint_id: 404,
        });

        assert_eq!(response.status, ServeStatus::Error);
        assert!(response.payload.is_none());
        assert_eq!(runtime.renderer.right_clicked_hints, vec![404]);
        assert!(runtime.renderer.clicked_points.is_empty());
        assert!(runtime.renderer.right_clicked_points.is_empty());
        assert_eq!(
            runtime.renderer.operations,
            vec!["capture", "hints", "right_click_hint"]
        );
    }

    #[test]
    fn serve_runtime_focuses_hint_before_capturing_next_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::FocusHint { id: 2, hint_id: 3 });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_some());
        assert_eq!(runtime.renderer.focused_hints, vec![3]);
        assert_eq!(
            runtime.renderer.operations,
            vec![
                "capture",
                "hints",
                "focus_hint",
                "settle",
                "capture",
                "hints"
            ]
        );
    }

    #[test]
    fn serve_runtime_does_not_capture_when_hint_focus_fails() {
        let mut renderer = FakeRenderer::new();
        renderer.fail_focus_hint = true;
        let mut runtime = ServeRuntime::new(
            renderer,
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::FocusHint {
            id: 2,
            hint_id: 404,
        });

        assert_eq!(response.status, ServeStatus::Error);
        assert!(response.payload.is_none());
        assert_eq!(runtime.renderer.focused_hints, vec![404]);
        assert_eq!(
            runtime.renderer.operations,
            vec!["capture", "hints", "focus_hint"]
        );
    }

    #[test]
    fn serve_runtime_types_at_hint_before_capturing_next_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::TypeHint {
            id: 2,
            hint_id: 2,
            text: "hello".to_string(),
            submit: true,
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_some());
        assert_eq!(runtime.renderer.focused_hints, vec![2]);
        assert!(runtime.renderer.clicked_points.is_empty());
        assert_eq!(runtime.renderer.text_inputs, vec!["hello"]);
        assert_eq!(runtime.renderer.key_presses, vec!["Enter"]);
        assert_eq!(
            runtime.renderer.operations,
            vec![
                "capture",
                "hints",
                "focus_hint",
                "settle",
                "text_input",
                "settle",
                "key_press",
                "settle",
                "capture",
                "hints"
            ]
        );
    }

    #[test]
    fn serve_runtime_does_not_type_at_hint_when_focus_fails() {
        let mut renderer = FakeRenderer::new();
        renderer.fail_focus_hint = true;
        let mut runtime = ServeRuntime::new(
            renderer,
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::TypeHint {
            id: 2,
            hint_id: 404,
            text: "hello".to_string(),
            submit: true,
        });

        assert_eq!(response.status, ServeStatus::Error);
        assert!(response.payload.is_none());
        assert_eq!(runtime.renderer.focused_hints, vec![404]);
        assert!(runtime.renderer.clicked_points.is_empty());
        assert!(runtime.renderer.text_inputs.is_empty());
        assert!(runtime.renderer.key_presses.is_empty());
        assert_eq!(
            runtime.renderer.operations,
            vec!["capture", "hints", "focus_hint"]
        );
    }

    #[test]
    fn serve_runtime_selects_hint_before_capturing_next_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::SelectHint {
            id: 2,
            hint_id: 3,
            choice: "Canada".to_string(),
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_some());
        assert_eq!(
            runtime.renderer.selected_hints,
            vec![(3, "Canada".to_string())]
        );
        assert_eq!(
            runtime.renderer.operations,
            vec![
                "capture",
                "hints",
                "select_hint",
                "settle",
                "capture",
                "hints"
            ]
        );
    }

    #[test]
    fn serve_runtime_does_not_capture_when_hint_select_fails() {
        let mut renderer = FakeRenderer::new();
        renderer.fail_select_hint = true;
        let mut runtime = ServeRuntime::new(
            renderer,
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::SelectHint {
            id: 2,
            hint_id: 404,
            choice: "Canada".to_string(),
        });

        assert_eq!(response.status, ServeStatus::Error);
        assert!(response.payload.is_none());
        assert_eq!(
            runtime.renderer.selected_hints,
            vec![(404, "Canada".to_string())]
        );
        assert_eq!(
            runtime.renderer.operations,
            vec!["capture", "hints", "select_hint"]
        );
    }

    #[test]
    fn serve_runtime_toggles_hint_before_capturing_next_frame() {
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::ToggleHint { id: 2, hint_id: 3 });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_some());
        assert_eq!(runtime.renderer.toggled_hints, vec![3]);
        assert_eq!(
            runtime.renderer.operations,
            vec![
                "capture",
                "hints",
                "toggle_hint",
                "settle",
                "capture",
                "hints"
            ]
        );
    }

    #[test]
    fn serve_runtime_does_not_capture_when_hint_toggle_fails() {
        let mut renderer = FakeRenderer::new();
        renderer.fail_toggle_hint = true;
        let mut runtime = ServeRuntime::new(
            renderer,
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::ToggleHint {
            id: 2,
            hint_id: 404,
        });

        assert_eq!(response.status, ServeStatus::Error);
        assert!(response.payload.is_none());
        assert_eq!(runtime.renderer.toggled_hints, vec![404]);
        assert_eq!(
            runtime.renderer.operations,
            vec!["capture", "hints", "toggle_hint"]
        );
    }

    #[test]
    fn serve_runtime_uploads_hint_before_capturing_next_frame() {
        let file = tempfile::NamedTempFile::new().expect("upload fixture should be created");
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::UploadHint {
            id: 2,
            hint_id: 8,
            paths: vec![file.path().to_path_buf()],
        });

        assert_eq!(response.status, ServeStatus::Ok);
        assert!(response.payload.is_some());
        assert_eq!(
            runtime.renderer.uploaded_hints,
            vec![(8, vec![fs::canonicalize(file.path()).unwrap()])]
        );
        assert_eq!(
            runtime.renderer.operations,
            vec![
                "capture",
                "hints",
                "upload_hint",
                "settle",
                "capture",
                "hints"
            ]
        );
    }

    #[test]
    fn serve_runtime_rejects_missing_upload_paths_before_renderer() {
        let missing = std::env::temp_dir().join("nvbrowser-missing-upload-fixture.txt");
        let _ = fs::remove_file(&missing);
        let mut runtime = ServeRuntime::new(
            FakeRenderer::new(),
            ServeOptions {
                output: ImageOutput::Ansi,
                columns: 1,
                rows: 1,
                viewport: Viewport::new(10, 10),
                initial_url: None,
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com".to_string(),
        });
        let response = runtime.handle(ServeRequest::UploadHint {
            id: 2,
            hint_id: 8,
            paths: vec![missing.clone()],
        });

        assert_eq!(response.status, ServeStatus::Error);
        assert!(response.payload.is_none());
        assert!(
            response
                .error
                .as_deref()
                .unwrap_or_default()
                .contains("upload path does not exist"),
            "missing upload path should produce a clear error"
        );
        assert!(runtime.renderer.uploaded_hints.is_empty());
        assert_eq!(runtime.renderer.operations, vec!["capture", "hints"]);
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
                markdown_preview: None,
                cdp_ws_url: None,
                user_data_dir: None,
            },
        );

        runtime.handle(ServeRequest::Navigate {
            id: 1,
            url: "https://example.com/form".to_string(),
        });
        let response = runtime.handle(ServeRequest::KeyPress {
            id: 2,
            key: "Enter".to_string(),
            modifiers: Vec::new(),
            capture: true,
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

    #[test]
    fn capture_output_writes_png_file_and_metadata_file() {
        let directory = tempfile::tempdir().expect("tempdir should be created");
        let png_path = directory.path().join("frame.png");
        let metadata_path = directory.path().join("frame.json");
        let frame = fake_capture_frame();
        let mut stdout = Vec::new();

        write_capture_outputs(&frame, &png_path, Some(&metadata_path), &mut stdout)
            .expect("capture outputs should be written");

        assert_eq!(
            std::fs::read(&png_path).expect("png should be readable"),
            tiny_png()
        );
        let metadata =
            std::fs::read_to_string(&metadata_path).expect("metadata should be readable");
        let metadata: serde_json::Value =
            serde_json::from_str(&metadata).expect("metadata should be valid json");
        assert_eq!(metadata["url"], "https://example.com");
        assert_eq!(metadata["viewport"]["width"], 320);
        assert_eq!(metadata["viewport"]["height"], 200);
        assert_eq!(metadata["captured_at_unix_ms"], 123456);
        assert!(stdout.is_empty(), "file outputs should not write stdout");
    }

    #[test]
    fn capture_output_can_write_png_to_stdout_buffer() {
        let frame = fake_capture_frame();
        let mut stdout = Vec::new();

        write_capture_outputs(&frame, Path::new("-"), None, &mut stdout)
            .expect("stdout capture should be written");

        assert_eq!(stdout, tiny_png());
    }

    #[test]
    fn capture_output_can_write_metadata_to_stdout_when_png_is_file() {
        let directory = tempfile::tempdir().expect("tempdir should be created");
        let png_path = directory.path().join("frame.png");
        let frame = fake_capture_frame();
        let mut stdout = Vec::new();

        write_capture_outputs(&frame, &png_path, Some(Path::new("-")), &mut stdout)
            .expect("metadata stdout capture should be written");

        assert_eq!(
            std::fs::read(&png_path).expect("png should be readable"),
            tiny_png()
        );
        let metadata = String::from_utf8(stdout).expect("metadata should be utf-8");
        let parsed: serde_json::Value =
            serde_json::from_str(&metadata).expect("metadata stdout should be valid json");
        assert_eq!(parsed["url"], "https://example.com");
        assert!(metadata.ends_with('\n'));
    }

    #[test]
    fn capture_rejects_png_stdout_and_metadata_stdout_together() {
        let frame = fake_capture_frame();
        let mut stdout = Vec::new();

        let error =
            write_capture_outputs(&frame, Path::new("-"), Some(Path::new("-")), &mut stdout)
                .expect_err("mixed stdout output should be rejected");

        assert!(error
            .to_string()
            .contains("cannot write PNG and metadata to stdout"));
    }

    #[test]
    fn capture_rejects_same_file_for_png_and_metadata() {
        let directory = tempfile::tempdir().expect("tempdir should be created");
        let output_path = directory.path().join("frame");
        let frame = fake_capture_frame();
        let mut stdout = Vec::new();

        let error = write_capture_outputs(&frame, &output_path, Some(&output_path), &mut stdout)
            .expect_err("same file output should be rejected");

        assert!(error
            .to_string()
            .contains("cannot write PNG and metadata to the same file"));
    }

    fn fake_capture_frame() -> RenderedFrame {
        RenderedFrame {
            metadata: FrameMetadata::new(
                FrameId::new(1),
                SessionId::new(1),
                PageId::new(1),
                "https://example.com",
                Some("Example Domain".to_string()),
                Viewport::new(320, 200),
                123456,
            ),
            artifact: FrameArtifact::Png(tiny_png()),
        }
    }

    fn frame_with_png(width: u32, height: u32) -> RenderedFrame {
        RenderedFrame {
            metadata: FrameMetadata::new(
                FrameId::new(1),
                SessionId::new(1),
                PageId::new(1),
                "https://example.com",
                Some("Example Domain".to_string()),
                Viewport::new(width, height),
                123456,
            ),
            artifact: FrameArtifact::Png(test_png(width, height)),
        }
    }

    fn tiny_png() -> Vec<u8> {
        const PNG: &str = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==";
        general_purpose::STANDARD
            .decode(PNG)
            .expect("embedded PNG should decode")
    }

    fn test_png(width: u32, height: u32) -> Vec<u8> {
        let image = DynamicImage::new_rgba8(width, height);
        let mut png = Cursor::new(Vec::new());
        image
            .write_to(&mut png, ImageFormat::Png)
            .expect("test PNG should encode");
        png.into_inner()
    }
}
