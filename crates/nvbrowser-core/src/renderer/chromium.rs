use std::{
    path::{Path, PathBuf},
    sync::Arc,
    thread,
    time::{Duration, SystemTime, UNIX_EPOCH},
};

use headless_chrome::{
    browser::tab::{point::Point, Tab},
    protocol::cdp::Page::CaptureScreenshotFormatOption,
    types::Bounds,
    Browser, LaunchOptions,
};

use crate::{
    renderer::{
        ClickPointRequest, FocusSelectorRequest, FrameArtifact, InputResult,
        InteractionSettleResult, KeyPressRequest, NavigateRequest, NavigationResult, ReloadRequest,
        ReloadResult, RenderFrameRequest, RenderedFrame, Renderer, RendererError,
        RendererErrorKind, ScrollRequest, ScrollResult, ShutdownResult, TextInputRequest,
    },
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

pub struct ChromiumRenderer {
    _browser: Browser,
    tab: Arc<Tab>,
    current_url: Option<String>,
    next_frame_id: u64,
}

impl ChromiumRenderer {
    pub fn launch(viewport: Viewport, options: ChromiumOptions) -> Result<Self, RendererError> {
        let binary = options.binary.ok_or_else(|| {
            RendererError::new(
                RendererErrorKind::BackendUnavailable,
                "Chrome/Chromium binary was not found; set NVBROWSER_CHROME",
            )
        })?;

        let browser = launch_browser(&binary, viewport)?;
        let tab = browser.new_tab().map_err(render_error)?;
        resize_tab(&tab, viewport)?;

        Ok(Self {
            _browser: browser,
            tab,
            current_url: None,
            next_frame_id: 1,
        })
    }

    fn next_frame_metadata(
        &mut self,
        session_id: SessionId,
        page_id: PageId,
        viewport: Viewport,
    ) -> Result<FrameMetadata, RendererError> {
        let url = self.current_url.clone().ok_or_else(|| {
            RendererError::new(
                RendererErrorKind::InvalidState,
                "cannot capture before navigation",
            )
        })?;
        let frame_id = FrameId::new(self.next_frame_id);
        self.next_frame_id += 1;
        Ok(FrameMetadata::new(
            frame_id,
            session_id,
            page_id,
            url,
            viewport,
            unix_time_ms(),
        ))
    }
}

impl Renderer for ChromiumRenderer {
    fn navigate(&mut self, request: NavigateRequest) -> Result<NavigationResult, RendererError> {
        self.tab
            .navigate_to(&request.url)
            .and_then(|tab| tab.wait_until_navigated())
            .map_err(render_error)?;
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
        resize_tab(&self.tab, request.viewport)?;
        let png = self
            .tab
            .capture_screenshot(CaptureScreenshotFormatOption::Png, None, None, true)
            .map_err(render_error)?;
        let metadata =
            self.next_frame_metadata(request.session_id, request.page_id, request.viewport)?;

        Ok(RenderedFrame {
            metadata,
            artifact: FrameArtifact::Png(png),
        })
    }

    fn scroll(&mut self, request: ScrollRequest) -> Result<ScrollResult, RendererError> {
        self.tab
            .evaluate(
                &format!("window.scrollBy({}, {})", request.delta_x, request.delta_y),
                false,
            )
            .map_err(render_error)?;

        Ok(ScrollResult {
            session_id: request.session_id,
            page_id: request.page_id,
            delta_x: request.delta_x,
            delta_y: request.delta_y,
        })
    }

    fn reload(&mut self, request: ReloadRequest) -> Result<ReloadResult, RendererError> {
        self.tab.reload(false, None).map_err(render_error)?;
        self.tab.wait_until_navigated().map_err(render_error)?;
        Ok(ReloadResult {
            session_id: request.session_id,
            page_id: request.page_id,
        })
    }

    fn input_text(&mut self, request: TextInputRequest) -> Result<InputResult, RendererError> {
        self.tab.type_str(&request.text).map_err(render_error)?;
        Ok(InputResult {
            session_id: request.session_id,
            page_id: request.page_id,
        })
    }

    fn press_key(&mut self, request: KeyPressRequest) -> Result<InputResult, RendererError> {
        self.tab.press_key(&request.key).map_err(render_error)?;
        Ok(InputResult {
            session_id: request.session_id,
            page_id: request.page_id,
        })
    }

    fn focus_selector(
        &mut self,
        request: FocusSelectorRequest,
    ) -> Result<InputResult, RendererError> {
        let element = self
            .tab
            .find_element(&request.selector)
            .map_err(render_error)?;
        element.focus().map_err(render_error)?;
        Ok(InputResult {
            session_id: request.session_id,
            page_id: request.page_id,
        })
    }

    fn click_point(&mut self, request: ClickPointRequest) -> Result<InputResult, RendererError> {
        self.tab
            .click_point(Point {
                x: request.x,
                y: request.y,
            })
            .map_err(render_error)?;
        Ok(InputResult {
            session_id: request.session_id,
            page_id: request.page_id,
        })
    }

    fn settle_after_interaction(&mut self) -> Result<InteractionSettleResult, RendererError> {
        thread::sleep(Duration::from_millis(75));
        self.tab.wait_until_navigated().map_err(render_error)?;
        let url = self.tab.get_url();
        self.current_url = Some(url.clone());
        Ok(InteractionSettleResult::new(url))
    }

    fn shutdown(&mut self) -> Result<ShutdownResult, RendererError> {
        let _ = self.tab.close(false);
        Ok(ShutdownResult {})
    }
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

fn resize_tab(tab: &Tab, viewport: Viewport) -> Result<(), RendererError> {
    tab.set_bounds(Bounds::Normal {
        left: None,
        top: None,
        width: Some(viewport.width.into()),
        height: Some(viewport.height.into()),
    })
    .map_err(render_error)?;
    Ok(())
}

fn unix_time_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis() as u64)
        .unwrap_or(0)
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

    #[test]
    fn unix_time_ms_returns_nonzero_timestamp() {
        assert!(unix_time_ms() > 0);
    }
}
