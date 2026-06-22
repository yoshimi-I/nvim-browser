use std::path::{Path, PathBuf};

use headless_chrome::{protocol::cdp::Page::CaptureScreenshotFormatOption, Browser, LaunchOptions};

use crate::{
    renderer::{FrameArtifact, RenderedFrame, RendererError, RendererErrorKind},
    session::{FrameId, FrameMetadata, PageId, SessionId, Viewport},
};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ChromiumOptions {
    pub binary: Option<PathBuf>,
}

impl ChromiumOptions {
    pub fn detect() -> Self {
        Self {
            binary: std::env::var_os("NVBROWSER_CHROME")
                .map(PathBuf::from)
                .or_else(default_chrome_binary),
        }
    }
}

pub fn default_chrome_binary() -> Option<PathBuf> {
    chrome_candidates().into_iter().find(|path| path.exists())
}

pub fn chrome_candidates() -> Vec<PathBuf> {
    vec![
        PathBuf::from("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"),
        PathBuf::from("/Applications/Chromium.app/Contents/MacOS/Chromium"),
        PathBuf::from("/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"),
        PathBuf::from("/usr/bin/google-chrome"),
        PathBuf::from("/usr/bin/chromium"),
        PathBuf::from("/usr/bin/chromium-browser"),
    ]
}

pub fn render_url_png(
    url: &str,
    viewport: Viewport,
    options: ChromiumOptions,
) -> Result<RenderedFrame, RendererError> {
    let binary = options.binary.ok_or_else(|| {
        RendererError::new(
            RendererErrorKind::BackendUnavailable,
            "Chrome/Chromium binary was not found; set NVBROWSER_CHROME",
        )
    })?;

    let browser = launch_browser(&binary, viewport)?;
    let tab = browser.new_tab().map_err(render_error)?;
    let png = tab
        .navigate_to(url)
        .and_then(|tab| tab.wait_until_navigated())
        .and_then(|tab| {
            tab.capture_screenshot(CaptureScreenshotFormatOption::Png, None, None, true)
        })
        .map_err(render_error)?;

    Ok(RenderedFrame {
        metadata: FrameMetadata::new(
            FrameId::new(1),
            SessionId::new(1),
            PageId::new(1),
            url,
            viewport,
            0,
        ),
        artifact: FrameArtifact::Png(png),
    })
}

fn launch_browser(binary: &Path, viewport: Viewport) -> Result<Browser, RendererError> {
    let options = LaunchOptions::default_builder()
        .path(Some(binary.to_path_buf()))
        .window_size(Some((viewport.width, viewport.height)))
        .sandbox(false)
        .build()
        .map_err(|error| {
            RendererError::new(
                RendererErrorKind::BackendUnavailable,
                format!("failed to build Chrome launch options: {error}"),
            )
        })?;

    Browser::new(options).map_err(|error| {
        RendererError::new(
            RendererErrorKind::BackendUnavailable,
            format!("failed to launch Chrome: {error}"),
        )
    })
}

fn render_error(error: impl std::fmt::Display) -> RendererError {
    RendererError::new(RendererErrorKind::RenderFailed, error.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn chrome_candidates_include_common_macos_and_linux_paths() {
        let candidates = chrome_candidates();

        assert!(candidates
            .iter()
            .any(|path| path.ends_with("Google Chrome.app/Contents/MacOS/Google Chrome")));
        assert!(candidates
            .iter()
            .any(|path| path == Path::new("/usr/bin/chromium")));
    }
}
