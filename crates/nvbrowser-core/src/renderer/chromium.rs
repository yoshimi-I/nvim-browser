use std::{
    collections::{HashMap, HashSet},
    ffi::OsStr,
    path::{Path, PathBuf},
    sync::{mpsc, Arc},
    thread,
    time::{Duration, SystemTime, UNIX_EPOCH},
};

#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;

use headless_chrome::{
    browser::tab::{point::Point, ModifierKey, Tab},
    protocol::cdp::types::{Event, Method},
    protocol::cdp::Page::{
        CaptureScreenshotFormatOption, DialogType, SetDownloadBehaviorBehaviorOption,
        Viewport as CdpViewport,
    },
    protocol::cdp::{Input, Page, DOM},
    types::Bounds,
    Browser, LaunchOptions,
};
use serde::{Deserialize, Serialize};

use crate::{
    renderer::{
        ClickHintRequest, ClickPointRequest, DialogAction, DialogEvent, DialogKind,
        DomEpochRequest, DownloadInfo, DragPointRequest, ElementHint, ElementHintsRequest,
        FindTextRequest, FindTextResult, FocusHintRequest, FocusSelectorRequest, FocusedElement,
        FocusedElementRequest, FrameArtifact, HistoryNavigationRequest, HistoryNavigationResult,
        HoverHintRequest, HoverPointRequest, InputResult, InteractionSettleResult, KeyPressRequest,
        NavigateRequest, NavigationResult, PageMetadata, PageMetadataRequest, PageMetrics,
        PageMetricsRequest, PageTextRequest, PageTextSnapshot, ReloadRequest, ReloadResult,
        RenderFrameRequest, RenderedFrame, Renderer, RendererError, RendererErrorKind,
        RightClickHintRequest, RightClickPointRequest, ScrollRequest, ScrollResult,
        SelectHintRequest, SelectionTextRequest, SelectionTextResult, ShutdownResult,
        TextInputRequest, ToggleHintRequest, UploadHintRequest, WheelPointRequest, ZoomRequest,
        ZoomResult,
    },
    session::{FrameId, FrameMetadata, PageId, SessionId, Viewport},
};

const INTERACTION_SETTLE_STABLE_SAMPLES: usize = 3;
pub const DEFAULT_NAVIGATION_TIMEOUT_MS: u64 = 20_000;
const BROWSER_IDLE_TIMEOUT: Duration = Duration::from_secs(24 * 60 * 60);

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ChromiumOptions {
    pub cdp_ws_url: Option<String>,
    pub binary: Option<PathBuf>,
    pub user_data_dir: Option<PathBuf>,
    pub download_dir: Option<PathBuf>,
    pub navigation_timeout_ms: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ChromiumBackendDiagnostics {
    pub status: String,
    pub source: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cdp_ws_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub chrome_binary: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub user_data_dir: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub warning: Option<String>,
}

impl ChromiumOptions {
    pub fn detect() -> Self {
        Self::from_env_values(
            std::env::var("NVBROWSER_CDP_WS_URL")
                .ok()
                .and_then(non_empty_string),
            std::env::var_os("NVBROWSER_CHROME")
                .map(PathBuf::from)
                .or_else(default_chrome_binary),
            std::env::var_os("NVBROWSER_USER_DATA_DIR").map(PathBuf::from),
            std::env::var_os("NVBROWSER_DOWNLOAD_DIR").map(PathBuf::from),
            std::env::var("NVBROWSER_NAVIGATION_TIMEOUT_MS").ok(),
        )
    }

    fn from_env_values(
        cdp_ws_url: Option<String>,
        binary: Option<PathBuf>,
        user_data_dir: Option<PathBuf>,
        download_dir: Option<PathBuf>,
        navigation_timeout_ms: Option<String>,
    ) -> Self {
        Self {
            cdp_ws_url,
            binary,
            user_data_dir: user_data_dir.and_then(non_empty_path),
            download_dir: download_dir.and_then(non_empty_path),
            navigation_timeout_ms: parse_navigation_timeout_ms(navigation_timeout_ms),
        }
    }

    pub fn backend_diagnostics(&self) -> ChromiumBackendDiagnostics {
        let chrome_binary = self
            .binary
            .as_ref()
            .map(|path| path.to_string_lossy().into_owned());
        let user_data_dir = self
            .user_data_dir
            .as_ref()
            .map(|path| path.to_string_lossy().into_owned());
        if let Some(cdp_ws_url) = self.cdp_ws_url.clone() {
            return ChromiumBackendDiagnostics {
                status: "available".to_string(),
                source: "cdp".to_string(),
                cdp_ws_url: Some(cdp_ws_url),
                chrome_binary,
                user_data_dir,
                warning: None,
            };
        }
        if let Some(chrome_binary) = chrome_binary.clone() {
            if self.binary.as_ref().is_some_and(is_executable_file) {
                return ChromiumBackendDiagnostics {
                    status: "available".to_string(),
                    source: "chrome".to_string(),
                    cdp_ws_url: None,
                    chrome_binary: Some(chrome_binary),
                    user_data_dir,
                    warning: None,
                };
            }
            return ChromiumBackendDiagnostics {
                status: "missing".to_string(),
                source: "none".to_string(),
                cdp_ws_url: None,
                chrome_binary: Some(chrome_binary),
                user_data_dir,
                warning: Some(
                    "Chrome binary is not executable; set NVBROWSER_CHROME to an existing Chrome/Chromium executable or set NVBROWSER_CDP_WS_URL"
                        .to_string(),
                ),
            };
        }
        ChromiumBackendDiagnostics {
            status: "missing".to_string(),
            source: "none".to_string(),
            cdp_ws_url: None,
            chrome_binary: None,
            user_data_dir,
            warning: Some(
                "Chrome/CDP backend was not found; set NVBROWSER_CDP_WS_URL or NVBROWSER_CHROME"
                    .to_string(),
            ),
        }
    }

    fn browser_source(&self) -> Result<BrowserSource, RendererError> {
        if let Some(cdp_ws_url) = self.cdp_ws_url.clone() {
            return Ok(BrowserSource::Connect(cdp_ws_url));
        }

        self.binary
            .clone()
            .map(BrowserSource::Launch)
            .ok_or_else(|| {
                RendererError::new(
                    RendererErrorKind::BackendUnavailable,
                    "Chrome/CDP backend was not found; set NVBROWSER_CDP_WS_URL or NVBROWSER_CHROME",
                )
            })
    }

    fn navigation_timeout(&self) -> Duration {
        Duration::from_millis(self.navigation_timeout_ms)
    }
}

#[cfg(unix)]
fn is_executable_file(path: &PathBuf) -> bool {
    std::fs::metadata(path)
        .map(|metadata| metadata.is_file() && metadata.permissions().mode() & 0o111 != 0)
        .unwrap_or(false)
}

#[cfg(not(unix))]
fn is_executable_file(path: &PathBuf) -> bool {
    path.is_file()
}

#[derive(Debug, Clone, PartialEq, Eq)]
enum BrowserSource {
    Connect(String),
    Launch(PathBuf),
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
    let browser = open_browser(&options, viewport)?;
    let tab = browser.new_tab().map_err(render_error)?;
    configure_tab_timeout(&tab, &options);
    install_default_dialog_handler(&tab, None)?;
    install_dom_epoch_observer(&tab)?;
    resize_tab(&tab, viewport)?;
    tab.navigate_to(url)
        .map_err(|error| navigation_start_error(url, error))?;
    wait_until_navigated(&tab, url, options.navigation_timeout_ms)?;
    let png = tab
        .capture_screenshot(
            CaptureScreenshotFormatOption::Png,
            None,
            Some(viewport_clip(viewport)),
            true,
        )
        .map_err(render_error)?;
    let url = tab.get_url();

    Ok(RenderedFrame {
        metadata: FrameMetadata::new(
            FrameId::new(1),
            SessionId::new(1),
            PageId::new(1),
            url,
            None,
            viewport,
            unix_time_ms(),
        ),
        artifact: FrameArtifact::Png(png),
    })
}

pub struct ChromiumRenderer {
    browser: Browser,
    tab: Arc<Tab>,
    known_target_ids: HashSet<String>,
    pending_page_target_ids: HashSet<String>,
    dialog_handler_target_ids: HashSet<String>,
    dialog_event_tx: mpsc::Sender<DialogEvent>,
    dialog_event_rx: mpsc::Receiver<DialogEvent>,
    suppress_target_registration_until: Option<std::time::Instant>,
    skip_next_target_adoption: bool,
    active_viewport: Viewport,
    current_url: Option<String>,
    current_title: Option<String>,
    current_zoom_scale: f64,
    next_frame_id: u64,
    navigation_timeout_ms: u64,
    download_dir: Option<PathBuf>,
    download_events: Option<DownloadEventTracker>,
    last_interaction_started: Option<SystemTime>,
}

struct DownloadEventTracker {
    rx: mpsc::Receiver<DownloadEvent>,
    filenames: HashMap<String, String>,
    known_paths: HashSet<PathBuf>,
}

enum DownloadEvent {
    WillBegin {
        guid: String,
        suggested_filename: String,
    },
    Completed {
        guid: String,
    },
}

impl ChromiumRenderer {
    pub fn launch(viewport: Viewport, options: ChromiumOptions) -> Result<Self, RendererError> {
        let browser = open_browser(&options, viewport)?;
        let tab = browser.new_tab().map_err(render_error)?;
        configure_tab_timeout(&tab, &options);
        let (dialog_event_tx, dialog_event_rx) = mpsc::channel::<DialogEvent>();
        install_default_dialog_handler(&tab, Some(dialog_event_tx.clone()))?;
        install_dom_epoch_observer(&tab)?;
        let download_events = configure_download_behavior(&tab, options.download_dir.as_deref())?;
        let dialog_handler_target_ids = HashSet::from([tab.get_target_id().clone()]);
        resize_tab(&tab, viewport)?;
        browser.register_missing_tabs();
        let known_target_ids = collect_tab_target_ids(&browser);

        Ok(Self {
            browser,
            tab,
            known_target_ids,
            pending_page_target_ids: HashSet::new(),
            dialog_handler_target_ids,
            dialog_event_tx,
            dialog_event_rx,
            suppress_target_registration_until: None,
            skip_next_target_adoption: false,
            active_viewport: viewport,
            current_url: None,
            current_title: None,
            current_zoom_scale: 1.0,
            next_frame_id: 1,
            navigation_timeout_ms: options.navigation_timeout_ms,
            download_dir: options.download_dir,
            download_events,
            last_interaction_started: None,
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
            self.current_title.clone(),
            viewport,
            unix_time_ms(),
        ))
    }
}

impl Renderer for ChromiumRenderer {
    fn navigate(&mut self, request: NavigateRequest) -> Result<NavigationResult, RendererError> {
        self.tab
            .navigate_to(&request.url)
            .map_err(|error| navigation_start_error(&request.url, error))?;
        wait_until_navigated(&self.tab, &request.url, self.navigation_timeout_ms)?;
        let url = self.tab.get_url();
        let title = self.read_current_title().unwrap_or(None);
        self.current_url = Some(url.clone());
        self.current_title = title.clone();
        self.refresh_known_target_ids();
        Ok(NavigationResult {
            session_id: request.session_id,
            page_id: request.page_id,
            url,
            title,
        })
    }

    fn render_frame(
        &mut self,
        request: RenderFrameRequest,
    ) -> Result<RenderedFrame, RendererError> {
        self.active_viewport = request.viewport;
        resize_tab(&self.tab, request.viewport)?;
        apply_page_zoom(&self.tab, request.viewport, self.current_zoom_scale)?;
        let png = self
            .tab
            .capture_screenshot(
                CaptureScreenshotFormatOption::Png,
                None,
                Some(viewport_clip(request.viewport)),
                true,
            )
            .map_err(render_error)?;
        self.current_url = Some(self.tab.get_url());
        if let Some(title) = self.read_current_title() {
            self.current_title = title;
        }
        self.refresh_known_target_ids();
        let metadata =
            self.next_frame_metadata(request.session_id, request.page_id, request.viewport)?;

        Ok(RenderedFrame {
            metadata,
            artifact: FrameArtifact::Png(png),
        })
    }

    fn scroll(&mut self, request: ScrollRequest) -> Result<ScrollResult, RendererError> {
        self.mark_interaction_start();
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

    fn zoom(&mut self, request: ZoomRequest) -> Result<ZoomResult, RendererError> {
        self.mark_interaction_start();
        if !request.scale.is_finite() || request.scale <= 0.0 {
            return Err(RendererError::new(
                RendererErrorKind::InvalidState,
                "page zoom scale must be a positive finite number",
            ));
        }
        apply_page_zoom(&self.tab, self.active_viewport, request.scale)?;
        self.current_zoom_scale = request.scale;
        Ok(ZoomResult {
            session_id: request.session_id,
            page_id: request.page_id,
            scale: request.scale,
        })
    }

    fn reload(&mut self, request: ReloadRequest) -> Result<ReloadResult, RendererError> {
        let requested_url = self
            .current_url
            .clone()
            .unwrap_or_else(|| self.tab.get_url());
        self.tab.reload(false, None).map_err(render_error)?;
        wait_until_navigated(&self.tab, &requested_url, self.navigation_timeout_ms)?;
        let url = self.tab.get_url();
        let title = self.read_current_title().unwrap_or(None);
        self.current_url = Some(url.clone());
        self.current_title = title.clone();
        Ok(ReloadResult {
            session_id: request.session_id,
            page_id: request.page_id,
            url,
            title,
        })
    }

    fn go_back(
        &mut self,
        request: HistoryNavigationRequest,
    ) -> Result<HistoryNavigationResult, RendererError> {
        self.navigate_history(request, HistoryDirection::Back)
    }

    fn go_forward(
        &mut self,
        request: HistoryNavigationRequest,
    ) -> Result<HistoryNavigationResult, RendererError> {
        self.navigate_history(request, HistoryDirection::Forward)
    }

    fn input_text(&mut self, request: TextInputRequest) -> Result<InputResult, RendererError> {
        self.mark_interaction_start();
        self.tab.type_str(&request.text).map_err(render_error)?;
        Ok(InputResult {
            session_id: request.session_id,
            page_id: request.page_id,
        })
    }

    fn press_key(&mut self, request: KeyPressRequest) -> Result<InputResult, RendererError> {
        self.mark_interaction_start();
        let (key, modifiers) = chromium_key_with_modifiers(&request.key);
        if modifiers.is_empty() {
            self.tab.press_key(key).map_err(render_error)?;
        } else {
            self.tab
                .press_key_with_modifiers(key, Some(&modifiers))
                .map_err(render_error)?;
        }
        Ok(InputResult {
            session_id: request.session_id,
            page_id: request.page_id,
        })
    }

    fn focus_selector(
        &mut self,
        request: FocusSelectorRequest,
    ) -> Result<InputResult, RendererError> {
        self.mark_interaction_start();
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

    fn focus_hint(&mut self, request: FocusHintRequest) -> Result<InputResult, RendererError> {
        self.mark_interaction_start();
        let hint_id = serde_json::to_string(&request.hint_id).map_err(render_error)?;
        let script = FOCUS_HINT_SCRIPT.replace("__HINT_ID__", &hint_id);
        let focused = self
            .tab
            .evaluate(&script, true)
            .map_err(render_error)?
            .value
            .and_then(|value| value.as_bool())
            .unwrap_or(false);
        if !focused {
            return Err(RendererError::new(
                RendererErrorKind::InvalidState,
                "hint id was not found or is stale",
            ));
        }
        Ok(InputResult {
            session_id: request.session_id,
            page_id: request.page_id,
        })
    }

    fn click_hint(&mut self, request: ClickHintRequest) -> Result<InputResult, RendererError> {
        self.mark_interaction_start();
        let hint_id = serde_json::to_string(&request.hint_id).map_err(render_error)?;
        let script = CLICK_HINT_ACTION_SCRIPT.replace("__HINT_ID__", &hint_id);
        let point = self
            .tab
            .evaluate(&script, true)
            .map_err(|error| render_context_error("hint point evaluation failed", error))?
            .value
            .ok_or_else(|| {
                RendererError::new(
                    RendererErrorKind::InvalidState,
                    "hint id was not found or is stale",
                )
            })
            .and_then(parse_hint_point_json)?;
        if let Err(error) = dispatch_mouse_click(&self.tab, point.x, point.y)
            .map_err(|error| render_context_error("hint click failed", error))
        {
            self.recover_popup_opening_mouse_dispatch_error(error)?;
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
        self.mark_interaction_start();
        let hint_id = serde_json::to_string(&request.hint_id).map_err(render_error)?;
        let script = CLICK_HINT_POINT_SCRIPT.replace("__HINT_ID__", &hint_id);
        let point = self
            .tab
            .evaluate(&script, true)
            .map_err(|error| render_context_error("hint point evaluation failed", error))?
            .value
            .ok_or_else(|| {
                RendererError::new(
                    RendererErrorKind::InvalidState,
                    "hint id was not found or is stale",
                )
            })
            .and_then(parse_hint_point_json)?;
        if let Err(error) = dispatch_mouse_click_with_button(
            &self.tab,
            point.x,
            point.y,
            MouseDispatchButton::Right,
        )
        .map_err(|error| render_context_error("hint right click failed", error))
        {
            self.recover_popup_opening_mouse_dispatch_error(error)?;
        }
        Ok(InputResult {
            session_id: request.session_id,
            page_id: request.page_id,
        })
    }

    fn hover_hint(&mut self, request: HoverHintRequest) -> Result<InputResult, RendererError> {
        self.mark_interaction_start();
        let hint_id = serde_json::to_string(&request.hint_id).map_err(render_error)?;
        let script = CLICK_HINT_POINT_SCRIPT.replace("__HINT_ID__", &hint_id);
        let point = self
            .tab
            .evaluate(&script, true)
            .map_err(render_error)?
            .value
            .ok_or_else(|| {
                RendererError::new(
                    RendererErrorKind::InvalidState,
                    "hint id was not found or is stale",
                )
            })
            .and_then(parse_hint_point_json)?;
        self.tab
            .move_mouse_to_point(Point {
                x: point.x,
                y: point.y,
            })
            .map_err(render_error)?;
        Ok(InputResult {
            session_id: request.session_id,
            page_id: request.page_id,
        })
    }

    fn select_hint(&mut self, request: SelectHintRequest) -> Result<InputResult, RendererError> {
        self.mark_interaction_start();
        let script = select_hint_script(request.hint_id, &request.choice)?;
        let selected = self
            .tab
            .evaluate(&script, true)
            .map_err(render_error)?
            .value
            .and_then(|value| value.as_bool())
            .unwrap_or(false);
        if !selected {
            return Err(RendererError::new(
                RendererErrorKind::InvalidState,
                "hint id was not a selectable element, was stale, or option choice was not found",
            ));
        }
        Ok(InputResult {
            session_id: request.session_id,
            page_id: request.page_id,
        })
    }

    fn upload_hint(&mut self, request: UploadHintRequest) -> Result<InputResult, RendererError> {
        self.mark_interaction_start();
        let script = upload_hint_target_script(request.hint_id, request.paths.len())?;
        let target = self
            .tab
            .evaluate(&script, true)
            .map_err(render_error)?
            .value
            .ok_or_else(|| {
                RendererError::new(
                    RendererErrorKind::InvalidState,
                    "hint id was not a file input, was stale, or was disabled",
                )
            })
            .and_then(parse_upload_hint_target_json)?;
        let file_paths = request
            .paths
            .iter()
            .map(|path| path.to_string_lossy().into_owned())
            .collect::<Vec<_>>();
        let object_script = upload_hint_object_script(&target.token)?;
        let object = self
            .tab
            .evaluate(&object_script, true)
            .map_err(render_error)?;
        let object_id = object.object_id.ok_or_else(|| {
            RendererError::new(
                RendererErrorKind::InvalidState,
                "hint file upload target did not return an object id",
            )
        })?;
        self.tab
            .call_method(DOM::SetFileInputFiles {
                files: file_paths,
                backend_node_id: None,
                node_id: None,
                object_id: Some(object_id),
            })
            .map_err(render_error)?;
        let change_script = upload_hint_change_script(&target.token)?;
        let changed = self
            .tab
            .evaluate(&change_script, true)
            .map_err(render_error)?
            .value
            .and_then(|value| value.as_bool())
            .unwrap_or(false);
        if !changed {
            return Err(RendererError::new(
                RendererErrorKind::InvalidState,
                "hint file upload completed but change event dispatch failed",
            ));
        }
        Ok(InputResult {
            session_id: request.session_id,
            page_id: request.page_id,
        })
    }

    fn toggle_hint(&mut self, request: ToggleHintRequest) -> Result<InputResult, RendererError> {
        self.mark_interaction_start();
        let script = toggle_hint_script(request.hint_id)?;
        let toggled = self
            .tab
            .evaluate(&script, true)
            .map_err(render_error)?
            .value
            .and_then(|value| value.as_bool())
            .unwrap_or(false);
        if !toggled {
            return Err(RendererError::new(
                RendererErrorKind::InvalidState,
                "hint id was not a checkbox or radio input, was stale, or was disabled",
            ));
        }
        Ok(InputResult {
            session_id: request.session_id,
            page_id: request.page_id,
        })
    }

    fn click_point(&mut self, request: ClickPointRequest) -> Result<InputResult, RendererError> {
        self.mark_interaction_start();
        if let Err(error) = dispatch_mouse_click(&self.tab, request.x, request.y)
            .map_err(|error| render_context_error("point click failed", error))
        {
            self.recover_popup_opening_mouse_dispatch_error(error)?;
        }
        Ok(InputResult {
            session_id: request.session_id,
            page_id: request.page_id,
        })
    }

    fn drag_point(&mut self, request: DragPointRequest) -> Result<InputResult, RendererError> {
        self.mark_interaction_start();
        dispatch_mouse_drag(
            &self.tab,
            request.start_x,
            request.start_y,
            request.end_x,
            request.end_y,
        )?;
        Ok(InputResult {
            session_id: request.session_id,
            page_id: request.page_id,
        })
    }

    fn right_click_point(
        &mut self,
        request: RightClickPointRequest,
    ) -> Result<InputResult, RendererError> {
        self.mark_interaction_start();
        if let Err(error) = dispatch_mouse_click_with_button(
            &self.tab,
            request.x,
            request.y,
            MouseDispatchButton::Right,
        )
        .map_err(|error| render_context_error("point right click failed", error))
        {
            self.recover_popup_opening_mouse_dispatch_error(error)?;
        }
        Ok(InputResult {
            session_id: request.session_id,
            page_id: request.page_id,
        })
    }

    fn hover_point(&mut self, request: HoverPointRequest) -> Result<InputResult, RendererError> {
        self.mark_interaction_start();
        self.tab
            .move_mouse_to_point(Point {
                x: request.x,
                y: request.y,
            })
            .map_err(render_error)?;
        Ok(InputResult {
            session_id: request.session_id,
            page_id: request.page_id,
        })
    }

    fn wheel_point(&mut self, request: WheelPointRequest) -> Result<InputResult, RendererError> {
        self.mark_interaction_start();
        self.tab
            .move_mouse_to_point(Point {
                x: request.x,
                y: request.y,
            })
            .map_err(render_error)?;
        self.tab
            .call_method(Input::DispatchMouseEvent {
                Type: Input::DispatchMouseEventTypeOption::MouseWheel,
                x: request.x,
                y: request.y,
                modifiers: None,
                timestamp: None,
                button: None,
                buttons: None,
                click_count: None,
                force: None,
                tangential_pressure: None,
                tilt_x: None,
                tilt_y: None,
                twist: None,
                delta_x: Some(request.delta_x),
                delta_y: Some(request.delta_y),
                pointer_Type: None,
            })
            .map_err(render_error)?;
        Ok(InputResult {
            session_id: request.session_id,
            page_id: request.page_id,
        })
    }

    fn find_text(&mut self, request: FindTextRequest) -> Result<FindTextResult, RendererError> {
        let script = find_text_script(&request.query, request.backwards)?;
        let result = self
            .tab
            .evaluate(&script, false)
            .map_err(render_error)?
            .value
            .and_then(|value| value.as_str().map(str::to_string))
            .ok_or_else(|| {
                RendererError::new(
                    RendererErrorKind::InvalidState,
                    "find text result was invalid",
                )
            })
            .and_then(|value| parse_find_text_json(&value).map_err(render_error))?;
        Ok(FindTextResult {
            session_id: request.session_id,
            page_id: request.page_id,
            query: request.query,
            backwards: request.backwards,
            found: result.found,
            match_count: Some(result.match_count),
        })
    }

    fn element_hints(
        &mut self,
        _request: ElementHintsRequest,
    ) -> Result<Vec<ElementHint>, RendererError> {
        self.read_element_hints()
    }

    fn page_metrics(
        &mut self,
        _request: PageMetricsRequest,
    ) -> Result<Option<PageMetrics>, RendererError> {
        Ok(self.read_page_metrics())
    }

    fn page_metadata(
        &mut self,
        _request: PageMetadataRequest,
    ) -> Result<Option<PageMetadata>, RendererError> {
        let url = self.tab.get_url();
        let title = self.read_current_title().unwrap_or(None);
        self.current_url = Some(url.clone());
        Ok(Some(PageMetadata { url, title }))
    }

    fn dom_epoch(&mut self, _request: DomEpochRequest) -> Result<Option<u64>, RendererError> {
        self.read_dom_epoch()
    }

    fn focused_element(
        &mut self,
        _request: FocusedElementRequest,
    ) -> Result<Option<FocusedElement>, RendererError> {
        self.read_focused_element()
    }

    fn page_text(&mut self, request: PageTextRequest) -> Result<PageTextSnapshot, RendererError> {
        let value = self
            .tab
            .evaluate(PAGE_TEXT_SCRIPT, true)
            .map_err(render_error)?
            .value
            .and_then(|value| value.as_str().map(str::to_string))
            .ok_or_else(|| {
                RendererError::new(RendererErrorKind::RenderFailed, "missing page text")
            })?;
        let extracted = parse_page_text_json(&value).map_err(render_error)?;
        Ok(PageTextSnapshot {
            session_id: request.session_id,
            page_id: request.page_id,
            url: extracted.url,
            title: extracted.title,
            text: extracted.text,
            truncated: extracted.truncated,
        })
    }

    fn selection_text(
        &mut self,
        request: SelectionTextRequest,
    ) -> Result<SelectionTextResult, RendererError> {
        let text = self
            .tab
            .evaluate(SELECTION_TEXT_SCRIPT, true)
            .map_err(render_error)?
            .value
            .and_then(|value| value.as_str().map(str::to_string))
            .unwrap_or_default();
        Ok(SelectionTextResult {
            session_id: request.session_id,
            page_id: request.page_id,
            text,
        })
    }

    fn settle_after_interaction(&mut self) -> Result<InteractionSettleResult, RendererError> {
        let interaction_started = self
            .last_interaction_started
            .take()
            .unwrap_or_else(SystemTime::now);
        let settled = if self.skip_next_target_adoption {
            self.skip_next_target_adoption = false;
            self.wait_for_current_tab_interaction_settle()
                .map_err(|error| context_renderer_error("interaction settle failed", error))?
        } else {
            self.adopt_new_page_target_after_interaction()
                .map_err(|error| context_renderer_error("target adoption failed", error))?;
            self.wait_for_interaction_settle()
                .map_err(|error| context_renderer_error("interaction settle failed", error))?
        };
        let url = settled.url;
        let title = settled.title;
        self.current_url = Some(url.clone());
        self.current_title = title.clone();
        let settled = InteractionSettleResult::new(url, title);
        let downloads = self.collect_completed_downloads(interaction_started);
        let dialogs = self.collect_dialog_events();
        let settled = if downloads.is_empty() {
            settled
        } else {
            settled.with_downloads(downloads)
        };
        Ok(if dialogs.is_empty() {
            settled
        } else {
            settled.with_dialogs(dialogs)
        })
    }

    fn shutdown(&mut self) -> Result<ShutdownResult, RendererError> {
        let _ = self.tab.close(false);
        Ok(ShutdownResult {})
    }
}

impl ChromiumRenderer {
    fn mark_interaction_start(&mut self) {
        self.drain_dialog_events();
        self.last_interaction_started = Some(SystemTime::now());
    }

    fn collect_dialog_events(&mut self) -> Vec<DialogEvent> {
        let mut dialogs = Vec::new();
        while let Ok(dialog) = self.dialog_event_rx.try_recv() {
            dialogs.push(dialog);
        }
        dialogs
    }

    fn drain_dialog_events(&mut self) {
        while self.dialog_event_rx.try_recv().is_ok() {}
    }

    fn recover_popup_opening_mouse_dispatch_error(
        &mut self,
        error: RendererError,
    ) -> Result<(), RendererError> {
        let now = std::time::Instant::now();
        let Some(deadline) = popup_opening_mouse_recovery_deadline(&error, now) else {
            return Err(error);
        };
        self.suppress_target_registration_until = Some(deadline);
        Ok(())
    }

    fn collect_completed_downloads(
        &mut self,
        interaction_started: SystemTime,
    ) -> Vec<DownloadInfo> {
        let (Some(download_dir), Some(download_events)) =
            (self.download_dir.as_ref(), self.download_events.as_mut())
        else {
            return Vec::new();
        };
        let mut completed = Vec::new();
        let mut saw_download_event = false;
        while let Ok(event) = download_events.rx.try_recv() {
            match event {
                DownloadEvent::WillBegin {
                    guid,
                    suggested_filename,
                } => {
                    saw_download_event = true;
                    download_events.filenames.insert(guid, suggested_filename);
                }
                DownloadEvent::Completed { guid } => {
                    saw_download_event = true;
                    let suggested_filename = download_events.filenames.remove(&guid);
                    completed.push(
                        detect_new_completed_download(
                            download_dir,
                            &mut download_events.known_paths,
                            interaction_started,
                        )
                        .unwrap_or_else(|| {
                            let path = suggested_filename
                                .as_ref()
                                .map(|filename| download_dir.join(filename))
                                .unwrap_or_else(|| download_dir.join(guid));
                            download_events.known_paths.insert(path.clone());
                            DownloadInfo::completed(path, suggested_filename)
                        }),
                    );
                }
            }
        }
        if !completed.is_empty() {
            return completed;
        }

        let downloads = detect_new_completed_downloads(
            download_dir,
            &mut download_events.known_paths,
            interaction_started,
        );
        if !downloads.is_empty() {
            return downloads;
        }

        if !saw_download_event && !has_active_chromium_download(download_dir, interaction_started) {
            return Vec::new();
        }

        let deadline = std::time::Instant::now() + Duration::from_millis(1500);
        loop {
            let downloads = detect_new_completed_downloads(
                download_dir,
                &mut download_events.known_paths,
                interaction_started,
            );
            if !downloads.is_empty() {
                return downloads;
            }
            if std::time::Instant::now() >= deadline {
                return Vec::new();
            }
            std::thread::sleep(Duration::from_millis(50));
        }
    }

    fn adopt_new_page_target_after_interaction(&mut self) -> Result<(), RendererError> {
        let deadline = std::time::Instant::now() + Duration::from_millis(750);
        let new_target_deadline = std::time::Instant::now() + Duration::from_millis(500);
        loop {
            let (tabs, candidates) = self.current_target_candidates();
            track_pending_page_targets(
                &mut self.known_target_ids,
                &mut self.pending_page_target_ids,
                &candidates,
            );
            if self.try_adopt_target_from_candidates(&tabs, &candidates)? {
                return Ok(());
            }
            if !has_unknown_targets(&candidates, &self.pending_page_target_ids) {
                if std::time::Instant::now() >= new_target_deadline {
                    return Ok(());
                }
                thread::sleep(Duration::from_millis(25));
                continue;
            }

            if std::time::Instant::now() >= deadline {
                mark_observed_targets_known(
                    &mut self.known_target_ids,
                    &mut self.pending_page_target_ids,
                    &candidates,
                );
                return Ok(());
            }
            thread::sleep(Duration::from_millis(50));
        }
    }

    fn try_adopt_target_from_candidates(
        &mut self,
        tabs: &[Arc<Tab>],
        candidates: &[TargetCandidate],
    ) -> Result<bool, RendererError> {
        let active_id = self.tab.get_target_id().clone();
        let Some(target_id) =
            choose_new_page_target_id(&active_id, candidates, &self.pending_page_target_ids)
        else {
            return Ok(false);
        };
        let Some(tab) = tabs
            .iter()
            .find(|tab| tab.get_target_id().as_str() == target_id)
            .cloned()
        else {
            return Ok(false);
        };
        if let Err(error) = self.ensure_dialog_handler(&tab) {
            if is_closed_target_error(&error) {
                self.pending_page_target_ids.remove(&target_id);
                self.known_target_ids.insert(target_id);
                return Ok(false);
            }
            return Err(error);
        }
        if let Err(error) = install_dom_epoch_observer(&tab) {
            if is_closed_target_error(&error) {
                self.pending_page_target_ids.remove(&target_id);
                self.known_target_ids.insert(target_id);
                return Ok(false);
            }
            return Err(error);
        }
        configure_tab_timeout_ms(&tab, self.navigation_timeout_ms);
        if let Err(error) = tab.activate().map_err(render_error) {
            if is_closed_target_error(&error) {
                self.pending_page_target_ids.remove(&target_id);
                self.known_target_ids.insert(target_id);
                return Ok(false);
            }
            return Err(error);
        }
        if let Err(error) = resize_tab(&tab, self.active_viewport) {
            if is_closed_target_error(&error) {
                self.pending_page_target_ids.remove(&target_id);
                self.known_target_ids.insert(target_id);
                return Ok(false);
            }
            return Err(error);
        }
        if let Err(error) = apply_page_zoom(&tab, self.active_viewport, self.current_zoom_scale) {
            if is_closed_target_error(&error) {
                self.pending_page_target_ids.remove(&target_id);
                self.known_target_ids.insert(target_id);
                return Ok(false);
            }
            return Err(error);
        }
        if let Some(download_dir) = self.download_dir.as_deref() {
            match configure_download_behavior(&tab, Some(download_dir)) {
                Ok(download_events) => {
                    self.download_events = download_events;
                }
                Err(error) if is_closed_target_error(&error) => {
                    self.pending_page_target_ids.remove(&target_id);
                    self.known_target_ids.insert(target_id);
                    return Ok(false);
                }
                Err(error) => return Err(error),
            }
        }
        self.tab = tab;
        self.pending_page_target_ids.remove(&target_id);
        self.known_target_ids = tabs
            .iter()
            .map(|tab| tab.get_target_id().clone())
            .collect::<HashSet<_>>();
        Ok(true)
    }

    fn ensure_dialog_handler(&mut self, tab: &Arc<Tab>) -> Result<(), RendererError> {
        let target_id = tab.get_target_id().clone();
        if self.dialog_handler_target_ids.contains(&target_id) {
            return Ok(());
        }
        install_default_dialog_handler(tab, Some(self.dialog_event_tx.clone()))?;
        self.dialog_handler_target_ids.insert(target_id);
        Ok(())
    }

    fn current_target_candidates(&mut self) -> (Vec<Arc<Tab>>, Vec<TargetCandidate>) {
        if self
            .suppress_target_registration_until
            .is_some_and(|deadline| std::time::Instant::now() < deadline)
        {
            // The browser-level Target.getTargets call inside headless_chrome can
            // panic immediately after a popup-opening click closes the old target
            // connection. During that short recovery window, rely on browser
            // target events that have already populated get_tabs().
        } else {
            self.suppress_target_registration_until = None;
            self.browser.register_missing_tabs();
        }
        let tabs = self.current_tabs();
        let candidates = tabs
            .iter()
            .map(|tab| TargetCandidate {
                id: tab.get_target_id().clone(),
                url: tab.get_url(),
                previously_known: self.known_target_ids.contains(tab.get_target_id()),
            })
            .collect::<Vec<_>>();
        (tabs, candidates)
    }

    fn current_tabs(&self) -> Vec<Arc<Tab>> {
        self.browser
            .get_tabs()
            .lock()
            .map(|tabs| tabs.iter().cloned().collect())
            .unwrap_or_default()
    }

    fn refresh_known_target_ids(&mut self) {
        self.browser.register_missing_tabs();
        self.known_target_ids = collect_tab_target_ids(&self.browser);
    }

    fn wait_for_interaction_settle(&mut self) -> Result<InteractionSettleSample, RendererError> {
        let deadline = std::time::Instant::now() + Duration::from_millis(750);
        let mut samples = Vec::new();
        let _ = self.wait_for_dom_quiet();

        loop {
            let (tabs, candidates) = self.current_target_candidates();
            track_pending_page_targets(
                &mut self.known_target_ids,
                &mut self.pending_page_target_ids,
                &candidates,
            );
            if self.try_adopt_target_from_candidates(&tabs, &candidates)? {
                samples.clear();
                let _ = self.wait_for_dom_quiet();
                continue;
            }
            if has_unknown_targets(&candidates, &self.pending_page_target_ids) {
                if std::time::Instant::now() < deadline {
                    samples.clear();
                    thread::sleep(Duration::from_millis(50));
                    continue;
                }
                mark_observed_targets_known(
                    &mut self.known_target_ids,
                    &mut self.pending_page_target_ids,
                    &candidates,
                );
            }
            samples.push(self.read_interaction_settle_sample()?);
            if let Some(sample) =
                choose_interaction_settle_sample(&samples, INTERACTION_SETTLE_STABLE_SAMPLES)
            {
                return Ok(sample);
            }
            if std::time::Instant::now() >= deadline {
                return latest_interaction_settle_sample(&samples)
                    .ok_or_else(|| render_error("interaction settle did not collect samples"));
            }
            thread::sleep(Duration::from_millis(50));
        }
    }

    fn wait_for_current_tab_interaction_settle(
        &mut self,
    ) -> Result<InteractionSettleSample, RendererError> {
        let deadline = std::time::Instant::now() + Duration::from_millis(750);
        let mut samples = Vec::new();
        let _ = self.wait_for_dom_quiet();

        loop {
            samples.push(self.read_interaction_settle_sample()?);
            if let Some(sample) =
                choose_interaction_settle_sample(&samples, INTERACTION_SETTLE_STABLE_SAMPLES)
            {
                return Ok(sample);
            }
            if std::time::Instant::now() >= deadline {
                return latest_interaction_settle_sample(&samples)
                    .ok_or_else(|| render_error("interaction settle did not collect samples"));
            }
            thread::sleep(Duration::from_millis(50));
        }
    }

    fn wait_for_dom_quiet(&self) -> Result<(), RendererError> {
        self.tab
            .evaluate(DOM_QUIET_SCRIPT, true)
            .map(|_| ())
            .map_err(render_error)
    }

    fn read_interaction_settle_sample(&self) -> Result<InteractionSettleSample, RendererError> {
        Ok(InteractionSettleSample {
            url: self.tab.get_url(),
            title: self.read_current_title().unwrap_or(None),
            ready_state: self.read_ready_state().unwrap_or(None),
        })
    }

    fn read_ready_state(&self) -> Result<Option<String>, RendererError> {
        Ok(self
            .tab
            .evaluate(READY_STATE_SCRIPT, true)
            .map_err(render_error)?
            .value
            .and_then(|value| value.as_str().map(str::to_string)))
    }

    fn navigate_history(
        &mut self,
        request: HistoryNavigationRequest,
        direction: HistoryDirection,
    ) -> Result<HistoryNavigationResult, RendererError> {
        let history = self
            .tab
            .call_method(GetNavigationHistory {})
            .map_err(render_error)?;
        let target_index = match direction {
            HistoryDirection::Back => history.current_index.checked_sub(1).ok_or_else(|| {
                RendererError::new(RendererErrorKind::InvalidState, "no back history entry")
            })?,
            HistoryDirection::Forward => {
                let next = history.current_index + 1;
                if next >= history.entries.len() {
                    return Err(RendererError::new(
                        RendererErrorKind::InvalidState,
                        "no forward history entry",
                    ));
                }
                next
            }
        };
        let target = history.entries.get(target_index).ok_or_else(|| {
            RendererError::new(RendererErrorKind::InvalidState, "history entry is missing")
        })?;
        let target_url = target.url.clone();
        self.tab
            .call_method(NavigateToHistoryEntry {
                entry_id: target.id,
            })
            .map_err(render_error)?;
        let url = self.wait_for_current_url(&target_url)?;
        wait_until_navigated(&self.tab, &target_url, self.navigation_timeout_ms)?;
        let title = self.read_current_title().unwrap_or(None);
        self.current_url = Some(url.clone());
        self.current_title = title.clone();
        Ok(HistoryNavigationResult {
            session_id: request.session_id,
            page_id: request.page_id,
            url,
            title,
        })
    }

    fn read_current_title(&self) -> Option<Option<String>> {
        self.tab
            .evaluate("document.title", false)
            .ok()
            .and_then(|remote_object| remote_object.value)
            .map(|value| {
                value.as_str().and_then(|title| {
                    let title = title.trim();
                    if title.is_empty() {
                        None
                    } else {
                        Some(title.to_string())
                    }
                })
            })
    }

    fn read_element_hints(&self) -> Result<Vec<ElementHint>, RendererError> {
        let value = self
            .tab
            .evaluate(ELEMENT_HINTS_SCRIPT, true)
            .map_err(render_error)?
            .value
            .ok_or_else(|| {
                RendererError::new(
                    RendererErrorKind::InvalidState,
                    "hint extraction did not return a value",
                )
            })?;
        value
            .as_str()
            .ok_or_else(|| {
                RendererError::new(
                    RendererErrorKind::InvalidState,
                    "hint extraction did not return JSON text",
                )
            })
            .and_then(parse_element_hints_json)
    }

    fn read_page_metrics(&self) -> Option<PageMetrics> {
        let value = self
            .tab
            .evaluate(PAGE_METRICS_SCRIPT, true)
            .ok()
            .and_then(|remote_object| remote_object.value)?;
        value
            .as_str()
            .and_then(|metrics| parse_page_metrics_json(metrics).ok())
    }

    fn read_dom_epoch(&self) -> Result<Option<u64>, RendererError> {
        Ok(self
            .tab
            .evaluate(DOM_EPOCH_SCRIPT, true)
            .map_err(render_error)?
            .value
            .and_then(|value| value.as_u64()))
    }

    fn read_focused_element(&self) -> Result<Option<FocusedElement>, RendererError> {
        let value = self
            .tab
            .evaluate(ACTIVE_ELEMENT_SCRIPT, true)
            .map_err(render_error)?
            .value;
        let Some(value) = value else {
            return Ok(None);
        };
        if value.is_null() {
            return Ok(None);
        }
        let text = value.as_str().ok_or_else(|| {
            RendererError::new(
                RendererErrorKind::InvalidState,
                "focused element extraction did not return JSON text",
            )
        })?;
        parse_focused_element_json(text)
            .map(Some)
            .map_err(render_error)
    }

    fn wait_for_current_url(&self, target_url: &str) -> Result<String, RendererError> {
        let deadline =
            std::time::Instant::now() + Duration::from_millis(self.navigation_timeout_ms);
        loop {
            let url = self.tab.get_url();
            if url == target_url {
                return Ok(url);
            }
            let now = std::time::Instant::now();
            if now >= deadline {
                let current_url = self.tab.get_url();
                return Err(navigation_timeout_error(
                    target_url,
                    self.navigation_timeout_ms,
                    format!("current URL is {current_url}"),
                ));
            }
            thread::sleep(Duration::from_millis(50).min(deadline.saturating_duration_since(now)));
        }
    }
}

const ELEMENT_HINTS_SCRIPT: &str = r#"
(() => {
  const selectors = [
    'a[href]',
    'button',
    'input',
    'textarea',
    'select',
    '[role="button"]',
    '[role="link"]',
    '[tabindex]:not([tabindex="-1"])',
    '[contenteditable="true"]',
    '[onclick]'
  ].join(',');
  const viewportWidth = window.innerWidth || document.documentElement.clientWidth || 0;
  const viewportHeight = window.innerHeight || document.documentElement.clientHeight || 0;
  const MAX_FRAME_DEPTH = 3;
  const normalizeText = (value) => String(value || '').replace(/\s+/g, ' ').trim();
  const labelledByText = (element) => {
    const raw = normalizeText(element.getAttribute('aria-labelledby'));
    if (raw.length === 0) return null;
    const ownerDocument = element.ownerDocument || document;
    const rootNode = typeof element.getRootNode === 'function' ? element.getRootNode() : null;
    const labelScope = rootNode && typeof rootNode.getElementById === 'function'
      ? rootNode
      : ownerDocument;
    const text = raw.split(' ').map((id) => {
      const label = labelScope.getElementById(id);
      return label ? normalizeText(label.textContent) : '';
    }).filter(Boolean).join(' ');
    return text.length > 0 ? text : null;
  };
  const labelElementText = (element) => {
    if (element.labels && element.labels.length > 0) {
      const text = Array.from(element.labels).map((label) => normalizeText(label.textContent)).filter(Boolean).join(' ');
      if (text.length > 0) return text;
    }
    const wrapping = typeof element.closest === 'function' ? element.closest('label') : null;
    if (wrapping) {
      const text = normalizeText(wrapping.textContent);
      if (text.length > 0) return text;
    }
    return null;
  };
  const labelFor = (element) => {
    const tag = element.tagName.toLowerCase();
    const inputType = tag === 'input' ? (element.getAttribute('type') || 'text').toLowerCase() : '';
    const passwordLike = tag === 'input' && inputType === 'password';
    const candidates = [
      element.getAttribute('aria-label'),
      labelledByText(element),
      labelElementText(element),
      element.getAttribute('title'),
      element.getAttribute('placeholder'),
      !passwordLike ? element.value : null,
      element.innerText,
      element.textContent,
      element.getAttribute('href')
    ];
    for (const candidate of candidates) {
      if (typeof candidate !== 'string') continue;
      const label = normalizeText(candidate);
      if (label.length > 0) return label.slice(0, 80);
    }
    return element.tagName.toLowerCase();
  };
  const kindFor = (element) => {
    const tag = element.tagName.toLowerCase();
    const role = (element.getAttribute('role') || '').toLowerCase();
    if (tag === 'a' || role === 'link') return 'link';
    if (tag === 'button' || role === 'button') return 'button';
    if (tag === 'input') {
      const type = (element.getAttribute('type') || 'text').toLowerCase();
      if (type === 'file') return 'file';
      if (type === 'checkbox') return 'checkbox';
      if (type === 'radio') return 'radio';
      return 'input';
    }
    if (tag === 'textarea') return 'text_area';
    if (tag === 'select') return 'select';
    if (element.isContentEditable) return 'editable';
    return 'other';
  };
  const hrefFor = (element) => {
    if (kindFor(element) !== 'link') return null;
    if (typeof element.href === 'string' && element.href.trim().length > 0) return element.href;
    const raw = element.getAttribute('href');
    if (typeof raw !== 'string' || raw.trim().length === 0) return null;
    try {
      const ownerDocument = element.ownerDocument || document;
      return new URL(raw, ownerDocument.baseURI).href;
    } catch (_) {
      return raw.trim();
    }
  };
  const targetFor = (element) => {
    if (element.tagName.toLowerCase() !== 'a') return null;
    const target = element.getAttribute('target');
    if (typeof target !== 'string' || target.trim().length === 0) return null;
    return target.trim();
  };
  const isFocusable = (element) => {
    const tag = element.tagName.toLowerCase();
    return ['input', 'textarea', 'select', 'button', 'a'].includes(tag)
      || element.isContentEditable
      || element.tabIndex >= 0;
  };
  const isDisabled = (element) => element.disabled || element.getAttribute('aria-disabled') === 'true';
  const checkedFor = (element) => {
    const kind = kindFor(element);
    if (kind !== 'checkbox' && kind !== 'radio') return null;
    return element.checked === true;
  };
  const optionsFor = (element) => {
    if (kindFor(element) !== 'select') return [];
    return Array.from(element.options || []).map((option) => ({
      value: typeof option.value === 'string' ? option.value : '',
      label: normalizeText(option.textContent || option.label || option.value || ''),
      disabled: option.disabled === true,
      selected: option.selected === true
    }));
  };
  const isVisible = (element) => {
    const ownerWindow = (element.ownerDocument && element.ownerDocument.defaultView) || window;
    const style = ownerWindow.getComputedStyle(element);
    return style.display !== 'none'
      && style.visibility !== 'hidden'
      && style.visibility !== 'collapse'
      && Number(style.opacity || '1') > 0.05
      && style.pointerEvents !== 'none';
  };
  const translateRectToViewport = (rect, frameElements) => {
    let left = rect.left;
    let top = rect.top;
    let right = rect.right;
    let bottom = rect.bottom;
    for (let index = frameElements.length - 1; index >= 0; index -= 1) {
      const frameRect = frameElements[index].getBoundingClientRect();
      const frameLeft = frameRect.left + (frameElements[index].clientLeft || 0);
      const frameTop = frameRect.top + (frameElements[index].clientTop || 0);
      left += frameLeft;
      right += frameLeft;
      top += frameTop;
      bottom += frameTop;
    }
    return { left, top, right, bottom, width: Math.max(0, right - left), height: Math.max(0, bottom - top) };
  };
  const isTopmostAt = (element, x, y, root, frameElements) => {
    const rootTop = typeof root.elementFromPoint === 'function' ? root.elementFromPoint(x, y) : null;
    if (rootTop !== element && !(rootTop !== null && element.contains(rootTop))) return false;
    if (frameElements.length === 0) return true;
    const translated = translateRectToViewport({ left: x, top: y, right: x, bottom: y }, frameElements);
    const topElement = document.elementFromPoint(translated.left, translated.top);
    const outerFrame = frameElements[0];
    return topElement === outerFrame || (topElement !== null && outerFrame.contains(topElement));
  };
  const rootViewport = (root) => {
    const rootDocument = root.ownerDocument || root;
    const rootWindow = rootDocument.defaultView || window;
    const rootElement = rootDocument.documentElement || document.documentElement;
    return {
      width: rootWindow.innerWidth || rootElement.clientWidth || 0,
      height: rootWindow.innerHeight || rootElement.clientHeight || 0
    };
  };
  const collectCandidates = (root, frameElements, depth) => {
    if (!root || typeof root.querySelectorAll !== 'function') return [];
    const viewport = rootViewport(root);
    const localCandidates = Array.from(root.querySelectorAll(selectors))
      .filter((element) => !isDisabled(element))
      .filter(isVisible)
      .map((element) => ({ element, root, frameElements, rect: element.getBoundingClientRect() }))
      .filter(({ rect }) => rect.width > 0 && rect.height > 0)
      .filter(({ rect }) => rect.right >= 0 && rect.bottom >= 0 && rect.left <= viewport.width && rect.top <= viewport.height)
      .map(({ element, root, frameElements, rect }) => {
        const localLeft = Math.max(0, rect.left);
        const localTop = Math.max(0, rect.top);
        const localRight = Math.min(viewport.width, rect.right);
        const localBottom = Math.min(viewport.height, rect.bottom);
        const localX = (localLeft + localRight) / 2;
        const localY = (localTop + localBottom) / 2;
        const translated = translateRectToViewport({ left: localLeft, top: localTop, right: localRight, bottom: localBottom }, frameElements);
        const left = Math.max(0, translated.left);
        const top = Math.max(0, translated.top);
        const right = Math.min(viewportWidth, translated.right);
        const bottom = Math.min(viewportHeight, translated.bottom);
        return { element, root, frameElements, rect, localX, localY, left, top, right, bottom, x: (left + right) / 2, y: (top + bottom) / 2 };
      })
      .filter(({ left, top, right, bottom }) => right > left && bottom > top)
      .filter(({ element, localX, localY, root, frameElements }) => isTopmostAt(element, localX, localY, root, frameElements));

    const nested = [];
    for (const element of Array.from(root.querySelectorAll('*'))) {
      if (element.shadowRoot) {
        nested.push(...collectCandidates(element.shadowRoot, frameElements, depth));
      }
      const tag = element.tagName ? element.tagName.toLowerCase() : '';
      if ((tag === 'iframe' || tag === 'frame') && depth < MAX_FRAME_DEPTH) {
        try {
          const frameDocument = element.contentDocument;
          if (frameDocument) {
            nested.push(...collectCandidates(frameDocument, frameElements.concat(element), depth + 1));
          }
        } catch (_) {
          // Cross-origin frames are intentionally skipped.
        }
      }
    }
    return localCandidates.concat(nested);
  };
  const candidates = collectCandidates(document, [], 0)
    .sort((a, b) => (a.rect.top - b.rect.top) || (a.rect.left - b.rect.left))
    .slice(0, 80);
  const registry = (() => {
    const existing = window.__nvbrowserHintRegistry;
    if (existing && existing.elements instanceof Map && Number.isFinite(existing.nextId)) {
      return existing;
    }
    const created = { nextId: 1, elements: new Map() };
    window.__nvbrowserHintRegistry = created;
    return created;
  })();
  for (const [id, element] of registry.elements) {
    const stored = element && (element.element || element);
    if (!stored || !stored.isConnected) {
      registry.elements.delete(id);
    }
  }
  const idFor = (element, frameElements) => {
    for (const [id, existing] of registry.elements) {
      const stored = existing && (existing.element || existing);
      if (stored === element) return id;
    }
    const id = registry.nextId++;
    registry.elements.set(id, { element, frameElements });
    return id;
  };
  const hints = candidates.map(({ element, frameElements, left, top, right, bottom, x, y }) => {
      const id = idFor(element, frameElements);
      return {
        id,
        kind: kindFor(element),
        label: labelFor(element),
        href: hrefFor(element),
        target: targetFor(element),
        checked: checkedFor(element),
        options: optionsFor(element),
        x,
        y,
        width: Math.max(0, right - left),
        height: Math.max(0, bottom - top),
        clickable: true,
        focusable: isFocusable(element)
      };
    });
  return JSON.stringify(hints);
})()
"#;

const FOCUS_HINT_SCRIPT: &str = r#"
(() => {
  const hintId = __HINT_ID__;
  const registry = window.__nvbrowserHintRegistry;
  const entry = registry && registry.elements instanceof Map ? registry.elements.get(hintId) : null;
  const element = entry && (entry.element || entry);
  if (!element || !element.isConnected) return false;
  if (element.disabled || element.getAttribute('aria-disabled') === 'true') return false;
  const tag = element.tagName.toLowerCase();
  const type = tag === 'input' ? (element.getAttribute('type') || 'text').toLowerCase() : '';
  if (type === 'hidden') return false;
  const role = (element.getAttribute('role') || '').toLowerCase();
  const focusable = tag === 'input'
    || tag === 'textarea'
    || tag === 'select'
    || tag === 'button'
    || tag === 'a'
    || element.isContentEditable
    || element.tabIndex >= 0
    || role === 'textbox'
    || role === 'combobox'
    || role === 'searchbox'
    || role === 'button'
    || role === 'link';
  if (!focusable) return false;
  if (typeof element.scrollIntoView === 'function') {
    element.scrollIntoView({ block: 'center', inline: 'center' });
  }
  if (typeof element.focus === 'function') {
    element.focus({ preventScroll: true });
  }
  const ownerDocument = element.ownerDocument || document;
  return ownerDocument.activeElement === element || element.contains(ownerDocument.activeElement);
})()
"#;

const ACTIVE_ELEMENT_SCRIPT: &str = r#"
(() => {
  const element = document.activeElement;
  if (!element || element === document.body || element === document.documentElement) return null;
  const normalizeText = (value) => String(value || '').replace(/\s+/g, ' ').trim();
  const labelledByText = (element) => {
    const raw = normalizeText(element.getAttribute('aria-labelledby'));
    if (raw.length === 0) return null;
    const text = raw.split(' ').map((id) => {
      const label = document.getElementById(id);
      return label ? normalizeText(label.textContent) : '';
    }).filter(Boolean).join(' ');
    return text.length > 0 ? text : null;
  };
  const labelElementText = (element) => {
    if (element.labels && element.labels.length > 0) {
      const text = Array.from(element.labels).map((label) => normalizeText(label.textContent)).filter(Boolean).join(' ');
      if (text.length > 0) return text;
    }
    const wrapping = typeof element.closest === 'function' ? element.closest('label') : null;
    if (wrapping) {
      const text = normalizeText(wrapping.textContent);
      if (text.length > 0) return text;
    }
    return null;
  };
  const kindFor = (element) => {
    const tag = element.tagName.toLowerCase();
    const role = (element.getAttribute('role') || '').toLowerCase();
    if (tag === 'a' || role === 'link') return 'link';
    if (tag === 'button' || role === 'button') return 'button';
    if (tag === 'input') {
      const type = (element.getAttribute('type') || 'text').toLowerCase();
      if (type === 'file') return 'file';
      if (type === 'checkbox') return 'checkbox';
      if (type === 'radio') return 'radio';
      return 'input';
    }
    if (tag === 'textarea') return 'text_area';
    if (tag === 'select') return 'select';
    if (element.isContentEditable) return 'editable';
    return 'other';
  };
  const labelFor = (element) => {
    const candidates = [
      element.getAttribute('aria-label'),
      labelledByText(element),
      labelElementText(element),
      element.getAttribute('title'),
      element.getAttribute('placeholder'),
      passwordLike ? null : element.value,
      element.innerText,
      element.textContent,
      element.getAttribute('href')
    ];
    for (const candidate of candidates) {
      if (typeof candidate !== 'string') continue;
      const label = normalizeText(candidate);
      if (label.length > 0) return label.slice(0, 80);
    }
    return null;
  };
  const tag = element.tagName.toLowerCase();
  const role = (element.getAttribute('role') || '').toLowerCase();
  const inputType = tag === 'input' ? (element.getAttribute('type') || 'text').toLowerCase() : '';
  const passwordLike = tag === 'input' && inputType === 'password';
  const kind = kindFor(element);
  const editable = kind === 'input' || kind === 'text_area' || kind === 'select' || kind === 'editable';
  const value = editable && !passwordLike && typeof element.value === 'string'
    ? normalizeText(element.value).slice(0, 120)
    : null;
  const checked = (kind === 'checkbox' || kind === 'radio') ? element.checked === true : null;
  const submittable = kind === 'input'
    || kind === 'text_area'
    || kind === 'select'
    || kind === 'checkbox'
    || kind === 'radio'
    || kind === 'editable'
    || role === 'textbox'
    || role === 'searchbox'
    || role === 'combobox';
  const focusable = tag === 'input'
    || tag === 'textarea'
    || tag === 'select'
    || tag === 'button'
    || tag === 'a'
    || element.isContentEditable
    || element.tabIndex >= 0
    || role === 'textbox'
    || role === 'combobox'
    || role === 'searchbox'
    || role === 'button'
    || role === 'link';
  return JSON.stringify({
    kind,
    label: labelFor(element),
    value,
    checked,
    focusable,
    submittable
  });
})()
"#;

const CLICK_HINT_POINT_SCRIPT: &str = r#"
(() => {
  const hintId = __HINT_ID__;
  const registry = window.__nvbrowserHintRegistry;
  const entry = registry && registry.elements instanceof Map ? registry.elements.get(hintId) : null;
  const element = entry && (entry.element || entry);
  const frameElements = entry && (entry.frameElements || []);
  if (!element || !element.isConnected) return null;
  for (const frame of frameElements) {
    if (frame && typeof frame.scrollIntoView === 'function') {
      frame.scrollIntoView({ block: 'center', inline: 'center' });
    }
  }
  if (typeof element.scrollIntoView === 'function') {
    element.scrollIntoView({ block: 'center', inline: 'center' });
  }
  const rect = element.getBoundingClientRect();
  if (rect.width <= 0 || rect.height <= 0) return null;
  let x = rect.left + rect.width / 2;
  let y = rect.top + rect.height / 2;
  for (let index = frameElements.length - 1; index >= 0; index -= 1) {
    const frameRect = frameElements[index].getBoundingClientRect();
    x += frameRect.left + (frameElements[index].clientLeft || 0);
    y += frameRect.top + (frameElements[index].clientTop || 0);
  }
  return JSON.stringify({
    x: Math.max(0, Math.min(window.innerWidth || x, x)),
    y: Math.max(0, Math.min(window.innerHeight || y, y))
  });
})()
"#;

const CLICK_HINT_ACTION_SCRIPT: &str = r#"
(() => {
  const hintId = __HINT_ID__;
  const registry = window.__nvbrowserHintRegistry;
  const entry = registry && registry.elements instanceof Map ? registry.elements.get(hintId) : null;
  const element = entry && (entry.element || entry);
  const frameElements = entry && (entry.frameElements || []);
  if (!element || !element.isConnected) return null;
  for (const frame of frameElements) {
    if (frame && typeof frame.scrollIntoView === 'function') {
      frame.scrollIntoView({ block: 'center', inline: 'center' });
    }
  }
  if (typeof element.scrollIntoView === 'function') {
    element.scrollIntoView({ block: 'center', inline: 'center' });
  }
  const rect = element.getBoundingClientRect();
  if (rect.width <= 0 || rect.height <= 0) return null;
  let x = rect.left + rect.width / 2;
  let y = rect.top + rect.height / 2;
  for (let index = frameElements.length - 1; index >= 0; index -= 1) {
    const frameRect = frameElements[index].getBoundingClientRect();
    x += frameRect.left + (frameElements[index].clientLeft || 0);
    y += frameRect.top + (frameElements[index].clientTop || 0);
  }
  return JSON.stringify({
    x: Math.max(0, Math.min(window.innerWidth || x, x)),
    y: Math.max(0, Math.min(window.innerHeight || y, y))
  });
})()
"#;

fn select_hint_script(hint_id: u32, choice: &str) -> Result<String, RendererError> {
    let hint_id = serde_json::to_string(&hint_id).map_err(render_error)?;
    let choice = serde_json::to_string(choice).map_err(render_error)?;
    Ok(SELECT_HINT_SCRIPT
        .replace("__HINT_ID__", &hint_id)
        .replace("__CHOICE__", &choice))
}

const SELECT_HINT_SCRIPT: &str = r#"
(() => {
  const hintId = __HINT_ID__;
  const choice = __CHOICE__;
  const registry = window.__nvbrowserHintRegistry;
  const entry = registry && registry.elements instanceof Map ? registry.elements.get(hintId) : null;
  const element = entry && (entry.element || entry);
  if (!element || !element.isConnected || element.tagName.toLowerCase() !== 'select') return false;
  const normalize = (value) => String(value || '').replace(/\s+/g, ' ').trim();
  const normalizedChoice = normalize(choice);
  const options = Array.from(element.options || []);
  let selectedIndex = -1;
  if (/^\d+$/.test(normalizedChoice)) {
    const index = Number.parseInt(normalizedChoice, 10) - 1;
    if (index >= 0 && index < options.length && !options[index].disabled) {
      selectedIndex = index;
    }
  }
  if (selectedIndex < 0) {
    selectedIndex = options.findIndex((option) => !option.disabled && option.value === choice);
  }
  if (selectedIndex < 0) {
    const wanted = normalizedChoice.toLowerCase();
    selectedIndex = options.findIndex((option) => !option.disabled && normalize(option.textContent).toLowerCase() === wanted);
  }
  if (selectedIndex < 0) return false;
  if (typeof element.focus === 'function') {
    element.focus({ preventScroll: true });
  }
  element.selectedIndex = selectedIndex;
  element.value = options[selectedIndex].value;
  element.dispatchEvent(new Event('input', { bubbles: true }));
  element.dispatchEvent(new Event('change', { bubbles: true }));
  return true;
})()
"#;

fn upload_hint_target_script(hint_id: u32, file_count: usize) -> Result<String, RendererError> {
    let hint_id = serde_json::to_string(&hint_id).map_err(render_error)?;
    let file_count = serde_json::to_string(&file_count).map_err(render_error)?;
    let token = format!("nvbrowser-upload-{}-{}", unix_time_ms(), hint_id);
    let token = serde_json::to_string(&token).map_err(render_error)?;
    Ok(UPLOAD_HINT_TARGET_SCRIPT
        .replace("__HINT_ID__", &hint_id)
        .replace("__FILE_COUNT__", &file_count)
        .replace("__TOKEN__", &token))
}

const UPLOAD_HINT_TARGET_SCRIPT: &str = r#"
(() => {
  const hintId = __HINT_ID__;
  const fileCount = __FILE_COUNT__;
  const token = __TOKEN__;
  const registry = window.__nvbrowserHintRegistry;
  const entry = registry && registry.elements instanceof Map ? registry.elements.get(hintId) : null;
  const element = entry && (entry.element || entry);
  if (!element || !element.isConnected || element.tagName.toLowerCase() !== 'input') {
    return JSON.stringify({ ok: false, error: 'hint id was not found or is stale' });
  }
  if (element.disabled || element.getAttribute('aria-disabled') === 'true') {
    return JSON.stringify({ ok: false, error: 'file input is disabled' });
  }
  const type = (element.getAttribute('type') || 'text').toLowerCase();
  if (type !== 'file') {
    return JSON.stringify({ ok: false, error: 'hint is not a file input' });
  }
  if (!Number.isFinite(fileCount) || fileCount <= 0) {
    return JSON.stringify({ ok: false, error: 'no files were provided' });
  }
  if (fileCount > 1 && !element.multiple) {
    return JSON.stringify({ ok: false, error: 'file input does not accept multiple files' });
  }
  if (typeof element.scrollIntoView === 'function') {
    element.scrollIntoView({ block: 'center', inline: 'center' });
  }
  element.setAttribute('data-nvbrowser-upload-token', token);
  if (entry && typeof entry === 'object') {
    entry.uploadToken = token;
  }
  return JSON.stringify({
    ok: true,
    token
  });
})()
"#;

fn upload_hint_object_script(token: &str) -> Result<String, RendererError> {
    let token = serde_json::to_string(token).map_err(render_error)?;
    Ok(UPLOAD_HINT_OBJECT_SCRIPT.replace("__TOKEN__", &token))
}

const UPLOAD_HINT_OBJECT_SCRIPT: &str = r#"
(() => {
  const token = __TOKEN__;
  const registry = window.__nvbrowserHintRegistry;
  if (!registry || !(registry.elements instanceof Map)) return null;
  for (const entry of registry.elements.values()) {
    const element = entry && (entry.element || entry);
    const uploadToken = entry && entry.uploadToken;
    if (
      element
      && element.isConnected
      && uploadToken === token
      && element.tagName.toLowerCase() === 'input'
      && (element.getAttribute('type') || 'text').toLowerCase() === 'file'
    ) {
      return element;
    }
  }
  return null;
})()
"#;

fn upload_hint_change_script(token: &str) -> Result<String, RendererError> {
    let token = serde_json::to_string(token).map_err(render_error)?;
    Ok(UPLOAD_HINT_CHANGE_SCRIPT.replace("__TOKEN__", &token))
}

const UPLOAD_HINT_CHANGE_SCRIPT: &str = r#"
(() => {
  const token = __TOKEN__;
  const registry = window.__nvbrowserHintRegistry;
  if (!registry || !(registry.elements instanceof Map)) return false;
  let element = null;
  for (const entry of registry.elements.values()) {
    const candidate = entry && (entry.element || entry);
    if (candidate && candidate.isConnected && entry && entry.uploadToken === token) {
      element = candidate;
      break;
    }
  }
  if (!element || !element.isConnected) return false;
  if (typeof element.focus === 'function') {
    element.focus({ preventScroll: true });
  }
  element.dispatchEvent(new Event('input', { bubbles: true }));
  element.dispatchEvent(new Event('change', { bubbles: true }));
  return true;
})()
"#;

fn toggle_hint_script(hint_id: u32) -> Result<String, RendererError> {
    let hint_id = serde_json::to_string(&hint_id).map_err(render_error)?;
    Ok(TOGGLE_HINT_SCRIPT.replace("__HINT_ID__", &hint_id))
}

const TOGGLE_HINT_SCRIPT: &str = r#"
(() => {
  const hintId = __HINT_ID__;
  const registry = window.__nvbrowserHintRegistry;
  const entry = registry && registry.elements instanceof Map ? registry.elements.get(hintId) : null;
  const element = entry && (entry.element || entry);
  if (!element || !element.isConnected || element.tagName.toLowerCase() !== 'input') return false;
  if (element.disabled || element.getAttribute('aria-disabled') === 'true') return false;
  const type = (element.getAttribute('type') || 'text').toLowerCase();
  if (type !== 'checkbox' && type !== 'radio') return false;
  if (typeof element.focus === 'function') {
    element.focus({ preventScroll: true });
  }
  element.click();
  return true;
})()
"#;

const PAGE_METRICS_SCRIPT: &str = r#"
(() => {
  const root = document.documentElement;
  const body = document.body;
  const max = (...values) => Math.max(...values.filter((value) => Number.isFinite(value)));
  const documentWidth = max(
    root ? root.scrollWidth : 0,
    root ? root.clientWidth : 0,
    body ? body.scrollWidth : 0,
    body ? body.clientWidth : 0,
    window.innerWidth || 0
  );
  const documentHeight = max(
    root ? root.scrollHeight : 0,
    root ? root.clientHeight : 0,
    body ? body.scrollHeight : 0,
    body ? body.clientHeight : 0,
    window.innerHeight || 0
  );
  return JSON.stringify({
    scroll_x: window.scrollX || window.pageXOffset || 0,
    scroll_y: window.scrollY || window.pageYOffset || 0,
    viewport_width: window.innerWidth || (root ? root.clientWidth : 0) || 0,
    viewport_height: window.innerHeight || (root ? root.clientHeight : 0) || 0,
    document_width: documentWidth,
    document_height: documentHeight
  });
})()
"#;

const READY_STATE_SCRIPT: &str = r#"
(() => document.readyState || 'complete')()
"#;

const DOM_EPOCH_SCRIPT: &str = r#"
(() => {
  const key = '__nvbrowserDomEpochState';
  const global = globalThis || window;
  if (!global[key] || typeof global[key].epoch !== 'number') {
    const state = { epoch: 1 };
    Object.defineProperty(global, key, {
      value: state,
      configurable: true
    });
    const bump = () => {
      state.epoch += 1;
    };
    if (typeof MutationObserver === 'function') {
      const target = document.documentElement || document;
      if (target) {
        state.observer = new MutationObserver(bump);
        state.observer.observe(target, {
          subtree: true,
          childList: true,
          attributes: true,
          characterData: true
        });
      }
    }
    window.addEventListener('input', bump, true);
    window.addEventListener('change', bump, true);
  }
  return global[key].epoch;
})()
"#;

const DOM_QUIET_SCRIPT: &str = r#"
(() => new Promise((resolve) => {
  const quietMs = 120;
  const maxMs = 650;
  let quietTimer = null;
  let maxTimer = null;
  let observer = null;
  const finish = () => {
    if (quietTimer !== null) {
      clearTimeout(quietTimer);
    }
    if (maxTimer !== null) {
      clearTimeout(maxTimer);
    }
    if (observer !== null) {
      observer.disconnect();
    }
    resolve(true);
  };
  const scheduleQuiet = () => {
    if (quietTimer !== null) {
      clearTimeout(quietTimer);
    }
    quietTimer = setTimeout(finish, quietMs);
  };
  observer = new MutationObserver(scheduleQuiet);
  observer.observe(document.documentElement || document, {
    subtree: true,
    childList: true,
    attributes: true,
    characterData: true
  });
  maxTimer = setTimeout(finish, maxMs);
  scheduleQuiet();
}))()
"#;

const PAGE_TEXT_SCRIPT: &str = r#"
(() => {
  const maxLength = 120000;
  const root = document.querySelector('main, article') || document.body || document.documentElement;
  const title = (document.title || '').trim() || null;
  const parts = [];
  const seenLinks = new WeakSet();
  let length = 0;
  let truncated = false;
  const markdownText = (value) => value.replace(/\\/g, '\\\\').replace(/\]/g, '\\]');
  const markdownUrl = (value) => value.replace(/\\/g, '\\\\').replace(/\)/g, '\\)');
  const markdownLink = (label, url) => {
    const text = (label || url || '').replace(/\s+/g, ' ').trim();
    if (!text || !url) {
      return '';
    }
    return `[${markdownText(text)}](${markdownUrl(url)})`;
  };
  const append = (value) => {
    if (!value || truncated) {
      return;
    }
    const normalized = value.replace(/\r/g, '');
    if (!normalized.trim()) {
      return;
    }
    const remaining = maxLength - length;
    if (normalized.length > remaining) {
      parts.push(normalized.slice(0, Math.max(remaining, 0)));
      truncated = true;
      length = maxLength;
      return;
    }
    parts.push(normalized);
    length += normalized.length;
  };
  if (root) {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
      acceptNode: (node) => {
        const parent = node.parentElement;
        if (!parent) {
          return NodeFilter.FILTER_REJECT;
        }
        const tag = parent.tagName;
        if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'NOSCRIPT' || tag === 'TEMPLATE') {
          return NodeFilter.FILTER_REJECT;
        }
        const style = window.getComputedStyle(parent);
        if (style && (style.display === 'none' || style.visibility === 'hidden')) {
          return NodeFilter.FILTER_REJECT;
        }
        return NodeFilter.FILTER_ACCEPT;
      }
    });
    for (let node = walker.nextNode(); node && !truncated; node = walker.nextNode()) {
      const link = node.parentElement.closest('a[href]');
      if (link && root.contains(link)) {
        if (!seenLinks.has(link)) {
          seenLinks.add(link);
          append(markdownLink(link.textContent || '', link.href));
          if (!truncated) {
            parts.push('\n');
            length += 1;
          }
        }
        continue;
      }
      append(node.nodeValue || '');
      if (!truncated) {
        parts.push('\n');
        length += 1;
      }
    }
  }
  let text = parts.join('');
  text = text.replace(/\r/g, '').replace(/\n{3,}/g, '\n\n').trim();
  if (text.length > maxLength) {
    text = text.slice(0, maxLength).trimEnd();
    truncated = true;
  }
  const heading = title ? `# ${title}\n\n` : '';
  const url = location.href;
  return JSON.stringify({
    url,
    title,
    text: `${heading}${text}`,
    truncated
  });
})()
"#;

#[derive(Debug, Clone, Copy)]
enum HistoryDirection {
    Back,
    Forward,
}

#[derive(Debug, Serialize)]
struct GetNavigationHistory {}

impl Method for GetNavigationHistory {
    const NAME: &'static str = "Page.getNavigationHistory";

    type ReturnObject = GetNavigationHistoryReturnObject;
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct GetNavigationHistoryReturnObject {
    current_index: usize,
    entries: Vec<NavigationEntry>,
}

#[derive(Debug, Deserialize)]
struct NavigationEntry {
    id: i64,
    url: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct NavigateToHistoryEntry {
    entry_id: i64,
}

impl Method for NavigateToHistoryEntry {
    const NAME: &'static str = "Page.navigateToHistoryEntry";

    type ReturnObject = NavigateToHistoryEntryReturnObject;
}

#[derive(Debug, Deserialize)]
struct NavigateToHistoryEntryReturnObject {}

#[derive(Debug, Serialize)]
struct ClearDeviceMetricsOverride {}

impl Method for ClearDeviceMetricsOverride {
    const NAME: &'static str = "Emulation.clearDeviceMetricsOverride";

    type ReturnObject = ClearDeviceMetricsOverrideReturnObject;
}

#[derive(Debug, Deserialize)]
struct ClearDeviceMetricsOverrideReturnObject {}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct SetDeviceMetricsOverride {
    width: u32,
    height: u32,
    device_scale_factor: f64,
    mobile: bool,
}

impl Method for SetDeviceMetricsOverride {
    const NAME: &'static str = "Emulation.setDeviceMetricsOverride";

    type ReturnObject = SetDeviceMetricsOverrideReturnObject;
}

#[derive(Debug, Deserialize)]
struct SetDeviceMetricsOverrideReturnObject {}

#[derive(Debug, Clone, Copy, PartialEq)]
struct ZoomDeviceMetricsOverride {
    width: u32,
    height: u32,
    device_scale_factor: f64,
}

impl ZoomDeviceMetricsOverride {
    fn from_viewport(viewport: Viewport, scale: f64) -> Option<Self> {
        if (scale - 1.0).abs() < 0.005 {
            return None;
        }

        Some(Self {
            width: ((viewport.width as f64) / scale).round().max(1.0) as u32,
            height: ((viewport.height as f64) / scale).round().max(1.0) as u32,
            device_scale_factor: f64::from(viewport.device_scale_factor),
        })
    }
}

fn launch_browser(
    binary: &Path,
    viewport: Viewport,
    user_data_dir: Option<&Path>,
) -> Result<Browser, RendererError> {
    let options = build_launch_options(binary, viewport, user_data_dir)?;

    Browser::new(options).map_err(|error| {
        RendererError::new(
            RendererErrorKind::BackendUnavailable,
            format!("failed to launch Chrome: {error}"),
        )
    })
}

fn build_launch_options(
    binary: &Path,
    viewport: Viewport,
    user_data_dir: Option<&Path>,
) -> Result<LaunchOptions<'static>, RendererError> {
    LaunchOptions::default_builder()
        .path(Some(binary.to_path_buf()))
        .user_data_dir(user_data_dir.map(Path::to_path_buf))
        .window_size(Some((viewport.width, viewport.height)))
        .idle_browser_timeout(BROWSER_IDLE_TIMEOUT)
        .sandbox(false)
        .args(vec![OsStr::new("--disable-popup-blocking")])
        .build()
        .map_err(|error| {
            RendererError::new(
                RendererErrorKind::BackendUnavailable,
                format!("failed to build Chrome launch options: {error}"),
            )
        })
}

fn open_browser(options: &ChromiumOptions, viewport: Viewport) -> Result<Browser, RendererError> {
    let browser = match options.browser_source()? {
        BrowserSource::Connect(cdp_ws_url) => connect_browser(&cdp_ws_url),
        BrowserSource::Launch(binary) => {
            launch_browser(&binary, viewport, options.user_data_dir.as_deref())
        }
    }?;
    browser.set_default_timeout(options.navigation_timeout());
    Ok(browser)
}

fn connect_browser(cdp_ws_url: &str) -> Result<Browser, RendererError> {
    Browser::connect_with_timeout(cdp_ws_url.to_string(), BROWSER_IDLE_TIMEOUT).map_err(|error| {
        RendererError::new(
            RendererErrorKind::BackendUnavailable,
            format!("failed to connect to Chrome CDP websocket: {error}"),
        )
    })
}

fn configure_download_behavior(
    tab: &Arc<Tab>,
    download_dir: Option<&Path>,
) -> Result<Option<DownloadEventTracker>, RendererError> {
    let Some(download_dir) = download_dir else {
        return Ok(None);
    };
    std::fs::create_dir_all(download_dir).map_err(|error| {
        RendererError::new(
            RendererErrorKind::BackendUnavailable,
            format!(
                "failed to create download directory {}: {error}",
                download_dir.display()
            ),
        )
    })?;
    if !download_dir.is_dir() {
        return Err(RendererError::new(
            RendererErrorKind::BackendUnavailable,
            format!(
                "download directory is not a directory: {}",
                download_dir.display()
            ),
        ));
    }

    tab.call_method(Page::SetDownloadBehavior {
        behavior: SetDownloadBehaviorBehaviorOption::Allow,
        download_path: Some(download_dir.to_string_lossy().into_owned()),
    })
    .map_err(|error| {
        RendererError::new(
            RendererErrorKind::BackendUnavailable,
            format!("failed to configure Chrome download directory: {error}"),
        )
    })?;

    let (tx, rx) = mpsc::channel();
    tab.add_event_listener(Arc::new(move |event: &Event| match event {
        Event::PageDownloadWillBegin(event) => {
            let _ = tx.send(DownloadEvent::WillBegin {
                guid: event.params.guid.clone(),
                suggested_filename: event.params.suggested_filename.clone(),
            });
        }
        Event::PageDownloadProgress(event)
            if event.params.state == Page::DownloadProgressEventStateOption::Completed =>
        {
            let _ = tx.send(DownloadEvent::Completed {
                guid: event.params.guid.clone(),
            });
        }
        _ => {}
    }))
    .map_err(|error| {
        RendererError::new(
            RendererErrorKind::BackendUnavailable,
            format!("failed to observe Chrome download events: {error}"),
        )
    })?;

    Ok(Some(DownloadEventTracker {
        rx,
        filenames: HashMap::new(),
        known_paths: list_completed_download_paths(download_dir),
    }))
}

fn list_completed_download_paths(download_dir: &Path) -> HashSet<PathBuf> {
    std::fs::read_dir(download_dir)
        .ok()
        .into_iter()
        .flat_map(|entries| entries.flatten())
        .map(|entry| entry.path())
        .filter(|path| {
            path.is_file()
                && path
                    .extension()
                    .and_then(|extension| extension.to_str())
                    .is_none_or(|extension| extension != "crdownload")
        })
        .collect()
}

fn detect_new_completed_download(
    download_dir: &Path,
    known_paths: &mut HashSet<PathBuf>,
    since: SystemTime,
) -> Option<DownloadInfo> {
    let mut candidates: Vec<PathBuf> = list_completed_download_paths(download_dir)
        .into_iter()
        .filter(|path| {
            if known_paths.contains(path) {
                return false;
            }
            if path_modified_before(path, since) {
                known_paths.insert(path.clone());
                return false;
            }
            true
        })
        .collect();
    candidates.sort();
    let path = candidates.into_iter().next()?;
    known_paths.insert(path.clone());
    let suggested_filename = path
        .file_name()
        .and_then(|filename| filename.to_str())
        .map(str::to_string);
    Some(DownloadInfo::completed(path, suggested_filename))
}

fn detect_new_completed_downloads(
    download_dir: &Path,
    known_paths: &mut HashSet<PathBuf>,
    since: SystemTime,
) -> Vec<DownloadInfo> {
    let mut downloads = Vec::new();
    while let Some(download) = detect_new_completed_download(download_dir, known_paths, since) {
        downloads.push(download);
    }
    downloads
}

fn has_active_chromium_download(download_dir: &Path, since: SystemTime) -> bool {
    std::fs::read_dir(download_dir)
        .ok()
        .into_iter()
        .flat_map(|entries| entries.flatten())
        .map(|entry| entry.path())
        .any(|path| {
            path.extension()
                .and_then(|extension| extension.to_str())
                .is_some_and(|extension| extension == "crdownload")
                && !path_modified_before(&path, since)
        })
}

fn path_modified_before(path: &Path, since: SystemTime) -> bool {
    path.metadata()
        .and_then(|metadata| metadata.modified())
        .map(|modified| modified < since)
        .unwrap_or(false)
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum MouseDispatchButton {
    Left,
    Right,
}

#[derive(Debug, Clone, PartialEq)]
struct MouseDispatchOptions {
    button: Option<Input::MouseButton>,
    buttons: Option<u32>,
    click_count: Option<u32>,
}

impl MouseDispatchButton {
    const fn cdp_button(self) -> Input::MouseButton {
        match self {
            Self::Left => Input::MouseButton::Left,
            Self::Right => Input::MouseButton::Right,
        }
    }

    const fn buttons_mask(self) -> u32 {
        match self {
            Self::Left => 1,
            Self::Right => 2,
        }
    }
}

fn mouse_dispatch_options(
    event_type: &Input::DispatchMouseEventTypeOption,
    button: MouseDispatchButton,
) -> MouseDispatchOptions {
    let is_press_or_release = matches!(
        event_type,
        &Input::DispatchMouseEventTypeOption::MousePressed
            | &Input::DispatchMouseEventTypeOption::MouseReleased
    );
    MouseDispatchOptions {
        button: is_press_or_release.then_some(button.cdp_button()),
        buttons: Some(if is_press_or_release {
            button.buttons_mask()
        } else {
            0
        }),
        click_count: is_press_or_release.then_some(1),
    }
}

fn dispatch_mouse_click(tab: &Arc<Tab>, x: f64, y: f64) -> Result<(), RendererError> {
    dispatch_mouse_click_with_button(tab, x, y, MouseDispatchButton::Left)
}

fn dispatch_mouse_click_with_button(
    tab: &Arc<Tab>,
    x: f64,
    y: f64,
    button: MouseDispatchButton,
) -> Result<(), RendererError> {
    dispatch_mouse_event(
        tab,
        Input::DispatchMouseEventTypeOption::MouseMoved,
        x,
        y,
        button,
    )?;
    dispatch_mouse_event(
        tab,
        Input::DispatchMouseEventTypeOption::MousePressed,
        x,
        y,
        button,
    )?;
    dispatch_mouse_event(
        tab,
        Input::DispatchMouseEventTypeOption::MouseReleased,
        x,
        y,
        button,
    )
}

fn dispatch_mouse_drag(
    tab: &Arc<Tab>,
    start_x: f64,
    start_y: f64,
    end_x: f64,
    end_y: f64,
) -> Result<(), RendererError> {
    dispatch_mouse_event(
        tab,
        Input::DispatchMouseEventTypeOption::MouseMoved,
        start_x,
        start_y,
        MouseDispatchButton::Left,
    )?;
    dispatch_mouse_event(
        tab,
        Input::DispatchMouseEventTypeOption::MousePressed,
        start_x,
        start_y,
        MouseDispatchButton::Left,
    )?;
    for step in 1..=4 {
        let ratio = step as f64 / 4.0;
        let x = start_x + (end_x - start_x) * ratio;
        let y = start_y + (end_y - start_y) * ratio;
        dispatch_mouse_drag_move(tab, x, y)?;
    }
    dispatch_mouse_event(
        tab,
        Input::DispatchMouseEventTypeOption::MouseReleased,
        end_x,
        end_y,
        MouseDispatchButton::Left,
    )
}

fn dispatch_mouse_drag_move(tab: &Arc<Tab>, x: f64, y: f64) -> Result<(), RendererError> {
    let options = mouse_drag_move_options(MouseDispatchButton::Left);
    tab.call_method(Input::DispatchMouseEvent {
        Type: Input::DispatchMouseEventTypeOption::MouseMoved,
        x,
        y,
        modifiers: None,
        timestamp: None,
        button: options.button,
        buttons: options.buttons,
        click_count: options.click_count,
        force: None,
        tangential_pressure: None,
        tilt_x: None,
        tilt_y: None,
        twist: None,
        delta_x: None,
        delta_y: None,
        pointer_Type: None,
    })
    .map(|_| ())
    .map_err(render_error)
}

fn mouse_drag_move_options(button: MouseDispatchButton) -> MouseDispatchOptions {
    MouseDispatchOptions {
        button: Some(button.cdp_button()),
        buttons: Some(button.buttons_mask()),
        click_count: None,
    }
}

fn dispatch_mouse_event(
    tab: &Arc<Tab>,
    event_type: Input::DispatchMouseEventTypeOption,
    x: f64,
    y: f64,
    button: MouseDispatchButton,
) -> Result<(), RendererError> {
    let options = mouse_dispatch_options(&event_type, button);
    tab.call_method(Input::DispatchMouseEvent {
        Type: event_type,
        x,
        y,
        modifiers: None,
        timestamp: None,
        button: options.button,
        buttons: options.buttons,
        click_count: options.click_count,
        force: None,
        tangential_pressure: None,
        tilt_x: None,
        tilt_y: None,
        twist: None,
        delta_x: None,
        delta_y: None,
        pointer_Type: None,
    })
    .map(|_| ())
    .map_err(render_error)
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

fn apply_page_zoom(tab: &Tab, viewport: Viewport, scale: f64) -> Result<(), RendererError> {
    match ZoomDeviceMetricsOverride::from_viewport(viewport, scale) {
        Some(metrics) => {
            tab.call_method(SetDeviceMetricsOverride {
                width: metrics.width,
                height: metrics.height,
                device_scale_factor: metrics.device_scale_factor,
                mobile: false,
            })
            .map_err(render_error)?;
        }
        None => {
            tab.call_method(ClearDeviceMetricsOverride {})
                .map_err(render_error)?;
        }
    };
    Ok(())
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum DialogPolicy {
    Accept,
    Dismiss,
}

fn default_dialog_policy(dialog_type: &DialogType) -> DialogPolicy {
    match dialog_type {
        DialogType::Alert => DialogPolicy::Accept,
        DialogType::Confirm | DialogType::Prompt | DialogType::Beforeunload => {
            DialogPolicy::Dismiss
        }
    }
}

fn dialog_kind(dialog_type: &DialogType) -> DialogKind {
    match dialog_type {
        DialogType::Alert => DialogKind::Alert,
        DialogType::Confirm => DialogKind::Confirm,
        DialogType::Prompt => DialogKind::Prompt,
        DialogType::Beforeunload => DialogKind::Beforeunload,
    }
}

fn dialog_action(policy: DialogPolicy) -> DialogAction {
    match policy {
        DialogPolicy::Accept => DialogAction::Accepted,
        DialogPolicy::Dismiss => DialogAction::Dismissed,
    }
}

fn dialog_event(dialog_type: &DialogType, message: impl Into<String>) -> DialogEvent {
    let policy = default_dialog_policy(dialog_type);
    DialogEvent {
        kind: dialog_kind(dialog_type),
        message: message.into(),
        action: dialog_action(policy),
    }
}

fn install_default_dialog_handler(
    tab: &Arc<Tab>,
    event_tx: Option<mpsc::Sender<DialogEvent>>,
) -> Result<(), RendererError> {
    let dialog = tab.get_dialog();
    let (dialog_tx, dialog_rx) = mpsc::channel::<DialogPolicy>();
    thread::Builder::new()
        .name("nvbrowser-dialog-handler".to_string())
        .spawn(move || {
            while let Ok(policy) = dialog_rx.recv() {
                let _ = match policy {
                    DialogPolicy::Accept => dialog.accept(None),
                    DialogPolicy::Dismiss => dialog.dismiss(),
                };
            }
        })
        .map_err(render_error)?;

    tab.add_event_listener(Arc::new(move |event: &Event| {
        if let Event::PageJavascriptDialogOpening(event) = event {
            let policy = default_dialog_policy(&event.params.Type);
            if let Some(event_tx) = event_tx.as_ref() {
                let _ = event_tx.send(dialog_event(
                    &event.params.Type,
                    event.params.message.clone(),
                ));
            }
            let _ = dialog_tx.send(policy);
        }
    }))
    .map(|_| ())
    .map_err(render_error)
}

fn install_dom_epoch_observer(tab: &Arc<Tab>) -> Result<(), RendererError> {
    tab.call_method(Page::AddScriptToEvaluateOnNewDocument {
        source: DOM_EPOCH_SCRIPT.to_string(),
        world_name: None,
        include_command_line_api: None,
        run_immediately: None,
    })
    .map(|_| ())
    .map_err(render_error)
}

fn viewport_clip(viewport: Viewport) -> CdpViewport {
    CdpViewport {
        x: 0.0,
        y: 0.0,
        width: viewport.width as f64,
        height: viewport.height as f64,
        scale: 1.0,
    }
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

fn navigation_start_error(url: &str, error: impl std::fmt::Display) -> RendererError {
    RendererError::new(
        RendererErrorKind::NavigationFailed,
        format!("navigation failed for {url}: {error}"),
    )
}

fn navigation_timeout_error(
    url: &str,
    timeout_ms: u64,
    error: impl std::fmt::Display,
) -> RendererError {
    RendererError::new(
        RendererErrorKind::NavigationFailed,
        format!("navigation timed out after {timeout_ms}ms: {url}: {error}"),
    )
}

fn wait_until_navigated(tab: &Tab, url: &str, timeout_ms: u64) -> Result<(), RendererError> {
    tab.wait_until_navigated()
        .map(|_| ())
        .map_err(|error| navigation_timeout_error(url, timeout_ms, error))
}

fn configure_tab_timeout(tab: &Tab, options: &ChromiumOptions) {
    configure_tab_timeout_ms(tab, options.navigation_timeout_ms);
}

fn configure_tab_timeout_ms(tab: &Tab, navigation_timeout_ms: u64) {
    tab.set_default_timeout(Duration::from_millis(navigation_timeout_ms));
}

fn parse_navigation_timeout_ms(value: Option<String>) -> u64 {
    value
        .and_then(|value| value.parse::<u64>().ok())
        .filter(|value| *value > 0)
        .unwrap_or(DEFAULT_NAVIGATION_TIMEOUT_MS)
}

fn render_context_error(context: &str, error: impl std::fmt::Display) -> RendererError {
    RendererError::new(
        RendererErrorKind::RenderFailed,
        format!("{context}: {error}"),
    )
}

fn context_renderer_error(context: &str, error: RendererError) -> RendererError {
    RendererError::new(error.kind(), format!("{context}: {}", error.message()))
}

fn is_closed_target_error(error: &RendererError) -> bool {
    error.kind() == RendererErrorKind::RenderFailed
        && error.message().contains("underlying connection is closed")
}

fn popup_opening_mouse_recovery_deadline(
    error: &RendererError,
    now: std::time::Instant,
) -> Option<std::time::Instant> {
    if is_closed_target_error(error) {
        return Some(now + Duration::from_millis(750));
    }

    None
}

const SELECTION_TEXT_SCRIPT: &str = r#"
(() => {
  const active = document.activeElement;
  const isTextArea = active && active.tagName === 'TEXTAREA';
  const isTextInput =
    active &&
    active.tagName === 'INPUT' &&
    typeof active.selectionStart === 'number' &&
    typeof active.selectionEnd === 'number';

  if (isTextArea || isTextInput) {
    const start = active.selectionStart;
    const end = active.selectionEnd;
    if (typeof start === 'number' && typeof end === 'number' && end > start) {
      return active.value.slice(start, end);
    }
  }

  const selection = window.getSelection && window.getSelection();
  return selection ? selection.toString() : '';
})()
"#;

fn chromium_key_with_modifiers(key: &str) -> (&str, Vec<ModifierKey>) {
    let Some((modifiers, base_key)) = key.rsplit_once('+') else {
        return (key, Vec::new());
    };
    let mut parsed = Vec::new();
    for modifier in modifiers.split('+') {
        match modifier.to_ascii_lowercase().as_str() {
            "alt" => parsed.push(ModifierKey::Alt),
            "ctrl" | "control" => parsed.push(ModifierKey::Ctrl),
            "meta" | "cmd" | "command" => parsed.push(ModifierKey::Meta),
            "shift" => parsed.push(ModifierKey::Shift),
            _ => return (key, Vec::new()),
        }
    }
    if parsed.is_empty() {
        (key, Vec::new())
    } else {
        (base_key, parsed)
    }
}

fn parse_page_metrics_json(metrics: &str) -> Result<PageMetrics, serde_json::Error> {
    serde_json::from_str(metrics)
}

fn parse_focused_element_json(text: &str) -> Result<FocusedElement, serde_json::Error> {
    serde_json::from_str(text)
}

fn find_text_script(query: &str, backwards: bool) -> Result<String, RendererError> {
    let query = serde_json::to_string(query).map_err(render_error)?;
    Ok(format!(
        r#"(function() {{
  const query = {query};
  const found = window.find(query, false, {backwards}, true, false, true, false);
  const text = (document.body && document.body.innerText) || "";
  const needle = String(query).toLocaleLowerCase();
  const haystack = String(text).toLocaleLowerCase();
  let match_count = 0;
  if (needle.length > 0) {{
    let index = haystack.indexOf(needle);
    while (index !== -1) {{
      match_count += 1;
      index = haystack.indexOf(needle, index + needle.length);
    }}
  }}
  return JSON.stringify({{ found, match_count }});
}})()"#
    ))
}

#[derive(Debug, Deserialize)]
struct FindTextScriptResult {
    found: bool,
    match_count: u32,
}

fn parse_find_text_json(text: &str) -> Result<FindTextScriptResult, serde_json::Error> {
    serde_json::from_str(text)
}

#[derive(Debug, Deserialize)]
struct ExtractedPageText {
    url: String,
    title: Option<String>,
    text: String,
    truncated: bool,
}

#[derive(Debug, Deserialize)]
struct HintPoint {
    x: f64,
    y: f64,
}

#[derive(Debug, Deserialize)]
struct UploadHintTarget {
    ok: bool,
    token: Option<String>,
    error: Option<String>,
}

fn parse_page_text_json(text: &str) -> Result<ExtractedPageText, serde_json::Error> {
    serde_json::from_str(text)
}

fn parse_hint_point_json(value: serde_json::Value) -> Result<HintPoint, RendererError> {
    let text = value.as_str().ok_or_else(|| {
        RendererError::new(
            RendererErrorKind::InvalidState,
            "hint id was not found or is stale",
        )
    })?;
    serde_json::from_str(text).map_err(render_error)
}

fn parse_upload_hint_target_json(
    value: serde_json::Value,
) -> Result<ResolvedUploadHintTarget, RendererError> {
    let text = value.as_str().ok_or_else(|| {
        RendererError::new(
            RendererErrorKind::InvalidState,
            "hint id was not a file input, was stale, or was disabled",
        )
    })?;
    let target: UploadHintTarget = serde_json::from_str(text).map_err(render_error)?;
    if !target.ok {
        return Err(RendererError::new(
            RendererErrorKind::InvalidState,
            target
                .error
                .unwrap_or_else(|| "hint file upload target was invalid".to_string()),
        ));
    }
    let token = target.token.ok_or_else(|| {
        RendererError::new(
            RendererErrorKind::InvalidState,
            "hint file upload target did not return a token",
        )
    })?;
    Ok(ResolvedUploadHintTarget { token })
}

fn parse_element_hints_json(text: &str) -> Result<Vec<ElementHint>, RendererError> {
    serde_json::from_str(text).map_err(render_error)
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct ResolvedUploadHintTarget {
    token: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct InteractionSettleSample {
    url: String,
    title: Option<String>,
    ready_state: Option<String>,
}

impl InteractionSettleSample {
    #[cfg(test)]
    fn new(
        url: impl Into<String>,
        title: Option<&str>,
        ready_state: Option<&str>,
    ) -> InteractionSettleSample {
        InteractionSettleSample {
            url: url.into(),
            title: title.map(str::to_string),
            ready_state: ready_state.map(str::to_string),
        }
    }

    fn is_loading(&self) -> bool {
        self.ready_state.as_deref() != Some("complete")
    }
}

fn choose_interaction_settle_sample(
    samples: &[InteractionSettleSample],
    required_stable_samples: usize,
) -> Option<InteractionSettleSample> {
    let latest = samples.last()?.clone();
    if latest.is_loading() {
        return None;
    }

    let mut stable_count = 0;
    for sample in samples.iter().rev() {
        if sample.url == latest.url && sample.title == latest.title && !sample.is_loading() {
            stable_count += 1;
            if stable_count >= required_stable_samples {
                return Some(latest);
            }
        } else {
            break;
        }
    }

    None
}

fn latest_interaction_settle_sample(
    samples: &[InteractionSettleSample],
) -> Option<InteractionSettleSample> {
    samples.last().cloned()
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct TargetCandidate {
    id: String,
    url: String,
    previously_known: bool,
}

fn choose_new_page_target_id(
    active_target_id: &str,
    candidates: &[TargetCandidate],
    pending_page_target_ids: &HashSet<String>,
) -> Option<String> {
    candidates
        .iter()
        .rev()
        .find(|candidate| {
            candidate.id != active_target_id
                && (!candidate.previously_known || pending_page_target_ids.contains(&candidate.id))
                && is_adoptable_page_url(&candidate.url)
        })
        .map(|candidate| candidate.id.clone())
}

fn mark_observed_targets_known(
    known_target_ids: &mut HashSet<String>,
    pending_page_target_ids: &mut HashSet<String>,
    candidates: &[TargetCandidate],
) {
    track_pending_page_targets(known_target_ids, pending_page_target_ids, candidates);
    known_target_ids.extend(candidates.iter().map(|candidate| candidate.id.clone()));
}

fn track_pending_page_targets(
    known_target_ids: &mut HashSet<String>,
    pending_page_target_ids: &mut HashSet<String>,
    candidates: &[TargetCandidate],
) {
    let present_target_ids = candidates
        .iter()
        .map(|candidate| candidate.id.as_str())
        .collect::<HashSet<_>>();
    pending_page_target_ids.retain(|target_id| present_target_ids.contains(target_id.as_str()));

    for candidate in candidates {
        if pending_page_target_ids.contains(&candidate.id) && is_internal_page_url(&candidate.url) {
            pending_page_target_ids.remove(&candidate.id);
        }
        if candidate.previously_known {
            continue;
        }
        if is_pending_new_page_url(&candidate.url) {
            pending_page_target_ids.insert(candidate.id.clone());
            known_target_ids.insert(candidate.id.clone());
        } else if is_internal_page_url(&candidate.url) {
            known_target_ids.insert(candidate.id.clone());
        }
    }
}

fn has_unknown_targets(
    candidates: &[TargetCandidate],
    pending_page_target_ids: &HashSet<String>,
) -> bool {
    candidates.iter().any(|candidate| {
        !candidate.previously_known
            && !pending_page_target_ids.contains(&candidate.id)
            && !is_internal_page_url(&candidate.url)
    })
}

fn is_pending_new_page_url(url: &str) -> bool {
    url.trim() == "about:blank"
}

fn is_adoptable_page_url(url: &str) -> bool {
    let url = url.trim();
    !url.is_empty() && !is_pending_new_page_url(url) && !is_internal_page_url(url)
}

fn is_internal_page_url(url: &str) -> bool {
    let url = url.trim();
    url.starts_with("devtools:")
        || url.starts_with("chrome:")
        || url.starts_with("chrome-extension:")
}

fn collect_tab_target_ids(browser: &Browser) -> HashSet<String> {
    browser
        .get_tabs()
        .lock()
        .map(|tabs| {
            tabs.iter()
                .map(|tab| tab.get_target_id().clone())
                .collect::<HashSet<_>>()
        })
        .unwrap_or_default()
}

fn non_empty_string(value: String) -> Option<String> {
    let value = value.trim().to_string();
    if value.is_empty() {
        None
    } else {
        Some(value)
    }
}

fn non_empty_path(value: PathBuf) -> Option<PathBuf> {
    if value.as_os_str().is_empty() {
        None
    } else {
        Some(value)
    }
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
    fn chromium_options_from_env_values_captures_cdp_ws_url() {
        let options = ChromiumOptions::from_env_values(
            Some("ws://127.0.0.1:9222/devtools/browser/test".to_string()),
            None,
            Some(PathBuf::from("/tmp/nvbrowser-profile")),
            Some(PathBuf::from("/tmp/nvbrowser-downloads")),
            Some("1234".to_string()),
        );

        assert_eq!(
            options.cdp_ws_url.as_deref(),
            Some("ws://127.0.0.1:9222/devtools/browser/test")
        );
        assert_eq!(options.binary, None);
        assert_eq!(
            options.user_data_dir,
            Some(PathBuf::from("/tmp/nvbrowser-profile"))
        );
        assert_eq!(
            options.download_dir,
            Some(PathBuf::from("/tmp/nvbrowser-downloads"))
        );
        assert_eq!(options.navigation_timeout_ms, 1234);
    }

    #[test]
    fn chromium_options_from_env_values_ignores_empty_user_data_dir() {
        let options =
            ChromiumOptions::from_env_values(None, None, Some(PathBuf::from("")), None, None);

        assert_eq!(options.user_data_dir, None);
        assert_eq!(options.navigation_timeout_ms, 20_000);
    }

    #[test]
    fn chromium_options_from_env_values_ignores_empty_download_dir() {
        let options =
            ChromiumOptions::from_env_values(None, None, None, Some(PathBuf::from("")), None);

        assert_eq!(options.download_dir, None);
    }

    #[test]
    fn popup_opening_mouse_recovery_deadline_handles_closed_target_errors() {
        let now = std::time::Instant::now();
        let error = RendererError::new(
            RendererErrorKind::RenderFailed,
            "hint click failed: underlying connection is closed",
        );

        let deadline = popup_opening_mouse_recovery_deadline(&error, now).expect(
            "closed target click errors should start a target-registration suppression window",
        );

        assert!(deadline > now);
        assert!(deadline <= now + Duration::from_millis(750));
    }

    #[test]
    fn popup_opening_mouse_recovery_deadline_rejects_other_errors() {
        let now = std::time::Instant::now();
        let error = RendererError::new(RendererErrorKind::RenderFailed, "hint click failed: boom");
        let hint_right_error = RendererError::new(
            RendererErrorKind::RenderFailed,
            "hint right click failed: boom",
        );
        let point_right_error = RendererError::new(
            RendererErrorKind::RenderFailed,
            "point right click failed: boom",
        );

        let recovered = popup_opening_mouse_recovery_deadline(&error, now);
        let hint_right_recovered = popup_opening_mouse_recovery_deadline(&hint_right_error, now);
        let point_right_recovered = popup_opening_mouse_recovery_deadline(&point_right_error, now);

        assert_eq!(recovered, None);
        assert_eq!(hint_right_recovered, None);
        assert_eq!(point_right_recovered, None);
    }

    #[test]
    fn popup_opening_mouse_recovery_deadline_handles_right_click_closed_target_errors() {
        let now = std::time::Instant::now();
        let hint_error = RendererError::new(
            RendererErrorKind::RenderFailed,
            "hint right click failed: underlying connection is closed",
        );
        let point_error = RendererError::new(
            RendererErrorKind::RenderFailed,
            "point right click failed: underlying connection is closed",
        );

        let hint_deadline = popup_opening_mouse_recovery_deadline(&hint_error, now)
            .expect("closed target hint right-click errors should start popup recovery");
        let point_deadline = popup_opening_mouse_recovery_deadline(&point_error, now)
            .expect("closed target point right-click errors should start popup recovery");

        assert!(hint_deadline > now);
        assert!(hint_deadline <= now + Duration::from_millis(750));
        assert!(point_deadline > now);
        assert!(point_deadline <= now + Duration::from_millis(750));
    }

    #[test]
    fn detects_new_completed_download_files_without_reporting_known_paths() {
        let directory =
            std::env::temp_dir().join(format!("nvbrowser-download-detect-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&directory);
        std::fs::create_dir_all(&directory).expect("tempdir should be created");
        let known_path = directory.join("known.txt");
        std::fs::write(&known_path, "known").expect("known fixture should be written");
        let mut known_paths = list_completed_download_paths(&directory);
        let interaction_started = SystemTime::now();

        assert!(
            detect_new_completed_download(&directory, &mut known_paths, interaction_started)
                .is_none(),
            "existing files should not be reported as fresh downloads"
        );

        let partial_path = directory.join("partial.txt.crdownload");
        std::fs::write(&partial_path, "partial").expect("partial fixture should be written");
        assert!(
            detect_new_completed_download(&directory, &mut known_paths, interaction_started)
                .is_none(),
            "temporary Chromium download files should not be reported as completed"
        );

        let download_path = directory.join("report.txt");
        std::fs::write(&download_path, "download").expect("download fixture should be written");
        let download =
            detect_new_completed_download(&directory, &mut known_paths, interaction_started)
                .expect("new completed download should be reported");

        assert_eq!(download.path, download_path);
        assert_eq!(download.suggested_filename.as_deref(), Some("report.txt"));
        assert!(
            detect_new_completed_download(&directory, &mut known_paths, interaction_started)
                .is_none(),
            "reported downloads should become known"
        );
        let _ = std::fs::remove_dir_all(directory);
    }

    #[test]
    fn detects_multiple_new_completed_download_files_in_order() {
        let directory = std::env::temp_dir().join(format!(
            "nvbrowser-download-detect-many-{}",
            std::process::id()
        ));
        let _ = std::fs::remove_dir_all(&directory);
        std::fs::create_dir_all(&directory).expect("tempdir should be created");
        let mut known_paths = list_completed_download_paths(&directory);
        let interaction_started = SystemTime::now();

        let first_path = directory.join("a-report.txt");
        let second_path = directory.join("b-report.txt");
        std::fs::write(&second_path, "download 2").expect("second fixture should be written");
        std::fs::write(&first_path, "download 1").expect("first fixture should be written");

        let downloads =
            detect_new_completed_downloads(&directory, &mut known_paths, interaction_started);

        assert_eq!(downloads.len(), 2);
        assert_eq!(downloads[0].path, first_path);
        assert_eq!(downloads[1].path, second_path);
        assert!(
            detect_new_completed_downloads(&directory, &mut known_paths, interaction_started)
                .is_empty(),
            "reported downloads should become known"
        );
        let _ = std::fs::remove_dir_all(directory);
    }

    #[test]
    fn single_download_detection_marks_only_one_candidate_known() {
        let directory = std::env::temp_dir().join(format!(
            "nvbrowser-download-detect-single-{}",
            std::process::id()
        ));
        let _ = std::fs::remove_dir_all(&directory);
        std::fs::create_dir_all(&directory).expect("tempdir should be created");
        let mut known_paths = list_completed_download_paths(&directory);
        let interaction_started = SystemTime::now();

        let first_path = directory.join("a-report.txt");
        let second_path = directory.join("b-report.txt");
        std::fs::write(&first_path, "download 1").expect("first fixture should be written");
        std::fs::write(&second_path, "download 2").expect("second fixture should be written");

        let first =
            detect_new_completed_download(&directory, &mut known_paths, interaction_started)
                .expect("first completed download should be reported");
        let second =
            detect_new_completed_download(&directory, &mut known_paths, interaction_started)
                .expect("second completed download should remain available");

        assert_eq!(first.path, first_path);
        assert_eq!(second.path, second_path);
        let _ = std::fs::remove_dir_all(directory);
    }

    #[test]
    fn chromium_options_from_env_values_ignores_invalid_navigation_timeout() {
        let options = ChromiumOptions::from_env_values(
            None,
            None,
            None,
            None,
            Some("not-a-number".to_string()),
        );

        assert_eq!(options.navigation_timeout_ms, 20_000);
    }

    #[test]
    fn navigation_start_error_does_not_report_timeout() {
        let error = navigation_start_error("https://example.com", "invalid URL");

        assert_eq!(error.kind(), RendererErrorKind::NavigationFailed);
        assert!(error
            .message()
            .contains("navigation failed for https://example.com"));
        assert!(!error.message().contains("timed out"));
    }

    #[test]
    fn navigation_timeout_error_includes_url_and_timeout() {
        let error = navigation_timeout_error("https://example.com", 1234, "deadline elapsed");

        assert_eq!(error.kind(), RendererErrorKind::NavigationFailed);
        assert!(error
            .message()
            .contains("navigation timed out after 1234ms"));
        assert!(error.message().contains("https://example.com"));
    }

    #[test]
    fn chromium_options_detect_reads_user_data_dir_env() {
        let previous = std::env::var_os("NVBROWSER_USER_DATA_DIR");
        std::env::set_var("NVBROWSER_USER_DATA_DIR", "/tmp/nvbrowser-profile-from-env");

        let options = ChromiumOptions::detect();

        match previous {
            Some(value) => std::env::set_var("NVBROWSER_USER_DATA_DIR", value),
            None => std::env::remove_var("NVBROWSER_USER_DATA_DIR"),
        }

        assert_eq!(
            options.user_data_dir,
            Some(PathBuf::from("/tmp/nvbrowser-profile-from-env"))
        );
    }

    #[test]
    fn chromium_backend_diagnostics_prefers_cdp_over_binary() {
        let diagnostics = ChromiumOptions::from_env_values(
            Some("ws://127.0.0.1:9222/devtools/browser/test".to_string()),
            Some(PathBuf::from(
                "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            )),
            Some(PathBuf::from("/tmp/nvbrowser-profile")),
            None,
            None,
        )
        .backend_diagnostics();

        assert_eq!(diagnostics.status, "available");
        assert_eq!(diagnostics.source, "cdp");
        assert_eq!(
            diagnostics.cdp_ws_url.as_deref(),
            Some("ws://127.0.0.1:9222/devtools/browser/test")
        );
        assert_eq!(
            diagnostics.chrome_binary.as_deref(),
            Some("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
        );
        assert_eq!(
            diagnostics.user_data_dir.as_deref(),
            Some("/tmp/nvbrowser-profile")
        );
        assert!(diagnostics.warning.is_none());
    }

    #[test]
    fn chromium_backend_diagnostics_reports_explicit_chrome_binary() {
        let chrome_path =
            std::env::temp_dir().join(format!("nvbrowser-test-chrome-{}", std::process::id()));
        std::fs::write(&chrome_path, "").expect("chrome fixture should be written");
        #[cfg(unix)]
        {
            let mut permissions = std::fs::metadata(&chrome_path)
                .expect("chrome fixture metadata should exist")
                .permissions();
            permissions.set_mode(0o755);
            std::fs::set_permissions(&chrome_path, permissions)
                .expect("chrome fixture should be executable");
        }
        let diagnostics =
            ChromiumOptions::from_env_values(None, Some(chrome_path.clone()), None, None, None)
                .backend_diagnostics();

        assert_eq!(diagnostics.status, "available");
        assert_eq!(diagnostics.source, "chrome");
        assert!(diagnostics.cdp_ws_url.is_none());
        assert_eq!(
            diagnostics.chrome_binary.as_deref(),
            Some(chrome_path.to_string_lossy().as_ref())
        );
        assert!(diagnostics.warning.is_none());
        let _ = std::fs::remove_file(chrome_path);
    }

    #[test]
    fn chromium_backend_diagnostics_reports_invalid_chrome_binary_as_missing() {
        let diagnostics = ChromiumOptions::from_env_values(
            None,
            Some(PathBuf::from("/definitely/not/nvbrowser-chrome")),
            None,
            None,
            None,
        )
        .backend_diagnostics();

        assert_eq!(diagnostics.status, "missing");
        assert_eq!(diagnostics.source, "none");
        assert_eq!(
            diagnostics.chrome_binary.as_deref(),
            Some("/definitely/not/nvbrowser-chrome")
        );
        assert!(diagnostics
            .warning
            .as_deref()
            .unwrap_or("")
            .contains("Chrome binary is not executable"));
    }

    #[test]
    fn chromium_backend_diagnostics_rejects_non_executable_chrome_binary() {
        let chrome_path = std::env::temp_dir().join(format!(
            "nvbrowser-test-non-executable-chrome-{}",
            std::process::id()
        ));
        std::fs::write(&chrome_path, "").expect("chrome fixture should be written");
        #[cfg(unix)]
        {
            let mut permissions = std::fs::metadata(&chrome_path)
                .expect("chrome fixture metadata should exist")
                .permissions();
            permissions.set_mode(0o644);
            std::fs::set_permissions(&chrome_path, permissions)
                .expect("chrome fixture should be non-executable");
        }

        let diagnostics =
            ChromiumOptions::from_env_values(None, Some(chrome_path.clone()), None, None, None)
                .backend_diagnostics();

        assert_eq!(diagnostics.status, "missing");
        assert_eq!(diagnostics.source, "none");
        assert_eq!(
            diagnostics.chrome_binary.as_deref(),
            Some(chrome_path.to_string_lossy().as_ref())
        );
        assert!(diagnostics
            .warning
            .as_deref()
            .unwrap_or("")
            .contains("Chrome binary is not executable"));
        let _ = std::fs::remove_file(chrome_path);
    }

    #[test]
    fn chromium_backend_diagnostics_reports_missing_backend() {
        let diagnostics =
            ChromiumOptions::from_env_values(None, None, None, None, None).backend_diagnostics();

        assert_eq!(diagnostics.status, "missing");
        assert_eq!(diagnostics.source, "none");
        assert!(diagnostics.cdp_ws_url.is_none());
        assert!(diagnostics.chrome_binary.is_none());
        assert!(diagnostics
            .warning
            .as_deref()
            .unwrap_or("")
            .contains("NVBROWSER_CDP_WS_URL"));
    }

    #[test]
    fn launch_options_include_persistent_user_data_dir_when_launching() {
        let options = build_launch_options(
            Path::new("/custom/chrome"),
            Viewport::new(640, 480),
            Some(Path::new("/tmp/nvbrowser-profile")),
        )
        .expect("launch options should build");

        assert_eq!(
            options.user_data_dir,
            Some(PathBuf::from("/tmp/nvbrowser-profile"))
        );
        assert_eq!(options.path, Some(PathBuf::from("/custom/chrome")));
        assert_eq!(options.window_size, Some((640, 480)));
        assert_eq!(options.idle_browser_timeout, BROWSER_IDLE_TIMEOUT);
    }

    #[test]
    fn browser_source_prefers_cdp_ws_url_over_binary() {
        let options = ChromiumOptions {
            cdp_ws_url: Some("ws://127.0.0.1:9222/devtools/browser/test".to_string()),
            binary: Some(PathBuf::from("/custom/chrome")),
            user_data_dir: Some(PathBuf::from("/tmp/nvbrowser-profile")),
            download_dir: Some(PathBuf::from("/tmp/nvbrowser-downloads")),
            navigation_timeout_ms: DEFAULT_NAVIGATION_TIMEOUT_MS,
        };

        assert_eq!(
            options
                .browser_source()
                .expect("source should be available"),
            BrowserSource::Connect("ws://127.0.0.1:9222/devtools/browser/test".to_string())
        );
    }

    #[test]
    fn browser_source_uses_binary_when_cdp_ws_url_is_absent() {
        let options = ChromiumOptions {
            cdp_ws_url: None,
            binary: Some(PathBuf::from("/custom/chrome")),
            user_data_dir: Some(PathBuf::from("/tmp/nvbrowser-profile")),
            download_dir: Some(PathBuf::from("/tmp/nvbrowser-downloads")),
            navigation_timeout_ms: DEFAULT_NAVIGATION_TIMEOUT_MS,
        };

        assert_eq!(
            options
                .browser_source()
                .expect("source should be available"),
            BrowserSource::Launch(PathBuf::from("/custom/chrome"))
        );
    }

    #[test]
    fn browser_source_reports_missing_backend_when_no_connection_options_exist() {
        let options = ChromiumOptions {
            cdp_ws_url: None,
            binary: None,
            user_data_dir: Some(PathBuf::from("/tmp/nvbrowser-profile")),
            download_dir: Some(PathBuf::from("/tmp/nvbrowser-downloads")),
            navigation_timeout_ms: DEFAULT_NAVIGATION_TIMEOUT_MS,
        };

        let error = options
            .browser_source()
            .expect_err("source should require CDP URL or Chrome binary");

        assert_eq!(error.kind(), RendererErrorKind::BackendUnavailable);
        assert!(error
            .message()
            .contains("set NVBROWSER_CDP_WS_URL or NVBROWSER_CHROME"));
    }

    #[test]
    fn hint_scripts_use_opaque_registry_ids_instead_of_capture_local_indexes() {
        assert!(ELEMENT_HINTS_SCRIPT.contains("__nvbrowserHintRegistry"));
        assert!(
            ELEMENT_HINTS_SCRIPT.contains("registry.elements.set(id, { element, frameElements })")
        );
        assert!(ELEMENT_HINTS_SCRIPT.contains("id,"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("aria-labelledby"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("element.labels"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("closest('label')"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("type === 'file'"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("return 'file'"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("return 'checkbox'"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("return 'radio'"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("checked: checkedFor(element)"));
        assert!(FOCUS_HINT_SCRIPT.contains("__nvbrowserHintRegistry"));
        assert!(FOCUS_HINT_SCRIPT.contains("registry.elements.get(hintId)"));
        assert!(FOCUS_HINT_SCRIPT.contains("type === 'hidden'"));
        assert!(FOCUS_HINT_SCRIPT.contains("element.disabled"));
        assert!(FOCUS_HINT_SCRIPT.contains("aria-disabled"));
        assert!(FOCUS_HINT_SCRIPT.contains("element.focus({ preventScroll: true })"));
        assert!(!FOCUS_HINT_SCRIPT.contains("element.click()"));
        assert!(!FOCUS_HINT_SCRIPT.contains("[hintId - 1]"));
        assert!(CLICK_HINT_POINT_SCRIPT.contains("__nvbrowserHintRegistry"));
        assert!(CLICK_HINT_POINT_SCRIPT.contains("registry.elements.get(hintId)"));
        assert!(CLICK_HINT_POINT_SCRIPT.contains("getBoundingClientRect"));
        assert!(!CLICK_HINT_POINT_SCRIPT.contains("[hintId - 1]"));
        assert!(!CLICK_HINT_POINT_SCRIPT.contains("element.click()"));
        assert!(!CLICK_HINT_POINT_SCRIPT.contains("location.assign"));
        assert!(!CLICK_HINT_ACTION_SCRIPT.contains("location.assign"));
        assert!(!CLICK_HINT_ACTION_SCRIPT.contains("element.click()"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("optionsFor(element)"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("Array.from(element.options || [])"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("disabled: option.disabled === true"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("selected: option.selected === true"));
        assert!(SELECT_HINT_SCRIPT.contains("__nvbrowserHintRegistry"));
        assert!(SELECT_HINT_SCRIPT.contains("registry.elements.get(hintId)"));
        assert!(SELECT_HINT_SCRIPT.contains("tagName.toLowerCase() !== 'select'"));
        assert!(SELECT_HINT_SCRIPT.contains("Number.parseInt(normalizedChoice, 10) - 1"));
        assert!(SELECT_HINT_SCRIPT.contains("option.value === choice"));
        assert!(
            SELECT_HINT_SCRIPT.contains("normalize(option.textContent).toLowerCase() === wanted")
        );
        assert!(SELECT_HINT_SCRIPT.contains("new Event('input', { bubbles: true })"));
        assert!(SELECT_HINT_SCRIPT.contains("new Event('change', { bubbles: true })"));
        assert!(!SELECT_HINT_SCRIPT.contains("[hintId - 1]"));
        assert!(TOGGLE_HINT_SCRIPT.contains("__nvbrowserHintRegistry"));
        assert!(TOGGLE_HINT_SCRIPT.contains("registry.elements.get(hintId)"));
        assert!(TOGGLE_HINT_SCRIPT.contains("type !== 'checkbox'"));
        assert!(TOGGLE_HINT_SCRIPT.contains("type !== 'radio'"));
        assert!(TOGGLE_HINT_SCRIPT.contains("element.click()"));
        assert!(!TOGGLE_HINT_SCRIPT.contains("element.checked ="));
        assert!(!TOGGLE_HINT_SCRIPT.contains("new Event('input'"));
        assert!(!TOGGLE_HINT_SCRIPT.contains("new Event('change'"));
        assert!(!TOGGLE_HINT_SCRIPT.contains("[hintId - 1]"));
        assert!(CLICK_HINT_POINT_SCRIPT.contains("registry.elements.get(hintId)"));
        let upload_script =
            upload_hint_target_script(9, 2).expect("upload target script should build");
        assert!(upload_script.contains("__nvbrowserHintRegistry"));
        assert!(upload_script.contains("registry.elements.get(hintId)"));
        assert!(upload_script.contains("type !== 'file'"));
        assert!(upload_script.contains("!element.multiple"));
        assert!(upload_script.contains("data-nvbrowser-upload-token"));
        assert!(upload_script.contains("entry.uploadToken = token"));
        let object_script = upload_hint_object_script("nvbrowser-upload-token")
            .expect("upload object script should build");
        assert!(object_script.contains("__nvbrowserHintRegistry"));
        assert!(object_script.contains("entry.uploadToken"));
        assert!(object_script.contains("return element"));
        let change_script = upload_hint_change_script("nvbrowser-upload-token")
            .expect("upload change script should build");
        assert!(change_script.contains("entry.uploadToken"));
        assert!(change_script.contains("dispatchEvent(new Event('input'"));
        assert!(change_script.contains("dispatchEvent(new Event('change'"));
    }

    #[test]
    fn hint_extraction_walks_open_shadow_roots_and_same_origin_iframes() {
        assert!(ELEMENT_HINTS_SCRIPT.contains("shadowRoot"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("collectCandidates(element.shadowRoot"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("iframe"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("contentDocument"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("try {"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("frameElements"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("translateRectToViewport"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("clientLeft"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("labelScope.getElementById(id)"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("const targetFor = (element)"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("element.tagName.toLowerCase() !== 'a'"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("target: targetFor(element)"));
        assert!(
            ELEMENT_HINTS_SCRIPT.contains("registry.elements.set(id, { element, frameElements })")
        );
    }

    #[test]
    fn hint_action_points_translate_iframe_relative_elements_to_top_viewport() {
        assert!(CLICK_HINT_POINT_SCRIPT.contains("entry.element || entry"));
        assert!(CLICK_HINT_POINT_SCRIPT.contains("entry.frameElements || []"));
        assert!(CLICK_HINT_POINT_SCRIPT.contains("for (let index = frameElements.length - 1"));
        assert!(CLICK_HINT_POINT_SCRIPT.contains("frameRect.left"));
        assert!(CLICK_HINT_POINT_SCRIPT.contains("clientLeft"));
        assert!(FOCUS_HINT_SCRIPT.contains("entry.element || entry"));
        assert!(SELECT_HINT_SCRIPT.contains("entry.element || entry"));
        assert!(TOGGLE_HINT_SCRIPT.contains("entry.element || entry"));
    }

    #[test]
    fn select_hint_metadata_uses_existing_normalize_text_helper() {
        assert!(ELEMENT_HINTS_SCRIPT.contains("label: normalizeText("));
        assert!(!ELEMENT_HINTS_SCRIPT.contains("label: normalize("));
    }

    #[test]
    fn mouse_dispatch_options_preserve_right_button_press_and_release() {
        let moved = mouse_dispatch_options(
            &Input::DispatchMouseEventTypeOption::MouseMoved,
            MouseDispatchButton::Right,
        );
        let pressed = mouse_dispatch_options(
            &Input::DispatchMouseEventTypeOption::MousePressed,
            MouseDispatchButton::Right,
        );
        let released = mouse_dispatch_options(
            &Input::DispatchMouseEventTypeOption::MouseReleased,
            MouseDispatchButton::Right,
        );

        assert_eq!(moved.button, None);
        assert_eq!(moved.buttons, Some(0));
        assert_eq!(moved.click_count, None);
        assert_eq!(pressed.button, Some(Input::MouseButton::Right));
        assert_eq!(pressed.buttons, Some(2));
        assert_eq!(pressed.click_count, Some(1));
        assert_eq!(released.button, Some(Input::MouseButton::Right));
        assert_eq!(released.buttons, Some(2));
        assert_eq!(released.click_count, Some(1));
    }

    #[test]
    fn mouse_drag_move_options_hold_left_button_without_click_count() {
        let drag_move = mouse_drag_move_options(MouseDispatchButton::Left);

        assert_eq!(drag_move.button, Some(Input::MouseButton::Left));
        assert_eq!(drag_move.buttons, Some(1));
        assert_eq!(drag_move.click_count, None);
    }

    #[test]
    fn active_element_script_redacts_password_values() {
        assert!(ACTIVE_ELEMENT_SCRIPT.contains("const inputType ="));
        assert!(ACTIVE_ELEMENT_SCRIPT.contains("inputType === 'password'"));
        assert!(ACTIVE_ELEMENT_SCRIPT.contains("passwordLike ? null : element.value"));
        assert!(ACTIVE_ELEMENT_SCRIPT.contains("!passwordLike"));
    }

    #[test]
    fn select_hint_script_escapes_choice() {
        let script = select_hint_script(4, "Canada \"East\"").expect("select script should build");
        assert!(script.contains("const hintId = 4;"));
        assert!(script.contains(r#"const choice = "Canada \"East\"";"#));
    }

    #[test]
    fn toggle_hint_script_uses_requested_hint_id() {
        let script = toggle_hint_script(7).expect("toggle script should build");
        assert!(script.contains("const hintId = 7;"));
    }

    #[test]
    fn unix_time_ms_returns_nonzero_timestamp() {
        assert!(unix_time_ms() > 0);
    }

    #[test]
    fn viewport_clip_matches_requested_viewport() {
        let clip = viewport_clip(Viewport::new(640, 480));

        assert_eq!(clip.x, 0.0);
        assert_eq!(clip.y, 0.0);
        assert_eq!(clip.width, 640.0);
        assert_eq!(clip.height, 480.0);
        assert_eq!(clip.scale, 1.0);
    }

    #[test]
    fn zoom_device_metrics_override_shrinks_css_viewport_and_preserves_device_scale() {
        let mut viewport = Viewport::new(480, 320);
        viewport.device_scale_factor = 2.0;

        let metrics = ZoomDeviceMetricsOverride::from_viewport(viewport, 1.25)
            .expect("zoomed scale should produce device metrics override");

        assert_eq!(metrics.width, 384);
        assert_eq!(metrics.height, 256);
        assert_eq!(metrics.device_scale_factor, 2.0);
    }

    #[test]
    fn zoom_device_metrics_override_clears_near_default_scale() {
        assert_eq!(
            ZoomDeviceMetricsOverride::from_viewport(Viewport::new(480, 320), 1.0),
            None
        );
        assert_eq!(
            ZoomDeviceMetricsOverride::from_viewport(Viewport::new(480, 320), 1.004),
            None
        );
    }

    #[test]
    fn parses_page_metrics_json_from_chromium_script() {
        let metrics = parse_page_metrics_json(
            r#"{"scroll_x":0,"scroll_y":250,"viewport_width":800,"viewport_height":600,"document_width":800,"document_height":1600}"#,
        )
        .expect("page metrics should parse");

        assert_eq!(metrics.scroll_x, 0.0);
        assert_eq!(metrics.scroll_y, 250.0);
        assert_eq!(metrics.viewport_width, 800.0);
        assert_eq!(metrics.viewport_height, 600.0);
        assert_eq!(metrics.document_width, 800.0);
        assert_eq!(metrics.document_height, 1600.0);
    }

    #[test]
    fn parses_page_text_json_from_chromium_script() {
        let snapshot = parse_page_text_json(
            r##"{"url":"https://example.com","title":"Example","text":"# Example\n\nBody","truncated":false}"##,
        )
        .expect("page text should parse");

        assert_eq!(snapshot.url, "https://example.com");
        assert_eq!(snapshot.title.as_deref(), Some("Example"));
        assert_eq!(snapshot.text, "# Example\n\nBody");
        assert!(!snapshot.truncated);
    }

    #[test]
    fn page_text_script_uses_bounded_text_node_walker() {
        assert!(PAGE_TEXT_SCRIPT.contains("document.createTreeWalker"));
        assert!(PAGE_TEXT_SCRIPT.contains("NodeFilter.SHOW_TEXT"));
        assert!(PAGE_TEXT_SCRIPT.contains("closest('a[href]'"));
        assert!(PAGE_TEXT_SCRIPT.contains("markdownLink"));
        assert!(!PAGE_TEXT_SCRIPT.contains("innerText"));
        assert!(!PAGE_TEXT_SCRIPT.contains("+ '\\n\\n[truncated]'"));
    }

    #[test]
    fn selection_text_script_prefers_text_controls_and_falls_back_to_dom_selection() {
        assert!(SELECTION_TEXT_SCRIPT.contains("selectionStart"));
        assert!(SELECTION_TEXT_SCRIPT.contains("selectionEnd"));
        assert!(SELECTION_TEXT_SCRIPT.contains("window.getSelection"));
    }

    #[test]
    fn find_text_script_uses_requested_direction() {
        let forward = find_text_script("needle", false).expect("forward find script should build");
        assert!(forward.contains(r#"window.find(query, false, false, true, false, true, false)"#));
        assert!(forward.contains("document.body.innerText"));
        assert!(forward.contains("match_count"));

        let backward = find_text_script("needle", true).expect("backward find script should build");
        assert!(backward.contains(r#"window.find(query, false, true, true, false, true, false)"#));
    }

    #[test]
    fn find_text_script_escapes_query_as_json() {
        let script =
            find_text_script(r#"quote " and \ slash"#, false).expect("find script should build");

        assert!(script.contains(r#"const query = "quote \" and \\ slash";"#));
    }

    #[test]
    fn parse_find_text_json_preserves_match_count() {
        let parsed = parse_find_text_json(r#"{"found":true,"match_count":2}"#)
            .expect("find text result should parse");

        assert!(parsed.found);
        assert_eq!(parsed.match_count, 2);
    }

    #[test]
    fn chromium_key_with_modifiers_parses_multiple_modifiers() {
        let (key, modifiers) = chromium_key_with_modifiers("Ctrl+Shift+Tab");

        assert_eq!(key, "Tab");
        assert_eq!(format!("{modifiers:?}"), "[Ctrl, Shift]");
    }

    #[test]
    fn chromium_key_with_modifiers_ignores_unknown_prefixes() {
        let (key, modifiers) = chromium_key_with_modifiers("Hyper+Tab");

        assert_eq!(key, "Hyper+Tab");
        assert!(modifiers.is_empty());
    }

    #[test]
    fn interaction_settle_decision_waits_for_stable_complete_state() {
        let samples = vec![
            InteractionSettleSample::new("https://example.com", Some("Old"), Some("loading")),
            InteractionSettleSample::new(
                "https://example.com/app",
                Some("App"),
                Some("interactive"),
            ),
            InteractionSettleSample::new("https://example.com/app", Some("App"), Some("complete")),
            InteractionSettleSample::new("https://example.com/app", Some("App"), Some("complete")),
        ];

        let settled = choose_interaction_settle_sample(&samples, 2).expect("sample should settle");

        assert_eq!(settled.url, "https://example.com/app");
        assert_eq!(settled.title.as_deref(), Some("App"));
    }

    #[test]
    fn interaction_settle_decision_requires_three_stable_complete_samples() {
        assert_eq!(
            INTERACTION_SETTLE_STABLE_SAMPLES, 3,
            "runtime settle should require three stable complete samples before capture"
        );

        let two_samples = vec![
            InteractionSettleSample::new("https://example.com/app", Some("App"), Some("complete")),
            InteractionSettleSample::new("https://example.com/app", Some("App"), Some("complete")),
        ];
        assert!(
            choose_interaction_settle_sample(&two_samples, 3).is_none(),
            "two matching complete samples should not settle when three stable samples are required"
        );

        let three_samples = vec![
            InteractionSettleSample::new("https://example.com/app", Some("App"), Some("complete")),
            InteractionSettleSample::new("https://example.com/app", Some("App"), Some("complete")),
            InteractionSettleSample::new("https://example.com/app", Some("App"), Some("complete")),
        ];
        let settled = choose_interaction_settle_sample(&three_samples, 3)
            .expect("three matching complete samples should settle");

        assert_eq!(settled.url, "https://example.com/app");
        assert_eq!(settled.title.as_deref(), Some("App"));
    }

    #[test]
    fn interaction_settle_decision_does_not_finish_at_interactive_state() {
        let samples = vec![
            InteractionSettleSample::new(
                "https://example.com/app",
                Some("App"),
                Some("interactive"),
            ),
            InteractionSettleSample::new(
                "https://example.com/app",
                Some("App"),
                Some("interactive"),
            ),
        ];

        assert!(choose_interaction_settle_sample(&samples, 2).is_none());
    }

    #[test]
    fn interaction_settle_decision_times_out_to_latest_sample() {
        let samples = vec![
            InteractionSettleSample::new("https://example.com", Some("Old"), Some("loading")),
            InteractionSettleSample::new("https://example.com/app", Some("App"), Some("loading")),
        ];

        let settled =
            latest_interaction_settle_sample(&samples).expect("latest sample should be returned");

        assert_eq!(settled.url, "https://example.com/app");
        assert_eq!(settled.title.as_deref(), Some("App"));
    }

    #[test]
    fn interaction_settle_decision_treats_unknown_ready_state_as_unstable() {
        let samples = vec![
            InteractionSettleSample::new("https://example.com/app", Some("App"), None),
            InteractionSettleSample::new("https://example.com/app", Some("App"), None),
        ];

        assert!(choose_interaction_settle_sample(&samples, 2).is_none());
    }

    #[test]
    fn new_page_target_selection_prefers_new_navigated_pages() {
        let active_id = "active".to_string();
        let candidates = vec![
            TargetCandidate {
                id: "active".to_string(),
                url: "https://example.com/start".to_string(),
                previously_known: true,
            },
            TargetCandidate {
                id: "new-blank".to_string(),
                url: "about:blank".to_string(),
                previously_known: false,
            },
            TargetCandidate {
                id: "new-page".to_string(),
                url: "https://example.com/new".to_string(),
                previously_known: false,
            },
        ];

        assert_eq!(
            choose_new_page_target_id(&active_id, &candidates, &HashSet::new()).as_deref(),
            Some("new-page")
        );
    }

    #[test]
    fn new_page_target_selection_ignores_existing_and_internal_targets() {
        let active_id = "active".to_string();
        let candidates = vec![
            TargetCandidate {
                id: "old-page".to_string(),
                url: "https://example.com/old".to_string(),
                previously_known: true,
            },
            TargetCandidate {
                id: "devtools".to_string(),
                url: "devtools://devtools/bundled/inspector.html".to_string(),
                previously_known: false,
            },
            TargetCandidate {
                id: "blank".to_string(),
                url: "about:blank".to_string(),
                previously_known: false,
            },
        ];

        assert!(choose_new_page_target_id(&active_id, &candidates, &HashSet::new()).is_none());
    }

    #[test]
    fn observed_blank_targets_remain_adoptable_after_late_navigation() {
        let mut known_target_ids = HashSet::from(["active".to_string()]);
        let mut pending_page_target_ids = HashSet::new();
        let first_scan = vec![
            TargetCandidate {
                id: "active".to_string(),
                url: "https://example.com/current".to_string(),
                previously_known: true,
            },
            TargetCandidate {
                id: "late-popup".to_string(),
                url: "about:blank".to_string(),
                previously_known: false,
            },
        ];

        track_pending_page_targets(
            &mut known_target_ids,
            &mut pending_page_target_ids,
            &first_scan,
        );
        assert!(
            choose_new_page_target_id("active", &first_scan, &pending_page_target_ids).is_none()
        );
        assert!(
            known_target_ids.contains("late-popup"),
            "pending blank targets should be known so they do not keep settle loops waiting"
        );
        assert!(
            pending_page_target_ids.contains("late-popup"),
            "pending blank targets should remain adoptable after they navigate"
        );

        let second_scan = vec![
            TargetCandidate {
                id: "active".to_string(),
                url: "https://example.com/current".to_string(),
                previously_known: true,
            },
            TargetCandidate {
                id: "late-popup".to_string(),
                url: "https://example.com/late".to_string(),
                previously_known: known_target_ids.contains("late-popup"),
            },
        ];

        assert_eq!(
            choose_new_page_target_id("active", &second_scan, &pending_page_target_ids).as_deref(),
            Some("late-popup")
        );
    }

    #[test]
    fn pending_target_tracking_ignores_internal_and_cleans_closed_targets() {
        let mut known_target_ids = HashSet::from(["active".to_string()]);
        let mut pending_page_target_ids = HashSet::from(["closed-popup".to_string()]);
        let candidates = vec![
            TargetCandidate {
                id: "active".to_string(),
                url: "https://example.com/current".to_string(),
                previously_known: true,
            },
            TargetCandidate {
                id: "blank-popup".to_string(),
                url: "about:blank".to_string(),
                previously_known: false,
            },
            TargetCandidate {
                id: "devtools".to_string(),
                url: "devtools://devtools/bundled/inspector.html".to_string(),
                previously_known: false,
            },
        ];

        track_pending_page_targets(
            &mut known_target_ids,
            &mut pending_page_target_ids,
            &candidates,
        );

        assert!(!pending_page_target_ids.contains("closed-popup"));
        assert!(pending_page_target_ids.contains("blank-popup"));
        assert!(!pending_page_target_ids.contains("devtools"));
        assert!(known_target_ids.contains("devtools"));
        assert!(!has_unknown_targets(&candidates, &pending_page_target_ids));
    }

    #[test]
    fn default_dialog_policy_accepts_alert_and_dismisses_blocking_prompts() {
        assert_eq!(
            default_dialog_policy(&DialogType::Alert),
            DialogPolicy::Accept
        );
        assert_eq!(
            default_dialog_policy(&DialogType::Confirm),
            DialogPolicy::Dismiss
        );
        assert_eq!(
            default_dialog_policy(&DialogType::Prompt),
            DialogPolicy::Dismiss
        );
        assert_eq!(
            default_dialog_policy(&DialogType::Beforeunload),
            DialogPolicy::Dismiss
        );
    }

    #[test]
    fn dom_quiet_script_waits_for_mutation_quiet_window() {
        assert!(DOM_QUIET_SCRIPT.contains("new MutationObserver"));
        assert!(DOM_QUIET_SCRIPT.contains("quietMs = 120"));
        assert!(DOM_QUIET_SCRIPT.contains("maxMs = 650"));
        assert!(DOM_QUIET_SCRIPT.contains("observer.disconnect()"));
    }
}
