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

local image_command = backend.command_for("nvbrowser", "open", "/tmp/image.png", {
  graphics = "ansi",
})
assert(vim.deep_equal(image_command, {
  "nvbrowser",
  "show-image",
  "/tmp/image.png",
  "--output",
  "ansi",
}), "raster images should keep direct image routing")
