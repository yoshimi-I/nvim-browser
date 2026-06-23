local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local backend = require("nvim-browser.backend")

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
vim.env.ZELLIJ = "1"
local zellij_auto_image_command = backend.command_for("nvbrowser", "open", "/tmp/image.png", {
  graphics = "auto",
  image_fit = "contain",
})
vim.env.ZELLIJ = original_zellij
assert(vim.deep_equal(zellij_auto_image_command, {
  "nvbrowser",
  "show-image",
  "/tmp/image.png",
  "--output",
  "ansi",
  "--fit",
  "contain",
}), "auto raster images under Zellij should use ANSI output")

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
