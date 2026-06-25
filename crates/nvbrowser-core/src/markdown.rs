use comrak::{markdown_to_html, Options};

pub fn render_markdown_document(markdown: &str) -> String {
    render_markdown_document_with_base_url(markdown, None)
}

pub fn render_markdown_document_with_base_url(markdown: &str, base_href: Option<&str>) -> String {
    let raw_body = markdown_to_html(markdown, &Options::default());
    let (body, has_mermaid) = promote_mermaid_code_blocks(&raw_body);
    let has_math = contains_markdown_math(markdown);
    let base = base_href
        .filter(|href| !href.is_empty())
        .map(|href| format!(r#"<base href="{href}">"#))
        .unwrap_or_default();
    let mermaid_assets = if has_mermaid { mermaid_assets() } else { "" };
    let katex_assets = if has_math { katex_assets() } else { "" };
    let mut html_attrs = String::new();
    if has_mermaid {
        html_attrs.push_str(r#" data-nvbrowser-mermaid="pending""#);
    }
    if has_math {
        html_attrs.push_str(r#" data-nvbrowser-katex="pending""#);
    }
    format!(
        r#"<!doctype html>
<html{html_attrs}>
<head>
<meta charset="utf-8">
{base}
<style>
:root {{
  color-scheme: light dark;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  line-height: 1.6;
}}
body {{
  box-sizing: border-box;
  max-width: 880px;
  margin: 0 auto;
  padding: 32px;
}}
img {{
  max-width: 100%;
  height: auto;
}}
pre {{
  overflow-x: auto;
  padding: 16px;
  border-radius: 6px;
}}
code {{
  font-family: "SFMono-Regular", Consolas, monospace;
}}
.mermaid {{
  text-align: center;
  background: transparent;
}}
</style>
{mermaid_assets}
{katex_assets}
</head>
<body>
{body}</body>
</html>
"#
    )
}

fn promote_mermaid_code_blocks(html: &str) -> (String, bool) {
    let mut output = String::with_capacity(html.len());
    let mut remaining = html;
    let mut promoted = false;
    let open = r#"<pre><code class="language-mermaid">"#;
    let close = "</code></pre>";

    while let Some(start) = remaining.find(open) {
        output.push_str(&remaining[..start]);
        let code_start = start + open.len();
        let after_open = &remaining[code_start..];
        let Some(end) = after_open.find(close) else {
            output.push_str(&remaining[start..]);
            return (output, promoted);
        };
        output.push_str(r#"<pre class="mermaid">"#);
        output.push_str(&after_open[..end]);
        output.push_str("</pre>");
        remaining = &after_open[end + close.len()..];
        promoted = true;
    }

    output.push_str(remaining);
    (output, promoted)
}

fn contains_markdown_math(markdown: &str) -> bool {
    let mut in_fence = false;
    for line in markdown.lines() {
        let trimmed = line.trim_start();
        if trimmed.starts_with("```") || trimmed.starts_with("~~~") {
            in_fence = !in_fence;
            continue;
        }
        if in_fence {
            continue;
        }
        if line.starts_with("    ") || line.starts_with('\t') {
            continue;
        }
        let visible_line = line_without_code_spans(line);
        let trimmed_visible = visible_line.trim_start();
        if trimmed_visible.starts_with("$$")
            || trimmed_visible.contains("\\[")
            || trimmed_visible.contains("\\(")
        {
            return true;
        }
        let mut previous_was_escape = false;
        let mut open_inline = false;
        for character in visible_line.chars() {
            if previous_was_escape {
                previous_was_escape = false;
                continue;
            }
            if character == '\\' {
                previous_was_escape = true;
                continue;
            }
            if character == '$' {
                if open_inline {
                    return true;
                }
                open_inline = true;
            }
        }
    }
    false
}

fn line_without_code_spans(line: &str) -> String {
    let mut output = String::with_capacity(line.len());
    let mut code_delimiter_width = None;
    let characters = line.chars().collect::<Vec<_>>();
    let mut index = 0usize;
    while index < characters.len() {
        let character = characters[index];
        if character == '`' {
            let mut run_width = 1usize;
            while index + run_width < characters.len() && characters[index + run_width] == '`' {
                run_width += 1;
            }
            match code_delimiter_width {
                Some(width) if width == run_width => code_delimiter_width = None,
                Some(_) => {}
                None => code_delimiter_width = Some(run_width),
            }
            index += run_width;
            continue;
        }
        if code_delimiter_width.is_none() {
            output.push(character);
        }
        index += 1;
    }
    output
}

fn mermaid_assets() -> &'static str {
    r#"<script type="module">
document.documentElement.dataset.nvbrowserMermaid = "pending";
try {
  const { default: mermaid } = await import("https://cdn.jsdelivr.net/npm/mermaid@10.9.3/dist/mermaid.esm.min.mjs");
  mermaid.initialize({ startOnLoad: false, securityLevel: "strict" });
  await mermaid.run({ querySelector: ".mermaid" });
  document.documentElement.dataset.nvbrowserMermaid = "ready";
} catch (error) {
  document.documentElement.dataset.nvbrowserMermaid = "error";
  console.error("nvim-browser Mermaid render failed", error);
}
</script>"#
}

fn katex_assets() -> &'static str {
    r#"<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">
<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js"></script>
<script>
document.documentElement.dataset.nvbrowserKatex = "pending";
window.addEventListener("load", () => {
  try {
    renderMathInElement(document.body, {
      delimiters: [
        { left: "$$", right: "$$", display: true },
        { left: "\\[", right: "\\]", display: true },
        { left: "$", right: "$", display: false },
        { left: "\\(", right: "\\)", display: false }
      ],
      throwOnError: false
    });
    document.documentElement.dataset.nvbrowserKatex = "ready";
  } catch (error) {
    document.documentElement.dataset.nvbrowserKatex = "error";
    console.error("nvim-browser KaTeX render failed", error);
  }
});
</script>"#
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn render_markdown_document_wraps_body_in_html() {
        let html = render_markdown_document("# Title\n\nHello **Neovim**.");

        assert!(html.contains("<!doctype html>"));
        assert!(html.contains("<h1>Title</h1>"));
        assert!(html.contains("<strong>Neovim</strong>"));
    }

    #[test]
    fn render_markdown_document_can_include_base_url_and_styles() {
        let html = render_markdown_document_with_base_url(
            "# Title\n\n![Logo](images/logo.png)",
            Some("file:///tmp/docs/"),
        );

        assert!(html.contains(r#"<base href="file:///tmp/docs/">"#));
        assert!(html.contains("<style>"));
        assert!(html.contains("font-family"));
        assert!(html.contains(r#"<img src="images/logo.png" alt="Logo" />"#));
    }

    #[test]
    fn render_markdown_document_converts_mermaid_fences_to_diagrams() {
        let html = render_markdown_document(
            r#"# Diagram

```mermaid
graph TD
  A["<start> & go"] --> B{"done?"}
```

```rust
fn main() {}
```
"#,
        );

        assert!(html.contains(r#"<pre class="mermaid">"#));
        assert!(
            html.contains(r#"A[&quot;&lt;start&gt; &amp; go&quot;] --&gt; B{&quot;done?&quot;}"#)
        );
        assert!(html.contains("https://cdn.jsdelivr.net/npm/mermaid@10.9.3/"));
        assert!(html.contains(r#"data-nvbrowser-mermaid="pending""#));
        assert!(html.contains("await import("));
        assert!(!html.contains("import mermaid from"));
        assert!(html.contains("mermaid.initialize"));
        assert!(html.contains("mermaid.run"));
        assert!(html.contains(r#"<code class="language-rust">fn main() {}"#));
    }

    #[test]
    fn render_markdown_document_omits_mermaid_assets_without_mermaid_fences() {
        let html = render_markdown_document(
            r#"```rust
fn main() {}
```
"#,
        );

        assert!(!html.contains("https://cdn.jsdelivr.net/npm/mermaid"));
        assert!(!html.contains("mermaid.initialize"));
        assert!(html.contains(r#"<code class="language-rust">fn main() {}"#));
    }

    #[test]
    fn render_markdown_document_includes_katex_assets_for_inline_and_display_math() {
        let html = render_markdown_document(
            r#"Inline math $E=mc^2$.

$$
\int_0^1 x^2 dx
$$
"#,
        );

        assert!(html.contains("katex"));
        assert!(html.contains("katex.min.css"));
        assert!(html.contains("auto-render"));
        assert!(html.contains("renderMathInElement(document.body"));
        assert!(html.contains(r#"data-nvbrowser-katex="pending""#));
    }

    #[test]
    fn render_markdown_document_omits_katex_assets_without_math() {
        let html = render_markdown_document("# Plain\n\nNo math here.");

        assert!(!html.contains("katex.min.css"));
        assert!(!html.contains("renderMathInElement"));
        assert!(!html.contains("data-nvbrowser-katex"));
    }

    #[test]
    fn render_markdown_document_omits_katex_assets_for_code_dollars() {
        let html = render_markdown_document(
            r#"Use `$HOME` and `$PATH`, or ``$OLDPWD $PWD``.

    echo "$HOME $PATH"
"#,
        );

        assert!(!html.contains("katex.min.css"));
        assert!(!html.contains("renderMathInElement"));
        assert!(!html.contains("data-nvbrowser-katex"));
    }

    #[test]
    fn render_markdown_document_can_include_mermaid_and_katex_assets_together() {
        let html = render_markdown_document(
            r#"```mermaid
graph TD
  A --> B
```

Inline $x+y$.
"#,
        );

        assert!(html.contains("mermaid@"));
        assert!(html.contains("katex"));
        assert!(html.contains(r#"data-nvbrowser-mermaid="pending""#));
        assert!(html.contains(r#"data-nvbrowser-katex="pending""#));
    }
}
