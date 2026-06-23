use std::{
    path::{Path, PathBuf},
    sync::Arc,
    thread,
    time::{Duration, SystemTime, UNIX_EPOCH},
};

use headless_chrome::{
    browser::tab::{point::Point, ModifierKey, Tab},
    protocol::cdp::types::Method,
    protocol::cdp::Page::{CaptureScreenshotFormatOption, Viewport as CdpViewport},
    types::Bounds,
    Browser, LaunchOptions,
};
use serde::{Deserialize, Serialize};

use crate::{
    renderer::{
        ClickHintRequest, ClickPointRequest, ElementHint, ElementHintsRequest, FindTextRequest,
        FindTextResult, FocusHintRequest, FocusSelectorRequest, FrameArtifact,
        HistoryNavigationRequest, HistoryNavigationResult, HoverHintRequest, HoverPointRequest,
        InputResult, InteractionSettleResult, KeyPressRequest, NavigateRequest, NavigationResult,
        PageMetrics, PageMetricsRequest, PageTextRequest, PageTextSnapshot, ReloadRequest,
        ReloadResult, RenderFrameRequest, RenderedFrame, Renderer, RendererError,
        RendererErrorKind, ScrollRequest, ScrollResult, ShutdownResult, TextInputRequest,
    },
    session::{FrameId, FrameMetadata, PageId, SessionId, Viewport},
};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ChromiumOptions {
    pub cdp_ws_url: Option<String>,
    pub binary: Option<PathBuf>,
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
        )
    }

    fn from_env_values(cdp_ws_url: Option<String>, binary: Option<PathBuf>) -> Self {
        Self { cdp_ws_url, binary }
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
    resize_tab(&tab, viewport)?;
    let png = tab
        .navigate_to(url)
        .and_then(|tab| tab.wait_until_navigated())
        .and_then(|tab| {
            tab.capture_screenshot(
                CaptureScreenshotFormatOption::Png,
                None,
                Some(viewport_clip(viewport)),
                true,
            )
        })
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
    _browser: Browser,
    tab: Arc<Tab>,
    current_url: Option<String>,
    current_title: Option<String>,
    next_frame_id: u64,
}

impl ChromiumRenderer {
    pub fn launch(viewport: Viewport, options: ChromiumOptions) -> Result<Self, RendererError> {
        let browser = open_browser(&options, viewport)?;
        let tab = browser.new_tab().map_err(render_error)?;
        resize_tab(&tab, viewport)?;

        Ok(Self {
            _browser: browser,
            tab,
            current_url: None,
            current_title: None,
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
            .and_then(|tab| tab.wait_until_navigated())
            .map_err(render_error)?;
        let url = self.tab.get_url();
        let title = self.read_current_title().unwrap_or(None);
        self.current_url = Some(url.clone());
        self.current_title = title.clone();
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
        resize_tab(&self.tab, request.viewport)?;
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
        self.tab.type_str(&request.text).map_err(render_error)?;
        Ok(InputResult {
            session_id: request.session_id,
            page_id: request.page_id,
        })
    }

    fn press_key(&mut self, request: KeyPressRequest) -> Result<InputResult, RendererError> {
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
            .click_point(Point {
                x: point.x,
                y: point.y,
            })
            .map_err(render_error)?;
        Ok(InputResult {
            session_id: request.session_id,
            page_id: request.page_id,
        })
    }

    fn hover_hint(&mut self, request: HoverHintRequest) -> Result<InputResult, RendererError> {
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

    fn hover_point(&mut self, request: HoverPointRequest) -> Result<InputResult, RendererError> {
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

    fn find_text(&mut self, request: FindTextRequest) -> Result<FindTextResult, RendererError> {
        let query = serde_json::to_string(&request.query).map_err(render_error)?;
        let script = format!("window.find({query}, false, false, true, false, true, false)");
        let found = self
            .tab
            .evaluate(&script, false)
            .map_err(render_error)?
            .value
            .and_then(|value| value.as_bool())
            .unwrap_or(false);
        Ok(FindTextResult {
            session_id: request.session_id,
            page_id: request.page_id,
            query: request.query,
            found,
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

    fn settle_after_interaction(&mut self) -> Result<InteractionSettleResult, RendererError> {
        let settled = self.wait_for_interaction_settle()?;
        let url = settled.url;
        let title = settled.title;
        self.current_url = Some(url.clone());
        self.current_title = title.clone();
        Ok(InteractionSettleResult::new(url, title))
    }

    fn shutdown(&mut self) -> Result<ShutdownResult, RendererError> {
        let _ = self.tab.close(false);
        Ok(ShutdownResult {})
    }
}

impl ChromiumRenderer {
    fn wait_for_interaction_settle(&self) -> Result<InteractionSettleSample, RendererError> {
        let deadline = std::time::Instant::now() + Duration::from_millis(750);
        let mut samples = Vec::new();
        let _ = self.wait_for_dom_quiet();

        loop {
            samples.push(self.read_interaction_settle_sample()?);
            if let Some(sample) = choose_interaction_settle_sample(&samples, 2) {
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
        self.tab.wait_until_navigated().map_err(render_error)?;
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

    fn wait_for_current_url(&self, target_url: &str) -> Result<String, RendererError> {
        for _ in 0..20 {
            let url = self.tab.get_url();
            if url == target_url {
                return Ok(url);
            }
            thread::sleep(Duration::from_millis(50));
        }
        let current_url = self.tab.get_url();
        Err(RendererError::new(
            RendererErrorKind::NavigationFailed,
            format!("history navigation did not reach {target_url}; current URL is {current_url}"),
        ))
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
  const labelFor = (element) => {
    const candidates = [
      element.getAttribute('aria-label'),
      element.getAttribute('title'),
      element.getAttribute('placeholder'),
      element.value,
      element.innerText,
      element.textContent,
      element.getAttribute('href')
    ];
    for (const candidate of candidates) {
      if (typeof candidate !== 'string') continue;
      const label = candidate.replace(/\s+/g, ' ').trim();
      if (label.length > 0) return label.slice(0, 80);
    }
    return element.tagName.toLowerCase();
  };
  const kindFor = (element) => {
    const tag = element.tagName.toLowerCase();
    const role = (element.getAttribute('role') || '').toLowerCase();
    if (tag === 'a' || role === 'link') return 'link';
    if (tag === 'button' || role === 'button') return 'button';
    if (tag === 'input') return 'input';
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
      return new URL(raw, document.baseURI).href;
    } catch (_) {
      return raw.trim();
    }
  };
  const isFocusable = (element) => {
    const tag = element.tagName.toLowerCase();
    return ['input', 'textarea', 'select', 'button', 'a'].includes(tag)
      || element.isContentEditable
      || element.tabIndex >= 0;
  };
  const isDisabled = (element) => element.disabled || element.getAttribute('aria-disabled') === 'true';
  const isVisible = (element) => {
    const style = window.getComputedStyle(element);
    return style.display !== 'none'
      && style.visibility !== 'hidden'
      && style.visibility !== 'collapse'
      && Number(style.opacity || '1') > 0.05
      && style.pointerEvents !== 'none';
  };
  const isTopmostAt = (element, x, y) => {
    const top = document.elementFromPoint(x, y);
    return top === element || (top !== null && element.contains(top));
  };
  const candidates = Array.from(document.querySelectorAll(selectors))
    .filter((element) => !isDisabled(element))
    .filter(isVisible)
    .map((element) => ({ element, rect: element.getBoundingClientRect() }))
    .filter(({ rect }) => rect.width > 0 && rect.height > 0)
    .filter(({ rect }) => rect.right >= 0 && rect.bottom >= 0 && rect.left <= viewportWidth && rect.top <= viewportHeight)
    .map(({ element, rect }) => {
      const left = Math.max(0, rect.left);
      const top = Math.max(0, rect.top);
      const right = Math.min(viewportWidth, rect.right);
      const bottom = Math.min(viewportHeight, rect.bottom);
      return { element, rect, left, top, right, bottom, x: (left + right) / 2, y: (top + bottom) / 2 };
    })
    .filter(({ element, x, y }) => isTopmostAt(element, x, y))
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
    if (!element || !element.isConnected) {
      registry.elements.delete(id);
    }
  }
  const idFor = (element) => {
    for (const [id, existing] of registry.elements) {
      if (existing === element) return id;
    }
    const id = registry.nextId++;
    registry.elements.set(id, element);
    return id;
  };
  const hints = candidates.map(({ element, left, top, right, bottom, x, y }) => {
      const id = idFor(element);
      return {
        id,
        kind: kindFor(element),
        label: labelFor(element),
        href: hrefFor(element),
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
  const element = registry && registry.elements instanceof Map ? registry.elements.get(hintId) : null;
  if (!element || !element.isConnected) return false;
  if (typeof element.scrollIntoView === 'function') {
    element.scrollIntoView({ block: 'center', inline: 'center' });
  }
  if (typeof element.focus === 'function') {
    element.focus();
  }
  if (document.activeElement !== element && typeof element.click === 'function') {
    element.click();
  }
  return document.activeElement === element || element.contains(document.activeElement);
})()
"#;

const CLICK_HINT_POINT_SCRIPT: &str = r#"
(() => {
  const hintId = __HINT_ID__;
  const registry = window.__nvbrowserHintRegistry;
  const element = registry && registry.elements instanceof Map ? registry.elements.get(hintId) : null;
  if (!element || !element.isConnected) return null;
  if (typeof element.scrollIntoView === 'function') {
    element.scrollIntoView({ block: 'center', inline: 'center' });
  }
  const rect = element.getBoundingClientRect();
  if (rect.width <= 0 || rect.height <= 0) return null;
  return JSON.stringify({
    x: Math.max(0, Math.min(window.innerWidth || rect.right, rect.left + rect.width / 2)),
    y: Math.max(0, Math.min(window.innerHeight || rect.bottom, rect.top + rect.height / 2))
  });
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

fn open_browser(options: &ChromiumOptions, viewport: Viewport) -> Result<Browser, RendererError> {
    match options.browser_source()? {
        BrowserSource::Connect(cdp_ws_url) => connect_browser(&cdp_ws_url),
        BrowserSource::Launch(binary) => launch_browser(&binary, viewport),
    }
}

fn connect_browser(cdp_ws_url: &str) -> Result<Browser, RendererError> {
    Browser::connect_with_timeout(cdp_ws_url.to_string(), Duration::from_secs(300)).map_err(
        |error| {
            RendererError::new(
                RendererErrorKind::BackendUnavailable,
                format!("failed to connect to Chrome CDP websocket: {error}"),
            )
        },
    )
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

fn parse_element_hints_json(text: &str) -> Result<Vec<ElementHint>, RendererError> {
    serde_json::from_str(text).map_err(render_error)
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

fn non_empty_string(value: String) -> Option<String> {
    let value = value.trim().to_string();
    if value.is_empty() {
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
        );

        assert_eq!(
            options.cdp_ws_url.as_deref(),
            Some("ws://127.0.0.1:9222/devtools/browser/test")
        );
        assert_eq!(options.binary, None);
    }

    #[test]
    fn browser_source_prefers_cdp_ws_url_over_binary() {
        let options = ChromiumOptions {
            cdp_ws_url: Some("ws://127.0.0.1:9222/devtools/browser/test".to_string()),
            binary: Some(PathBuf::from("/custom/chrome")),
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
        assert!(ELEMENT_HINTS_SCRIPT.contains("registry.elements.set(id, element)"));
        assert!(ELEMENT_HINTS_SCRIPT.contains("id,"));
        assert!(FOCUS_HINT_SCRIPT.contains("__nvbrowserHintRegistry"));
        assert!(FOCUS_HINT_SCRIPT.contains("registry.elements.get(hintId)"));
        assert!(!FOCUS_HINT_SCRIPT.contains("[hintId - 1]"));
        assert!(CLICK_HINT_POINT_SCRIPT.contains("__nvbrowserHintRegistry"));
        assert!(CLICK_HINT_POINT_SCRIPT.contains("registry.elements.get(hintId)"));
        assert!(CLICK_HINT_POINT_SCRIPT.contains("getBoundingClientRect"));
        assert!(!CLICK_HINT_POINT_SCRIPT.contains("[hintId - 1]"));
        assert!(!CLICK_HINT_POINT_SCRIPT.contains("element.click()"));
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
    fn dom_quiet_script_waits_for_mutation_quiet_window() {
        assert!(DOM_QUIET_SCRIPT.contains("new MutationObserver"));
        assert!(DOM_QUIET_SCRIPT.contains("quietMs = 120"));
        assert!(DOM_QUIET_SCRIPT.contains("maxMs = 650"));
        assert!(DOM_QUIET_SCRIPT.contains("observer.disconnect()"));
    }
}
