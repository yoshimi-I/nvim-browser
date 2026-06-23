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

local html_command = backend.command_for("nvbrowser", "open", "/tmp/site/index page.html", {
  graphics = "ansi",
})
assert(vim.deep_equal(html_command, {
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--url",
  vim.uri_from_fname("/tmp/site/index page.html"),
}), "HTML files should route through Chromium serve with file URLs")

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
})
assert(vim.deep_equal(image_command, {
  "nvbrowser",
  "show-image",
  "/tmp/image.png",
  "--output",
  "ansi",
  "--fit",
  "contain",
}), "raster images should keep direct image routing")

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
  "show-image",
  "/tmp/image.png",
  "--output",
  "ansi",
  "--fit",
  "contain",
}), "auto raster images under Zellij should use ANSI output")

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
  "show-image",
  "/tmp/image.png",
  "--output",
  "kitty",
  "--fit",
  "contain",
}), "explicit kitty-unicode raster images under Zellij should preserve the existing Kitty image fallback")

vim.env.ZELLIJ = original_zellij
vim.env.TMUX = original_tmux
vim.env.TERM = original_term
vim.env.TERM_PROGRAM = original_term_program
vim.env.GHOSTTY_RESOURCES_DIR = original_ghostty
