use serde::Serialize;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize)]
pub struct SessionId(u64);

impl SessionId {
    pub const fn new(value: u64) -> Self {
        Self(value)
    }

    pub const fn get(self) -> u64 {
        self.0
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize)]
pub struct PageId(u64);

impl PageId {
    pub const fn new(value: u64) -> Self {
        Self(value)
    }

    pub const fn get(self) -> u64 {
        self.0
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize)]
pub struct FrameId(u64);

impl FrameId {
    pub const fn new(value: u64) -> Self {
        Self(value)
    }

    pub const fn get(self) -> u64 {
        self.0
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct Viewport {
    pub width: u32,
    pub height: u32,
    pub device_scale_factor: f32,
}

impl Viewport {
    pub const fn new(width: u32, height: u32) -> Self {
        Self {
            width,
            height,
            device_scale_factor: 1.0,
        }
    }

    pub const fn with_scale(width: u32, height: u32, device_scale_factor: f32) -> Self {
        Self {
            width,
            height,
            device_scale_factor,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum LoadingState {
    Idle,
    Loading,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct FrameMetadata {
    pub id: FrameId,
    pub session_id: SessionId,
    pub page_id: PageId,
    pub url: String,
    pub viewport: Viewport,
    pub captured_at_unix_ms: u64,
}

impl FrameMetadata {
    pub fn new(
        id: FrameId,
        session_id: SessionId,
        page_id: PageId,
        url: impl Into<String>,
        viewport: Viewport,
        captured_at_unix_ms: u64,
    ) -> Self {
        Self {
            id,
            session_id,
            page_id,
            url: url.into(),
            viewport,
            captured_at_unix_ms,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct PageState {
    id: PageId,
    url: Option<String>,
    loading_state: LoadingState,
    viewport: Viewport,
    last_frame: Option<FrameMetadata>,
}

impl PageState {
    pub fn new(id: PageId, viewport: Viewport) -> Self {
        Self {
            id,
            url: None,
            loading_state: LoadingState::Idle,
            viewport,
            last_frame: None,
        }
    }

    pub const fn id(&self) -> PageId {
        self.id
    }

    pub fn url(&self) -> Option<&str> {
        self.url.as_deref()
    }

    pub const fn loading_state(&self) -> LoadingState {
        self.loading_state
    }

    pub const fn viewport(&self) -> Viewport {
        self.viewport
    }

    pub fn last_frame(&self) -> Option<&FrameMetadata> {
        self.last_frame.as_ref()
    }

    fn navigate(&mut self, url: impl Into<String>) {
        self.url = Some(url.into());
        self.loading_state = LoadingState::Loading;
    }

    fn finish_load(&mut self) {
        self.loading_state = LoadingState::Idle;
    }

    fn update_viewport(&mut self, viewport: Viewport) {
        self.viewport = viewport;
    }

    fn set_frame(&mut self, frame: FrameMetadata) {
        self.last_frame = Some(frame);
    }
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct BrowserSession {
    id: SessionId,
    active_page_id: PageId,
    active_page: PageState,
}

impl BrowserSession {
    pub fn new(id: SessionId, viewport: Viewport) -> Self {
        let active_page_id = PageId::new(1);
        Self {
            id,
            active_page_id,
            active_page: PageState::new(active_page_id, viewport),
        }
    }

    pub const fn id(&self) -> SessionId {
        self.id
    }

    pub const fn active_page_id(&self) -> PageId {
        self.active_page_id
    }

    pub const fn active_page(&self) -> &PageState {
        &self.active_page
    }

    pub fn navigate_active_page(&mut self, url: impl Into<String>) {
        self.active_page.navigate(url);
    }

    pub fn finish_active_page_load(&mut self) {
        self.active_page.finish_load();
    }

    pub fn update_active_viewport(&mut self, viewport: Viewport) {
        self.active_page.update_viewport(viewport);
    }

    pub fn set_active_page_frame(&mut self, frame: FrameMetadata) {
        self.active_page.set_frame(frame);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn session_starts_with_one_blank_page() {
        let session = BrowserSession::new(SessionId::new(7), Viewport::new(800, 600));

        assert_eq!(session.id(), SessionId::new(7));
        assert_eq!(session.active_page_id(), PageId::new(1));
        assert_eq!(session.active_page().url(), None);
        assert_eq!(session.active_page().loading_state(), LoadingState::Idle);
        assert_eq!(session.active_page().viewport(), Viewport::new(800, 600));
        assert_eq!(session.active_page().last_frame(), None);
    }

    #[test]
    fn page_state_tracks_navigation_loading_and_frames() {
        let mut session = BrowserSession::new(SessionId::new(1), Viewport::new(1024, 768));

        session.navigate_active_page("https://example.com");
        assert_eq!(session.active_page().url(), Some("https://example.com"));
        assert_eq!(session.active_page().loading_state(), LoadingState::Loading);

        session.finish_active_page_load();
        assert_eq!(session.active_page().loading_state(), LoadingState::Idle);

        let frame = FrameMetadata::new(
            FrameId::new(10),
            session.id(),
            session.active_page_id(),
            "https://example.com",
            Viewport::new(1024, 768),
            1234,
        );
        session.set_active_page_frame(frame.clone());

        assert_eq!(session.active_page().last_frame(), Some(&frame));
    }

    #[test]
    fn active_viewport_can_be_updated() {
        let mut session = BrowserSession::new(SessionId::new(1), Viewport::new(800, 600));

        session.update_active_viewport(Viewport::new(1280, 720));

        assert_eq!(session.active_page().viewport(), Viewport::new(1280, 720));
    }
}
