pub mod chromium;

use std::path::PathBuf;

use serde::{Deserialize, Serialize};

use crate::session::{FrameMetadata, PageId, SessionId, Viewport};

pub trait Renderer {
    fn navigate(&mut self, request: NavigateRequest) -> Result<NavigationResult, RendererError>;

    fn render_frame(&mut self, request: RenderFrameRequest)
        -> Result<RenderedFrame, RendererError>;

    fn scroll(&mut self, request: ScrollRequest) -> Result<ScrollResult, RendererError>;

    fn zoom(&mut self, _request: ZoomRequest) -> Result<ZoomResult, RendererError> {
        Err(RendererError::new(
            RendererErrorKind::InvalidState,
            "page zoom is not supported by this renderer",
        ))
    }

    fn reload(&mut self, request: ReloadRequest) -> Result<ReloadResult, RendererError>;

    fn go_back(
        &mut self,
        request: HistoryNavigationRequest,
    ) -> Result<HistoryNavigationResult, RendererError>;

    fn go_forward(
        &mut self,
        request: HistoryNavigationRequest,
    ) -> Result<HistoryNavigationResult, RendererError>;

    fn input_text(&mut self, request: TextInputRequest) -> Result<InputResult, RendererError>;

    fn press_key(&mut self, request: KeyPressRequest) -> Result<InputResult, RendererError>;

    fn focus_selector(
        &mut self,
        request: FocusSelectorRequest,
    ) -> Result<InputResult, RendererError>;

    fn focus_hint(&mut self, request: FocusHintRequest) -> Result<InputResult, RendererError>;

    fn click_hint(&mut self, request: ClickHintRequest) -> Result<InputResult, RendererError>;

    fn right_click_hint(
        &mut self,
        request: RightClickHintRequest,
    ) -> Result<InputResult, RendererError>;

    fn hover_hint(&mut self, request: HoverHintRequest) -> Result<InputResult, RendererError>;

    fn select_hint(&mut self, request: SelectHintRequest) -> Result<InputResult, RendererError>;

    fn upload_hint(&mut self, request: UploadHintRequest) -> Result<InputResult, RendererError>;

    fn toggle_hint(&mut self, request: ToggleHintRequest) -> Result<InputResult, RendererError>;

    fn click_point(&mut self, request: ClickPointRequest) -> Result<InputResult, RendererError>;

    fn drag_point(&mut self, request: DragPointRequest) -> Result<InputResult, RendererError>;

    fn right_click_point(
        &mut self,
        request: RightClickPointRequest,
    ) -> Result<InputResult, RendererError>;

    fn hover_point(&mut self, request: HoverPointRequest) -> Result<InputResult, RendererError>;

    fn wheel_point(&mut self, request: WheelPointRequest) -> Result<InputResult, RendererError>;

    fn find_text(&mut self, request: FindTextRequest) -> Result<FindTextResult, RendererError>;

    fn page_text(&mut self, _request: PageTextRequest) -> Result<PageTextSnapshot, RendererError> {
        Err(RendererError::new(
            RendererErrorKind::InvalidState,
            "page text snapshots are not supported by this renderer",
        ))
    }

    fn selection_text(
        &mut self,
        _request: SelectionTextRequest,
    ) -> Result<SelectionTextResult, RendererError> {
        Err(RendererError::new(
            RendererErrorKind::InvalidState,
            "selection text is not supported by this renderer",
        ))
    }

    fn element_hints(
        &mut self,
        _request: ElementHintsRequest,
    ) -> Result<Vec<ElementHint>, RendererError> {
        Ok(Vec::new())
    }

    fn page_metrics(
        &mut self,
        _request: PageMetricsRequest,
    ) -> Result<Option<PageMetrics>, RendererError> {
        Ok(None)
    }

    fn page_metadata(
        &mut self,
        _request: PageMetadataRequest,
    ) -> Result<Option<PageMetadata>, RendererError> {
        Ok(None)
    }

    fn focused_element(
        &mut self,
        _request: FocusedElementRequest,
    ) -> Result<Option<FocusedElement>, RendererError> {
        Ok(None)
    }

    fn settle_after_interaction(&mut self) -> Result<InteractionSettleResult, RendererError>;

    fn shutdown(&mut self) -> Result<ShutdownResult, RendererError>;
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct NavigateRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub url: String,
}

impl NavigateRequest {
    pub fn new(session_id: SessionId, page_id: PageId, url: impl Into<String>) -> Self {
        Self {
            session_id,
            page_id,
            url: url.into(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct NavigationResult {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub url: String,
    pub title: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct RenderFrameRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub viewport: Viewport,
}

impl RenderFrameRequest {
    pub const fn new(session_id: SessionId, page_id: PageId, viewport: Viewport) -> Self {
        Self {
            session_id,
            page_id,
            viewport,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub enum FrameArtifact {
    Png(Vec<u8>),
    Text(String),
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct RenderedFrame {
    pub metadata: FrameMetadata,
    pub artifact: FrameArtifact,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct PageMetricsRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
}

impl PageMetricsRequest {
    pub const fn new(session_id: SessionId, page_id: PageId) -> Self {
        Self {
            session_id,
            page_id,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct PageMetrics {
    pub scroll_x: f64,
    pub scroll_y: f64,
    pub viewport_width: f64,
    pub viewport_height: f64,
    pub document_width: f64,
    pub document_height: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub struct PageMetadataRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
}

impl PageMetadataRequest {
    pub const fn new(session_id: SessionId, page_id: PageId) -> Self {
        Self {
            session_id,
            page_id,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct PageMetadata {
    pub url: String,
    pub title: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub struct FocusedElementRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
}

impl FocusedElementRequest {
    pub const fn new(session_id: SessionId, page_id: PageId) -> Self {
        Self {
            session_id,
            page_id,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub struct FocusedElement {
    pub kind: ElementHintKind,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub label: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub value: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub checked: Option<bool>,
    pub focusable: bool,
    pub submittable: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub struct ScrollRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub delta_x: i32,
    pub delta_y: i32,
}

impl ScrollRequest {
    pub const fn new(session_id: SessionId, page_id: PageId, delta_x: i32, delta_y: i32) -> Self {
        Self {
            session_id,
            page_id,
            delta_x,
            delta_y,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub struct ScrollResult {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub delta_x: i32,
    pub delta_y: i32,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct ZoomRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub scale: f64,
}

impl ZoomRequest {
    pub const fn new(session_id: SessionId, page_id: PageId, scale: f64) -> Self {
        Self {
            session_id,
            page_id,
            scale,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct ZoomResult {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub scale: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub struct ReloadRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
}

impl ReloadRequest {
    pub const fn new(session_id: SessionId, page_id: PageId) -> Self {
        Self {
            session_id,
            page_id,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ReloadResult {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub url: String,
    pub title: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub struct HistoryNavigationRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
}

impl HistoryNavigationRequest {
    pub const fn new(session_id: SessionId, page_id: PageId) -> Self {
        Self {
            session_id,
            page_id,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct HistoryNavigationResult {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub url: String,
    pub title: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct TextInputRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub text: String,
}

impl TextInputRequest {
    pub fn new(session_id: SessionId, page_id: PageId, text: impl Into<String>) -> Self {
        Self {
            session_id,
            page_id,
            text: text.into(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct KeyPressRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub key: String,
}

impl KeyPressRequest {
    pub fn new(session_id: SessionId, page_id: PageId, key: impl Into<String>) -> Self {
        Self {
            session_id,
            page_id,
            key: key.into(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct InputResult {
    pub session_id: SessionId,
    pub page_id: PageId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct InteractionSettleResult {
    pub url: String,
    pub title: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub download: Option<DownloadInfo>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub downloads: Vec<DownloadInfo>,
}

impl InteractionSettleResult {
    pub fn new(url: impl Into<String>, title: Option<String>) -> Self {
        Self {
            url: url.into(),
            title,
            download: None,
            downloads: Vec::new(),
        }
    }

    pub fn with_download(mut self, download: DownloadInfo) -> Self {
        self.download = Some(download.clone());
        self.downloads.push(download);
        self
    }

    pub fn with_downloads(mut self, downloads: Vec<DownloadInfo>) -> Self {
        if let Some(download) = downloads.last() {
            self.download = Some(download.clone());
        }
        self.downloads.extend(downloads);
        self
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct DownloadInfo {
    pub path: PathBuf,
    pub suggested_filename: Option<String>,
    pub status: DownloadStatus,
}

impl DownloadInfo {
    pub fn completed(path: PathBuf, suggested_filename: Option<String>) -> Self {
        Self {
            path,
            suggested_filename,
            status: DownloadStatus::Completed,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum DownloadStatus {
    Completed,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct FocusSelectorRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub selector: String,
}

impl FocusSelectorRequest {
    pub fn new(session_id: SessionId, page_id: PageId, selector: impl Into<String>) -> Self {
        Self {
            session_id,
            page_id,
            selector: selector.into(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub struct FocusHintRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub hint_id: u32,
}

impl FocusHintRequest {
    pub const fn new(session_id: SessionId, page_id: PageId, hint_id: u32) -> Self {
        Self {
            session_id,
            page_id,
            hint_id,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub struct ClickHintRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub hint_id: u32,
}

impl ClickHintRequest {
    pub const fn new(session_id: SessionId, page_id: PageId, hint_id: u32) -> Self {
        Self {
            session_id,
            page_id,
            hint_id,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub struct RightClickHintRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub hint_id: u32,
}

impl RightClickHintRequest {
    pub const fn new(session_id: SessionId, page_id: PageId, hint_id: u32) -> Self {
        Self {
            session_id,
            page_id,
            hint_id,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub struct HoverHintRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub hint_id: u32,
}

impl HoverHintRequest {
    pub const fn new(session_id: SessionId, page_id: PageId, hint_id: u32) -> Self {
        Self {
            session_id,
            page_id,
            hint_id,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct SelectHintRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub hint_id: u32,
    pub choice: String,
}

impl SelectHintRequest {
    pub fn new(
        session_id: SessionId,
        page_id: PageId,
        hint_id: u32,
        choice: impl Into<String>,
    ) -> Self {
        Self {
            session_id,
            page_id,
            hint_id,
            choice: choice.into(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct UploadHintRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub hint_id: u32,
    pub paths: Vec<PathBuf>,
}

impl UploadHintRequest {
    pub fn new(session_id: SessionId, page_id: PageId, hint_id: u32, paths: Vec<PathBuf>) -> Self {
        Self {
            session_id,
            page_id,
            hint_id,
            paths,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub struct ToggleHintRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub hint_id: u32,
}

impl ToggleHintRequest {
    pub const fn new(session_id: SessionId, page_id: PageId, hint_id: u32) -> Self {
        Self {
            session_id,
            page_id,
            hint_id,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct ClickPointRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub x: f64,
    pub y: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct DragPointRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub start_x: f64,
    pub start_y: f64,
    pub end_x: f64,
    pub end_y: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct RightClickPointRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub x: f64,
    pub y: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct HoverPointRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub x: f64,
    pub y: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct WheelPointRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub x: f64,
    pub y: f64,
    pub delta_x: f64,
    pub delta_y: f64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct FindTextRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub query: String,
    pub backwards: bool,
}

impl FindTextRequest {
    pub fn new(session_id: SessionId, page_id: PageId, query: impl Into<String>) -> Self {
        Self {
            session_id,
            page_id,
            query: query.into(),
            backwards: false,
        }
    }

    pub const fn backwards(mut self, backwards: bool) -> Self {
        self.backwards = backwards;
        self
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct FindTextResult {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub query: String,
    pub backwards: bool,
    pub found: bool,
    pub match_count: Option<u32>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub struct PageTextRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
}

impl PageTextRequest {
    pub const fn new(session_id: SessionId, page_id: PageId) -> Self {
        Self {
            session_id,
            page_id,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct PageTextSnapshot {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub url: String,
    pub title: Option<String>,
    pub text: String,
    pub truncated: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub struct SelectionTextRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
}

impl SelectionTextRequest {
    pub const fn new(session_id: SessionId, page_id: PageId) -> Self {
        Self {
            session_id,
            page_id,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct SelectionTextResult {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub text: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub struct ElementHintsRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
}

impl ElementHintsRequest {
    pub const fn new(session_id: SessionId, page_id: PageId) -> Self {
        Self {
            session_id,
            page_id,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ElementHintKind {
    Link,
    Button,
    Input,
    File,
    TextArea,
    Select,
    Checkbox,
    Radio,
    Editable,
    Other,
}

#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub struct SelectOptionHint {
    pub value: String,
    pub label: String,
    pub disabled: bool,
    pub selected: bool,
}

#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub struct ElementHint {
    pub id: u32,
    pub kind: ElementHintKind,
    pub label: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub href: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub checked: Option<bool>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub options: Vec<SelectOptionHint>,
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
    pub clickable: bool,
    pub focusable: bool,
}

impl ClickPointRequest {
    pub const fn new(session_id: SessionId, page_id: PageId, x: f64, y: f64) -> Self {
        Self {
            session_id,
            page_id,
            x,
            y,
        }
    }
}

impl DragPointRequest {
    pub const fn new(
        session_id: SessionId,
        page_id: PageId,
        start_x: f64,
        start_y: f64,
        end_x: f64,
        end_y: f64,
    ) -> Self {
        Self {
            session_id,
            page_id,
            start_x,
            start_y,
            end_x,
            end_y,
        }
    }
}

impl RightClickPointRequest {
    pub const fn new(session_id: SessionId, page_id: PageId, x: f64, y: f64) -> Self {
        Self {
            session_id,
            page_id,
            x,
            y,
        }
    }
}

impl HoverPointRequest {
    pub const fn new(session_id: SessionId, page_id: PageId, x: f64, y: f64) -> Self {
        Self {
            session_id,
            page_id,
            x,
            y,
        }
    }
}

impl WheelPointRequest {
    pub const fn new(
        session_id: SessionId,
        page_id: PageId,
        x: f64,
        y: f64,
        delta_x: f64,
        delta_y: f64,
    ) -> Self {
        Self {
            session_id,
            page_id,
            x,
            y,
            delta_x,
            delta_y,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub struct ShutdownResult {}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RendererError {
    kind: RendererErrorKind,
    message: String,
}

impl RendererError {
    pub fn new(kind: RendererErrorKind, message: impl Into<String>) -> Self {
        Self {
            kind,
            message: message.into(),
        }
    }

    pub const fn kind(&self) -> RendererErrorKind {
        self.kind
    }

    pub fn message(&self) -> &str {
        &self.message
    }
}

impl std::fmt::Display for RendererError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(formatter, "{:?}: {}", self.kind, self.message)
    }
}

impl std::error::Error for RendererError {}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RendererErrorKind {
    InvalidState,
    BackendUnavailable,
    NavigationFailed,
    RenderFailed,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::session::{FrameId, FrameMetadata, PageId, SessionId, Viewport};

    struct FakeRenderer {
        current_url: Option<String>,
        settled: bool,
        shutdown: bool,
    }

    impl FakeRenderer {
        fn new() -> Self {
            Self {
                current_url: None,
                settled: false,
                shutdown: false,
            }
        }
    }

    impl Renderer for FakeRenderer {
        fn navigate(
            &mut self,
            request: NavigateRequest,
        ) -> Result<NavigationResult, RendererError> {
            self.current_url = Some(request.url.clone());
            Ok(NavigationResult {
                session_id: request.session_id,
                page_id: request.page_id,
                url: request.url,
                title: Some("Example Domain".to_string()),
            })
        }

        fn render_frame(
            &mut self,
            request: RenderFrameRequest,
        ) -> Result<RenderedFrame, RendererError> {
            let url = self.current_url.clone().ok_or_else(|| {
                RendererError::new(
                    RendererErrorKind::InvalidState,
                    "no page has been navigated",
                )
            })?;
            Ok(RenderedFrame {
                metadata: FrameMetadata::new(
                    FrameId::new(1),
                    request.session_id,
                    request.page_id,
                    url,
                    Some("Example Domain".to_string()),
                    request.viewport,
                    1000,
                ),
                artifact: FrameArtifact::Png(vec![1, 2, 3]),
            })
        }

        fn scroll(&mut self, request: ScrollRequest) -> Result<ScrollResult, RendererError> {
            Ok(ScrollResult {
                session_id: request.session_id,
                page_id: request.page_id,
                delta_x: request.delta_x,
                delta_y: request.delta_y,
            })
        }

        fn zoom(&mut self, request: ZoomRequest) -> Result<ZoomResult, RendererError> {
            Ok(ZoomResult {
                session_id: request.session_id,
                page_id: request.page_id,
                scale: request.scale,
            })
        }

        fn reload(&mut self, request: ReloadRequest) -> Result<ReloadResult, RendererError> {
            Ok(ReloadResult {
                session_id: request.session_id,
                page_id: request.page_id,
                url: "https://example.com".to_string(),
                title: Some("Example Domain".to_string()),
            })
        }

        fn go_back(
            &mut self,
            request: HistoryNavigationRequest,
        ) -> Result<HistoryNavigationResult, RendererError> {
            self.current_url = Some("https://example.com/back".to_string());
            Ok(HistoryNavigationResult {
                session_id: request.session_id,
                page_id: request.page_id,
                url: "https://example.com/back".to_string(),
                title: Some("Back".to_string()),
            })
        }

        fn go_forward(
            &mut self,
            request: HistoryNavigationRequest,
        ) -> Result<HistoryNavigationResult, RendererError> {
            self.current_url = Some("https://example.com/forward".to_string());
            Ok(HistoryNavigationResult {
                session_id: request.session_id,
                page_id: request.page_id,
                url: "https://example.com/forward".to_string(),
                title: Some("Forward".to_string()),
            })
        }

        fn input_text(&mut self, request: TextInputRequest) -> Result<InputResult, RendererError> {
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn press_key(&mut self, request: KeyPressRequest) -> Result<InputResult, RendererError> {
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn focus_selector(
            &mut self,
            request: FocusSelectorRequest,
        ) -> Result<InputResult, RendererError> {
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn focus_hint(&mut self, request: FocusHintRequest) -> Result<InputResult, RendererError> {
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn click_hint(&mut self, request: ClickHintRequest) -> Result<InputResult, RendererError> {
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn right_click_hint(
            &mut self,
            request: RightClickHintRequest,
        ) -> Result<InputResult, RendererError> {
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn hover_hint(&mut self, request: HoverHintRequest) -> Result<InputResult, RendererError> {
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn select_hint(
            &mut self,
            request: SelectHintRequest,
        ) -> Result<InputResult, RendererError> {
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn upload_hint(
            &mut self,
            request: UploadHintRequest,
        ) -> Result<InputResult, RendererError> {
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn toggle_hint(
            &mut self,
            request: ToggleHintRequest,
        ) -> Result<InputResult, RendererError> {
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn click_point(
            &mut self,
            request: ClickPointRequest,
        ) -> Result<InputResult, RendererError> {
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn drag_point(&mut self, request: DragPointRequest) -> Result<InputResult, RendererError> {
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn right_click_point(
            &mut self,
            request: RightClickPointRequest,
        ) -> Result<InputResult, RendererError> {
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn hover_point(
            &mut self,
            request: HoverPointRequest,
        ) -> Result<InputResult, RendererError> {
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn wheel_point(
            &mut self,
            request: WheelPointRequest,
        ) -> Result<InputResult, RendererError> {
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn find_text(&mut self, request: FindTextRequest) -> Result<FindTextResult, RendererError> {
            Ok(FindTextResult {
                session_id: request.session_id,
                page_id: request.page_id,
                query: request.query,
                backwards: request.backwards,
                found: true,
                match_count: Some(3),
            })
        }

        fn page_text(
            &mut self,
            request: PageTextRequest,
        ) -> Result<PageTextSnapshot, RendererError> {
            Ok(PageTextSnapshot {
                session_id: request.session_id,
                page_id: request.page_id,
                url: "https://example.com".to_string(),
                title: Some("Example".to_string()),
                text: "# Example\n\nExample body".to_string(),
                truncated: false,
            })
        }

        fn selection_text(
            &mut self,
            request: SelectionTextRequest,
        ) -> Result<SelectionTextResult, RendererError> {
            Ok(SelectionTextResult {
                session_id: request.session_id,
                page_id: request.page_id,
                text: "selected text".to_string(),
            })
        }

        fn settle_after_interaction(&mut self) -> Result<InteractionSettleResult, RendererError> {
            self.settled = true;
            Ok(InteractionSettleResult::new(
                "https://example.com",
                Some("Example Domain".to_string()),
            ))
        }

        fn shutdown(&mut self) -> Result<ShutdownResult, RendererError> {
            self.shutdown = true;
            Ok(ShutdownResult {})
        }
    }

    #[test]
    fn renderer_contract_supports_navigation_and_frame_capture() {
        let mut renderer = FakeRenderer::new();
        let session_id = SessionId::new(1);
        let page_id = PageId::new(2);
        let viewport = Viewport::new(800, 600);

        let navigation = renderer
            .navigate(NavigateRequest::new(
                session_id,
                page_id,
                "https://example.com",
            ))
            .expect("navigation should succeed");
        let frame = renderer
            .render_frame(RenderFrameRequest::new(session_id, page_id, viewport))
            .expect("frame should render");

        assert_eq!(navigation.session_id, session_id);
        assert_eq!(navigation.url, "https://example.com");
        assert_eq!(navigation.title, Some("Example Domain".to_string()));
        assert_eq!(frame.metadata.session_id, session_id);
        assert_eq!(frame.metadata.page_id, page_id);
        assert_eq!(frame.metadata.title, Some("Example Domain".to_string()));
        assert_eq!(frame.metadata.viewport, viewport);
        assert_eq!(frame.artifact, FrameArtifact::Png(vec![1, 2, 3]));
    }

    #[test]
    fn renderer_contract_supports_scroll_zoom_reload_and_shutdown() {
        let mut renderer = FakeRenderer::new();
        let session_id = SessionId::new(4);
        let page_id = PageId::new(3);

        let scroll = renderer
            .scroll(ScrollRequest::new(session_id, page_id, 0, 240))
            .expect("scroll should succeed");
        let zoom = renderer
            .zoom(ZoomRequest::new(session_id, page_id, 1.25))
            .expect("zoom should succeed");
        let reload = renderer
            .reload(ReloadRequest::new(session_id, page_id))
            .expect("reload should succeed");
        let back = renderer
            .go_back(HistoryNavigationRequest::new(session_id, page_id))
            .expect("back should succeed");
        let forward = renderer
            .go_forward(HistoryNavigationRequest::new(session_id, page_id))
            .expect("forward should succeed");
        let shutdown = renderer.shutdown();

        assert_eq!(scroll.session_id, session_id);
        assert_eq!(scroll.delta_y, 240);
        assert_eq!(zoom.session_id, session_id);
        assert_eq!(zoom.page_id, page_id);
        assert_eq!(zoom.scale, 1.25);
        assert_eq!(reload.session_id, session_id);
        assert_eq!(reload.page_id, page_id);
        assert_eq!(reload.url, "https://example.com");
        assert_eq!(reload.title, Some("Example Domain".to_string()));
        assert_eq!(back.session_id, session_id);
        assert_eq!(back.page_id, page_id);
        assert_eq!(back.url, "https://example.com/back");
        assert_eq!(back.title, Some("Back".to_string()));
        assert_eq!(forward.session_id, session_id);
        assert_eq!(forward.page_id, page_id);
        assert_eq!(forward.url, "https://example.com/forward");
        assert_eq!(forward.title, Some("Forward".to_string()));
        assert!(shutdown.is_ok());
        assert!(renderer.shutdown);
    }

    #[test]
    fn renderer_contract_supports_text_input_and_key_press() {
        let mut renderer = FakeRenderer::new();
        let session_id = SessionId::new(5);
        let page_id = PageId::new(8);

        let text = renderer
            .input_text(TextInputRequest::new(session_id, page_id, "hello"))
            .expect("text input should succeed");
        let key = renderer
            .press_key(KeyPressRequest::new(session_id, page_id, "Enter"))
            .expect("key press should succeed");

        assert_eq!(text.session_id, session_id);
        assert_eq!(text.page_id, page_id);
        assert_eq!(key.session_id, session_id);
        assert_eq!(key.page_id, page_id);
    }

    #[test]
    fn renderer_contract_supports_selector_focus_click_and_hover() {
        let mut renderer = FakeRenderer::new();
        let session_id = SessionId::new(6);
        let page_id = PageId::new(9);

        let focus = renderer
            .focus_selector(FocusSelectorRequest::new(
                session_id,
                page_id,
                "input[name=q]",
            ))
            .expect("selector focus should succeed");
        let click = renderer
            .click_point(ClickPointRequest::new(session_id, page_id, 12.5, 24.25))
            .expect("point click should succeed");
        let right_click = renderer
            .right_click_point(RightClickPointRequest::new(
                session_id, page_id, 12.5, 24.25,
            ))
            .expect("point right click should succeed");
        let hover = renderer
            .hover_point(HoverPointRequest::new(session_id, page_id, 12.5, 24.25))
            .expect("point hover should succeed");
        let wheel = renderer
            .wheel_point(WheelPointRequest::new(
                session_id, page_id, 12.5, 24.25, 0.0, 120.0,
            ))
            .expect("point wheel should succeed");
        let drag = renderer
            .drag_point(DragPointRequest::new(
                session_id, page_id, 12.5, 24.25, 72.0, 24.25,
            ))
            .expect("point drag should succeed");
        let focus_hint = renderer
            .focus_hint(FocusHintRequest::new(session_id, page_id, 2))
            .expect("hint focus should succeed");
        let click_hint = renderer
            .click_hint(ClickHintRequest::new(session_id, page_id, 2))
            .expect("hint click should succeed");
        let right_click_hint = renderer
            .right_click_hint(RightClickHintRequest::new(session_id, page_id, 2))
            .expect("hint right click should succeed");
        let hover_hint = renderer
            .hover_hint(HoverHintRequest::new(session_id, page_id, 2))
            .expect("hint hover should succeed");
        let select_hint = renderer
            .select_hint(SelectHintRequest::new(session_id, page_id, 2, "Canada"))
            .expect("hint select should succeed");
        let toggle_hint = renderer
            .toggle_hint(ToggleHintRequest::new(session_id, page_id, 2))
            .expect("hint toggle should succeed");

        assert_eq!(focus.session_id, session_id);
        assert_eq!(focus.page_id, page_id);
        assert_eq!(focus_hint.session_id, session_id);
        assert_eq!(focus_hint.page_id, page_id);
        assert_eq!(click_hint.session_id, session_id);
        assert_eq!(click_hint.page_id, page_id);
        assert_eq!(right_click_hint.session_id, session_id);
        assert_eq!(right_click_hint.page_id, page_id);
        assert_eq!(hover_hint.session_id, session_id);
        assert_eq!(hover_hint.page_id, page_id);
        assert_eq!(select_hint.session_id, session_id);
        assert_eq!(select_hint.page_id, page_id);
        assert_eq!(toggle_hint.session_id, session_id);
        assert_eq!(toggle_hint.page_id, page_id);
        assert_eq!(click.session_id, session_id);
        assert_eq!(click.page_id, page_id);
        assert_eq!(right_click.session_id, session_id);
        assert_eq!(right_click.page_id, page_id);
        assert_eq!(hover.session_id, session_id);
        assert_eq!(hover.page_id, page_id);
        assert_eq!(wheel.session_id, session_id);
        assert_eq!(wheel.page_id, page_id);
        assert_eq!(drag.session_id, session_id);
        assert_eq!(drag.page_id, page_id);
    }

    #[test]
    fn renderer_contract_supports_find_text() {
        let mut renderer = FakeRenderer::new();
        let session_id = SessionId::new(7);
        let page_id = PageId::new(10);

        let find = renderer
            .find_text(FindTextRequest::new(session_id, page_id, "needle").backwards(true))
            .expect("find text should succeed");

        assert_eq!(find.session_id, session_id);
        assert_eq!(find.page_id, page_id);
        assert_eq!(find.query, "needle");
        assert!(find.backwards);
        assert!(find.found);
        assert_eq!(find.match_count, Some(3));
    }

    #[test]
    fn renderer_contract_supports_page_text_snapshot() {
        let mut renderer = FakeRenderer::new();
        let session_id = SessionId::new(7);
        let page_id = PageId::new(10);

        let snapshot = renderer
            .page_text(PageTextRequest::new(session_id, page_id))
            .expect("page text should succeed");

        assert_eq!(snapshot.session_id, session_id);
        assert_eq!(snapshot.page_id, page_id);
        assert_eq!(snapshot.title.as_deref(), Some("Example"));
        assert_eq!(snapshot.url, "https://example.com");
        assert!(snapshot.text.contains("Example body"));
    }

    #[test]
    fn renderer_contract_supports_selection_text() {
        let mut renderer = FakeRenderer::new();
        let session_id = SessionId::new(7);
        let page_id = PageId::new(10);

        let selection = renderer
            .selection_text(SelectionTextRequest::new(session_id, page_id))
            .expect("selection text should succeed");

        assert_eq!(selection.session_id, session_id);
        assert_eq!(selection.page_id, page_id);
        assert_eq!(selection.text, "selected text");
    }

    #[test]
    fn renderer_contract_supports_element_hints() {
        let mut renderer = FakeRenderer::new();
        let session_id = SessionId::new(1);
        let page_id = PageId::new(1);

        let hints = renderer
            .element_hints(ElementHintsRequest::new(session_id, page_id))
            .expect("default element hints should succeed");

        assert!(hints.is_empty());

        let hint = ElementHint {
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
        };
        let json = serde_json::to_string(&hint).expect("hint should serialize");
        assert!(json.contains(r#""kind":"link""#));
        assert!(!json.contains("checked"));
        let checkbox = ElementHint {
            id: 2,
            kind: ElementHintKind::Checkbox,
            label: "Subscribe".to_string(),
            href: None,
            checked: Some(true),
            options: Vec::new(),
            x: 10.0,
            y: 20.0,
            width: 16.0,
            height: 16.0,
            clickable: true,
            focusable: true,
        };
        let checkbox_json =
            serde_json::to_string(&checkbox).expect("checkbox hint should serialize");
        assert!(checkbox_json.contains(r#""kind":"checkbox""#));
        assert!(checkbox_json.contains(r#""checked":true"#));
        assert!(json.contains(r#""label":"Docs""#));
        assert!(json.contains(r#""href":"https://example.com/docs""#));

        let select = ElementHint {
            id: 3,
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
                    disabled: true,
                    selected: true,
                },
            ],
            x: 20.0,
            y: 30.0,
            width: 120.0,
            height: 24.0,
            clickable: true,
            focusable: true,
        };
        let select_json = serde_json::to_string(&select).expect("select hint should serialize");
        assert!(select_json.contains(r#""kind":"select""#));
        assert!(
            select_json.contains(r#""options":["#),
            "select hint should include option metadata"
        );
        assert!(select_json.contains(r#""value":"jp""#));
        assert!(select_json.contains(r#""label":"Japan""#));
        assert!(select_json.contains(r#""disabled":true"#));
        assert!(select_json.contains(r#""selected":true"#));

        let file = ElementHint {
            id: 4,
            kind: ElementHintKind::File,
            label: "Avatar".to_string(),
            href: None,
            checked: None,
            options: Vec::new(),
            x: 40.0,
            y: 50.0,
            width: 160.0,
            height: 32.0,
            clickable: true,
            focusable: true,
        };
        let file_json = serde_json::to_string(&file).expect("file hint should serialize");
        assert!(file_json.contains(r#""kind":"file""#));
    }

    #[test]
    fn element_hint_deserializes_without_href() {
        let hint: ElementHint = serde_json::from_str(
            r#"{"id":1,"kind":"link","label":"Docs","x":120.5,"y":240.0,"width":80.0,"height":24.0,"clickable":true,"focusable":false}"#,
        )
        .expect("legacy hint JSON without href should deserialize");

        assert_eq!(hint.label, "Docs");
        assert_eq!(hint.href, None);
    }

    #[test]
    fn renderer_contract_supports_interaction_settle() {
        let mut renderer = FakeRenderer::new();

        let settled = renderer
            .settle_after_interaction()
            .expect("interaction settle should succeed");

        assert!(renderer.settled);
        assert_eq!(settled.url, "https://example.com");
    }
}
