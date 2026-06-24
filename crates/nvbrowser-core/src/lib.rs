pub mod markdown;
pub mod renderer;
pub mod session;
pub mod target;
pub mod terminal;

pub use markdown::{render_markdown_document, render_markdown_document_with_base_url};
pub use renderer::chromium::{ChromiumBackendDiagnostics, ChromiumRenderer};
pub use renderer::{
    ClickHintRequest, ClickPointRequest, DialogAction, DialogEvent, DialogKind, DomEpochRequest,
    DownloadInfo, DownloadStatus, DragPointRequest, ElementHint, ElementHintKind,
    ElementHintsRequest, FindTextRequest, FindTextResult, FocusHintRequest, FocusSelectorRequest,
    FocusedElement, FocusedElementRequest, FrameArtifact, HistoryNavigationRequest,
    HistoryNavigationResult, HoverHintRequest, HoverPointRequest, InputResult,
    InteractionSettleResult, KeyPressRequest, NavigateRequest, NavigationResult, PageMetadata,
    PageMetadataRequest, PageMetrics, PageMetricsRequest, PageTextRequest, PageTextSnapshot,
    ReloadRequest, ReloadResult, RenderFrameRequest, RenderedFrame, Renderer, RendererError,
    RendererErrorKind, RightClickHintRequest, RightClickPointRequest, ScrollRequest, ScrollResult,
    SelectHintRequest, SelectOptionHint, SelectionTextRequest, SelectionTextResult, ShutdownResult,
    StopLoadingRequest, StopLoadingResult, TextInputRequest, ToggleHintRequest, UploadHintRequest,
    WheelPointRequest, ZoomRequest, ZoomResult,
};
pub use session::{
    BrowserSession, FrameId, FrameMetadata, LoadingState, PageId, PageState, SessionId, Viewport,
};
pub use target::{inspect_target, supports_direct_terminal_image, InspectResult, TargetKind};
pub use terminal::kitty::{
    kitty_image_escape, kitty_tiled_image_delete_escape, tmux_passthrough_escape, KittyImageDelete,
    KittyImagePlacement, KittyImageTransfer, KittyPlacementDelete,
};
