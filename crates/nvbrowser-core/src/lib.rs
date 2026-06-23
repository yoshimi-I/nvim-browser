pub mod markdown;
pub mod renderer;
pub mod session;
pub mod target;
pub mod terminal;

pub use markdown::render_markdown_document;
pub use renderer::chromium::ChromiumRenderer;
pub use renderer::{
    ClickPointRequest, FocusSelectorRequest, FrameArtifact, HistoryNavigationRequest,
    HistoryNavigationResult, InputResult, InteractionSettleResult, KeyPressRequest,
    NavigateRequest, NavigationResult, ReloadRequest, ReloadResult, RenderFrameRequest,
    RenderedFrame, Renderer, RendererError, RendererErrorKind, ScrollRequest, ScrollResult,
    ShutdownResult, TextInputRequest,
};
pub use session::{
    BrowserSession, FrameId, FrameMetadata, LoadingState, PageId, PageState, SessionId, Viewport,
};
pub use target::{inspect_target, supports_direct_terminal_image, InspectResult, TargetKind};
pub use terminal::kitty::{
    kitty_image_escape, KittyImageDelete, KittyImagePlacement, KittyImageTransfer,
    KittyPlacementDelete,
};
