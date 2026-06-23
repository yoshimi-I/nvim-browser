use comrak::{markdown_to_html, Options};

pub fn render_markdown_document(markdown: &str) -> String {
    render_markdown_document_with_base_url(markdown, None)
}

pub fn render_markdown_document_with_base_url(markdown: &str, base_href: Option<&str>) -> String {
    let body = markdown_to_html(markdown, &Options::default());
    let base = base_href
        .filter(|href| !href.is_empty())
        .map(|href| format!(r#"<base href="{href}">"#))
        .unwrap_or_default();
    format!(
        r#"<!doctype html>
<html>
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
</style>
</head>
<body>
{body}</body>
</html>
"#
    )
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
}
