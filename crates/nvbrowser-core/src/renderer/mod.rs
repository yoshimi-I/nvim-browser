pub mod chromium;

use serde::Serialize;

use crate::session::{FrameMetadata, PageId, SessionId, Viewport};

pub trait Renderer {
    fn navigate(&mut self, request: NavigateRequest) -> Result<NavigationResult, RendererError>;

    fn render_frame(&mut self, request: RenderFrameRequest)
        -> Result<RenderedFrame, RendererError>;

    fn scroll(&mut self, request: ScrollRequest) -> Result<ScrollResult, RendererError>;

    fn reload(&mut self, request: ReloadRequest) -> Result<ReloadResult, RendererError>;

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

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub struct ReloadResult {
    pub session_id: SessionId,
    pub page_id: PageId,
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
        shutdown: bool,
    }

    impl FakeRenderer {
        fn new() -> Self {
            Self {
                current_url: None,
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
            })
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
        let shutdown = renderer.shutdown();

        assert_eq!(scroll.session_id, session_id);
        assert_eq!(scroll.delta_y, 240);
        assert_eq!(reload.session_id, session_id);
        assert_eq!(reload.page_id, page_id);
        assert!(shutdown.is_ok());
        assert!(renderer.shutdown);
    }
}
