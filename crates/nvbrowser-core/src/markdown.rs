use comrak::{markdown_to_html, Options};

pub fn render_markdown_document(markdown: &str) -> String {
    let body = markdown_to_html(markdown, &Options::default());
    format!(
        "<!doctype html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n</head>\n<body>\n{body}</body>\n</html>\n"
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
}
