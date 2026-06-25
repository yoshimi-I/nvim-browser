local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local backend = require("nvim-browser.backend")

local zellij_resolution = backend.resolve_graphics({ graphics = "auto" }, { ZELLIJ = "1", TERM = "xterm-256color" })
assert(zellij_resolution.browser_output == "ansi", "auto browser output should fall back to ANSI under Zellij")
assert(zellij_resolution.image_output == "ansi", "auto image output should fall back to ANSI under Zellij")
assert(zellij_resolution.multiplexer == "zellij", "graphics resolver should detect Zellij")
assert(zellij_resolution.reason:find("Zellij", 1, true), "Zellij resolver reason should explain the fallback")

local ghostty_resolution = backend.resolve_graphics({
  graphics = "auto",
}, {
  TERM_PROGRAM = "ghostty",
  TERM = "xterm-ghostty",
})
assert(ghostty_resolution.browser_output == "kitty-unicode", "Ghostty auto browser output should use Kitty Unicode")
assert(ghostty_resolution.image_output == "kitty", "Ghostty auto image output should use Kitty")
assert(ghostty_resolution.terminal == "ghostty", "graphics resolver should detect Ghostty")
assert(ghostty_resolution.reason:find("Ghostty", 1, true), "Ghostty resolver reason should explain Kitty support")

local tmux_resolution = backend.resolve_graphics({
  graphics = "auto",
}, {
  TMUX = "/tmp/tmux-501/default,123,0",
  TERM = "tmux-256color",
  TERM_PROGRAM = "ghostty",
})
assert(tmux_resolution.browser_output == "kitty-unicode", "tmux auto browser output should preserve Kitty Unicode passthrough")
assert(tmux_resolution.image_output == "kitty", "tmux auto image output should preserve Kitty passthrough")
assert(tmux_resolution.multiplexer == "tmux", "graphics resolver should detect tmux")
assert(tmux_resolution.reason:find("tmux", 1, true), "tmux resolver reason should explain passthrough")

local unknown_resolution = backend.resolve_graphics({ graphics = "auto" }, { TERM = "xterm-256color" })
assert(unknown_resolution.browser_output == "ansi", "unknown auto browser output should use safe ANSI fallback")
assert(unknown_resolution.image_output == "ansi", "unknown auto image output should use safe ANSI fallback")
assert(unknown_resolution.terminal == "unknown", "graphics resolver should label unknown terminals")

local explicit_unicode_resolution = backend.resolve_graphics({ graphics = "kitty-unicode" }, { ZELLIJ = "1" })
assert(explicit_unicode_resolution.browser_output == "kitty-unicode", "explicit kitty-unicode should preserve browser output")
assert(explicit_unicode_resolution.image_output == "kitty", "explicit kitty-unicode should map raster images to Kitty")
assert(#explicit_unicode_resolution.warnings > 0, "explicit Kitty graphics under a risky multiplexer should warn")

local explicit_ansi_resolution = backend.resolve_graphics({ graphics = "ansi" }, { TERM_PROGRAM = "ghostty" })
assert(explicit_ansi_resolution.browser_output == "ansi", "explicit ansi should preserve browser output")
assert(explicit_ansi_resolution.image_output == "ansi", "explicit ansi should preserve image output")
assert(#explicit_ansi_resolution.warnings == 0, "explicit ansi should not warn in Kitty-capable terminals")

local explicit_kitty_resolution = backend.resolve_graphics({ graphics = "kitty" }, { TERM_PROGRAM = "ghostty" })
assert(explicit_kitty_resolution.browser_output == "kitty", "explicit kitty should preserve browser output")
assert(explicit_kitty_resolution.image_output == "kitty", "explicit kitty should preserve image output")
assert(#explicit_kitty_resolution.warnings == 0, "explicit kitty should not warn outside risky multiplexers")

local markdown_command = backend.command_for("nvbrowser", "open", "/tmp/docs/README.md", {
  graphics = "ansi",
})
assert(vim.deep_equal(markdown_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--markdown",
  "/tmp/docs/README.md",
}), "markdown files should route through the browser serve pipeline")

local markdown_profile_command = backend.command_for("nvbrowser", "open", "/tmp/docs/README.md", {
  graphics = "ansi",
  user_data_dir = "/tmp/nvbrowser-profile",
})
assert(vim.deep_equal(markdown_profile_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--user-data-dir",
  "/tmp/nvbrowser-profile",
  "--markdown",
  "/tmp/docs/README.md",
}), "markdown commands should pass configured persistent profile directories")

local relative_markdown_command = backend.command_for("nvbrowser", "open", "docs/README.md", {
  graphics = "ansi",
})
assert(vim.deep_equal(relative_markdown_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--markdown",
  vim.fn.fnamemodify("docs/README.md", ":p"),
}), "relative markdown paths should be converted to absolute markdown paths")

local url_command = backend.command_for("nvbrowser", "open", "https://example.com", {
  graphics = "ansi",
})
assert(vim.deep_equal(url_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--url",
  "https://example.com",
}), "web URLs should keep routing through serve --url")

local default_timeout_url_command = backend.command_for("nvbrowser", "open", "https://example.com", {
  graphics = "ansi",
  navigation_timeout_ms = 20000,
})
assert(vim.deep_equal(default_timeout_url_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--url",
  "https://example.com",
}), "default navigation timeout should be omitted so CLI env fallback can still apply")

local timeout_url_command = backend.command_for("nvbrowser", "open", "https://example.com", {
  graphics = "ansi",
  navigation_timeout_ms = 1234,
})
assert(vim.deep_equal(timeout_url_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--navigation-timeout-ms",
  "1234",
  "--url",
  "https://example.com",
}), "web URL commands should pass configured navigation timeouts")

local cdp_url_command = backend.command_for("nvbrowser", "open", "https://example.com", {
  graphics = "ansi",
  cdp_ws_url = "ws://127.0.0.1:9222/devtools/browser/test",
})
assert(vim.deep_equal(cdp_url_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--cdp-ws-url",
  "ws://127.0.0.1:9222/devtools/browser/test",
  "--url",
  "https://example.com",
}), "web URL commands should pass configured CDP websocket endpoints")

local profile_url_command = backend.command_for("nvbrowser", "open", "https://example.com", {
  graphics = "ansi",
  user_data_dir = "/tmp/nvbrowser-profile",
})
assert(vim.deep_equal(profile_url_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--user-data-dir",
  "/tmp/nvbrowser-profile",
  "--url",
  "https://example.com",
}), "web URL commands should pass configured persistent profile directories")

local download_url_command = backend.command_for("nvbrowser", "open", "https://example.com", {
  graphics = "ansi",
  download_dir = "/tmp/nvbrowser-downloads",
})
assert(vim.deep_equal(download_url_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--download-dir",
  "/tmp/nvbrowser-downloads",
  "--url",
  "https://example.com",
}), "web URL commands should pass configured download directories")

local empty_download_url_command = backend.command_for("nvbrowser", "open", "https://example.com", {
  graphics = "ansi",
  download_dir = "",
})
assert(vim.deep_equal(empty_download_url_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--url",
  "https://example.com",
}), "empty download directories should not be passed to web URL commands")

local empty_profile_url_command = backend.command_for("nvbrowser", "open", "https://example.com", {
  graphics = "ansi",
  user_data_dir = "",
})
assert(vim.deep_equal(empty_profile_url_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--url",
  "https://example.com",
}), "empty persistent profile directories should not be passed to web URL commands")

local html_command = backend.command_for("nvbrowser", "open", "/tmp/site/index page.html", {
  graphics = "ansi",
  navigation_timeout_ms = 2345,
})
assert(vim.deep_equal(html_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--navigation-timeout-ms",
  "2345",
  "--url",
  vim.uri_from_fname("/tmp/site/index page.html"),
}), "HTML files should route through Chromium serve with file URLs and configured navigation timeouts")

local htm_cdp_command = backend.command_for("nvbrowser", "open", "/tmp/site/index.htm", {
  graphics = "ansi",
  cdp_ws_url = "ws://127.0.0.1:9222/devtools/browser/test",
})
assert(vim.deep_equal(htm_cdp_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--cdp-ws-url",
  "ws://127.0.0.1:9222/devtools/browser/test",
  "--url",
  vim.uri_from_fname("/tmp/site/index.htm"),
}), "HTML file commands should pass configured CDP websocket endpoints")

local html_profile_command = backend.command_for("nvbrowser", "open", "/tmp/site/index.html", {
  graphics = "ansi",
  user_data_dir = "/tmp/nvbrowser-profile",
})
assert(vim.deep_equal(html_profile_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--user-data-dir",
  "/tmp/nvbrowser-profile",
  "--url",
  vim.uri_from_fname("/tmp/site/index.html"),
}), "HTML file commands should pass configured persistent profile directories")

local html_download_command = backend.command_for("nvbrowser", "open", "/tmp/site/index.html", {
  graphics = "ansi",
  download_dir = "/tmp/nvbrowser-downloads",
})
assert(vim.deep_equal(html_download_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--download-dir",
  "/tmp/nvbrowser-downloads",
  "--url",
  vim.uri_from_fname("/tmp/site/index.html"),
}), "HTML file commands should pass configured download directories")

local relative_html_command = backend.command_for("nvbrowser", "open", "site/index.html", {
  graphics = "ansi",
})
assert(vim.deep_equal(relative_html_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--url",
  vim.uri_from_fname(vim.fn.fnamemodify("site/index.html", ":p")),
}), "relative HTML paths should be converted to absolute file URLs")

local home_html_command = backend.command_for("nvbrowser", "open", "~/site/index.html", {
  graphics = "ansi",
})
assert(vim.deep_equal(home_html_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--url",
  vim.uri_from_fname(vim.fn.fnamemodify("~/site/index.html", ":p")),
}), "home-relative HTML paths should be expanded before file URL conversion")

local pdf_command = backend.command_for("nvbrowser", "open", "/tmp/docs/manual.pdf", {
  graphics = "ansi",
})
assert(vim.deep_equal(pdf_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--url",
  vim.uri_from_fname("/tmp/docs/manual.pdf"),
}), "PDF files should route through Chromium serve with file URLs")

local pdf_cdp_profile_command = backend.command_for("nvbrowser", "open", "/tmp/docs/manual.PDF", {
  graphics = "ansi",
  cdp_ws_url = "ws://127.0.0.1:9222/devtools/browser/test",
  user_data_dir = "/tmp/nvbrowser-profile",
})
assert(vim.deep_equal(pdf_cdp_profile_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--cdp-ws-url",
  "ws://127.0.0.1:9222/devtools/browser/test",
  "--user-data-dir",
  "/tmp/nvbrowser-profile",
  "--url",
  vim.uri_from_fname("/tmp/docs/manual.PDF"),
}), "PDF file commands should pass CDP websocket endpoints and profile directories")

local relative_pdf_command = backend.command_for("nvbrowser", "open", "docs/manual.pdf", {
  graphics = "ansi",
})
assert(vim.deep_equal(relative_pdf_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--url",
  vim.uri_from_fname(vim.fn.fnamemodify("docs/manual.pdf", ":p")),
}), "relative PDF paths should be converted to absolute file URLs")

local home_pdf_command = backend.command_for("nvbrowser", "open", "~/docs/manual.pdf", {
  graphics = "ansi",
})
assert(vim.deep_equal(home_pdf_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--url",
  vim.uri_from_fname(vim.fn.fnamemodify("~/docs/manual.pdf", ":p")),
}), "home-relative PDF paths should be expanded before file URL conversion")

local file_url_html_command = backend.command_for("nvbrowser", "open", "file:///tmp/site/index.html", {
  graphics = "ansi",
})
assert(vim.deep_equal(file_url_html_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--url",
  "file:///tmp/site/index.html",
}), "existing file URL HTML targets should be preserved")

local svg_command = backend.command_for("nvbrowser", "open", "/tmp/site/icon.svg", {
  graphics = "ansi",
})
assert(vim.deep_equal(svg_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--url",
  vim.uri_from_fname("/tmp/site/icon.svg"),
}), "SVG files should route through Chromium serve with file URLs")

local svg_cdp_command = backend.command_for("nvbrowser", "open", "/tmp/site/icon.svg", {
  graphics = "ansi",
  cdp_ws_url = "ws://127.0.0.1:9222/devtools/browser/test",
})
assert(vim.deep_equal(svg_cdp_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--cdp-ws-url",
  "ws://127.0.0.1:9222/devtools/browser/test",
  "--url",
  vim.uri_from_fname("/tmp/site/icon.svg"),
}), "SVG file commands should pass configured CDP websocket endpoints")

local relative_svg_command = backend.command_for("nvbrowser", "open", "site/icon.svg", {
  graphics = "ansi",
})
assert(vim.deep_equal(relative_svg_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--url",
  vim.uri_from_fname(vim.fn.fnamemodify("site/icon.svg", ":p")),
}), "relative SVG paths should be converted to absolute file URLs")

local image_command = backend.command_for("nvbrowser", "open", "/tmp/image.png", {
  graphics = "ansi",
  image_fit = "contain",
  user_data_dir = "/tmp/nvbrowser-profile",
})
assert(vim.deep_equal(image_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--user-data-dir",
  "/tmp/nvbrowser-profile",
  "--image-fit",
  "contain",
  "--image",
  "/tmp/image.png",
}), "raster images should route through Chromium serve with image fit wrappers")

local image_cdp_command = backend.command_for("nvbrowser", "open", "/tmp/image.webp", {
  graphics = "ansi",
  cdp_ws_url = "ws://127.0.0.1:9222/devtools/browser/test",
})
assert(vim.deep_equal(image_cdp_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--cdp-ws-url",
  "ws://127.0.0.1:9222/devtools/browser/test",
  "--image-fit",
  "original",
  "--image",
  "/tmp/image.webp",
}), "raster image commands should pass configured CDP websocket endpoints")

local relative_image_command = backend.command_for("nvbrowser", "open", "assets/image.JPG", {
  graphics = "ansi",
})
assert(vim.deep_equal(relative_image_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--image-fit",
  "original",
  "--image",
  vim.fn.fnamemodify("assets/image.JPG", ":p"),
}), "relative raster image paths should be converted to absolute image paths")

local original_zellij = vim.env.ZELLIJ
local original_tmux = vim.env.TMUX
local original_term = vim.env.TERM
local original_term_program = vim.env.TERM_PROGRAM
local original_ghostty = vim.env.GHOSTTY_RESOURCES_DIR
vim.env.ZELLIJ = "1"
vim.env.TMUX = nil
vim.env.TERM = "xterm-256color"
vim.env.TERM_PROGRAM = nil
vim.env.GHOSTTY_RESOURCES_DIR = nil
local zellij_auto_image_command = backend.command_for("nvbrowser", "open", "/tmp/image.png", {
  graphics = "auto",
  image_fit = "contain",
})
assert(vim.deep_equal(zellij_auto_image_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--image-fit",
  "contain",
  "--image",
  "/tmp/image.png",
}), "auto raster image browser previews under Zellij should use ANSI output")

local zellij_auto_url_command = backend.command_for("nvbrowser", "open", "https://example.com", {
  graphics = "auto",
})
assert(vim.deep_equal(zellij_auto_url_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--url",
  "https://example.com",
}), "auto web URLs under Zellij should use ANSI browser output")

vim.env.ZELLIJ = nil
vim.env.TERM_PROGRAM = "ghostty"
vim.env.TERM = "xterm-ghostty"
local ghostty_auto_url_command = backend.command_for("nvbrowser", "open", "https://example.com", {
  graphics = "auto",
})
assert(vim.deep_equal(ghostty_auto_url_command, {
  "nvbrowser",
  "serve",
  "--output",
  "kitty-unicode",
  "--url",
  "https://example.com",
}), "auto web URLs under Ghostty should use Kitty Unicode browser output")

vim.env.TMUX = "/tmp/tmux-501/default,123,0"
local tmux_auto_url_command = backend.command_for("nvbrowser", "open", "https://example.com", {
  graphics = "auto",
})
assert(vim.deep_equal(tmux_auto_url_command, {
  "nvbrowser",
  "serve",
  "--output",
  "kitty-unicode",
  "--url",
  "https://example.com",
}), "auto web URLs under tmux should preserve Kitty Unicode passthrough output")
vim.env.TMUX = nil
vim.env.TERM_PROGRAM = nil
vim.env.TERM = "xterm-256color"
local unknown_auto_url_command = backend.command_for("nvbrowser", "open", "https://example.com", {
  graphics = "auto",
})
assert(vim.deep_equal(unknown_auto_url_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--url",
  "https://example.com",
}), "auto web URLs in unknown terminals should use ANSI fallback")

vim.env.ZELLIJ = "1"
local zellij_explicit_kitty_unicode_image_command = backend.command_for("nvbrowser", "open", "/tmp/image.png", {
  graphics = "kitty-unicode",
  image_fit = "contain",
})
vim.env.ZELLIJ = original_zellij
assert(vim.deep_equal(zellij_explicit_kitty_unicode_image_command, {
  "nvbrowser",
  "serve",
  "--output",
  "kitty-unicode",
  "--image-fit",
  "contain",
  "--image",
  "/tmp/image.png",
}), "explicit kitty-unicode raster image browser previews under Zellij should preserve browser output")

vim.env.ZELLIJ = original_zellij
vim.env.TMUX = original_tmux
vim.env.TERM = original_term
vim.env.TERM_PROGRAM = original_term_program
vim.env.GHOSTTY_RESOURCES_DIR = original_ghostty
