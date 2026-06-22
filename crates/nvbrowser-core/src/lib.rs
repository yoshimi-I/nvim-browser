pub mod markdown;
pub mod target;
pub mod terminal;

pub use markdown::render_markdown_document;
pub use target::{inspect_target, supports_direct_terminal_image, InspectResult, TargetKind};
pub use terminal::kitty::kitty_image_escape;
