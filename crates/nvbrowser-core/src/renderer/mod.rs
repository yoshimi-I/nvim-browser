pub mod chromium;

use serde::Serialize;

use crate::session::{FrameMetadata, PageId, SessionId, Viewport};

pub trait Renderer {
    fn navigate(&mut self, request: NavigateRequest) -> Result<NavigationResult, RendererError>;

    fn render_frame(&mut self, request: RenderFrameRequest)
        -> Result<RenderedFrame, RendererError>;

    fn scroll(&mut self, request: ScrollRequest) -> Result<ScrollResult, RendererError>;

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

    fn click_point(&mut self, request: ClickPointRequest) -> Result<InputResult, RendererError>;

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
}

impl InteractionSettleResult {
    pub fn new(url: impl Into<String>) -> Self {
        Self { url: url.into() }
    }
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

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct ClickPointRequest {
    pub session_id: SessionId,
    pub page_id: PageId,
    pub x: f64,
    pub y: f64,
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

        fn reload(&mut self, request: ReloadRequest) -> Result<ReloadResult, RendererError> {
            Ok(ReloadResult {
                session_id: request.session_id,
                page_id: request.page_id,
                url: "https://example.com".to_string(),
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

        fn click_point(
            &mut self,
            request: ClickPointRequest,
        ) -> Result<InputResult, RendererError> {
            Ok(InputResult {
                session_id: request.session_id,
                page_id: request.page_id,
            })
        }

        fn settle_after_interaction(&mut self) -> Result<InteractionSettleResult, RendererError> {
            self.settled = true;
            Ok(InteractionSettleResult::new("https://example.com"))
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
        assert_eq!(frame.metadata.session_id, session_id);
        assert_eq!(frame.metadata.page_id, page_id);
        assert_eq!(frame.metadata.viewport, viewport);
        assert_eq!(frame.artifact, FrameArtifact::Png(vec![1, 2, 3]));
    }

    #[test]
    fn renderer_contract_supports_scroll_reload_and_shutdown() {
        let mut renderer = FakeRenderer::new();
        let session_id = SessionId::new(4);
        let page_id = PageId::new(3);

        let scroll = renderer
            .scroll(ScrollRequest::new(session_id, page_id, 0, 240))
            .expect("scroll should succeed");
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
        assert_eq!(reload.session_id, session_id);
        assert_eq!(reload.page_id, page_id);
        assert_eq!(reload.url, "https://example.com");
        assert_eq!(back.session_id, session_id);
        assert_eq!(back.page_id, page_id);
        assert_eq!(back.url, "https://example.com/back");
        assert_eq!(forward.session_id, session_id);
        assert_eq!(forward.page_id, page_id);
        assert_eq!(forward.url, "https://example.com/forward");
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
    fn renderer_contract_supports_selector_focus_and_point_click() {
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

        assert_eq!(focus.session_id, session_id);
        assert_eq!(focus.page_id, page_id);
        assert_eq!(click.session_id, session_id);
        assert_eq!(click.page_id, page_id);
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
