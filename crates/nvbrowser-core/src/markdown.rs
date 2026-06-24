use comrak::{markdown_to_html, Options};

pub fn render_markdown_document(markdown: &str) -> String {
    render_markdown_document_with_base_url(markdown, None)
}

pub fn render_markdown_document_with_base_url(markdown: &str, base_href: Option<&str>) -> String {
    let raw_body = markdown_to_html(markdown, &Options::default());
    let (body, has_mermaid) = promote_mermaid_code_blocks(&raw_body);
    let base = base_href
        .filter(|href| !href.is_empty())
        .map(|href| format!(r#"<base href="{href}">"#))
        .unwrap_or_default();
    let mermaid_assets = if has_mermaid { mermaid_assets() } else { "" };
    let html_attrs = if has_mermaid {
        r#" data-nvbrowser-mermaid="pending""#
    } else {
        ""
    };
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
}
