use std::path::Path;

use serde::Serialize;

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum TargetKind {
    WebUrl,
    MarkdownFile,
    HtmlFile,
    PdfFile,
    ImageFile,
    UnknownFile,
    SearchQuery,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct InspectResult {
    pub input: String,
    pub kind: TargetKind,
}

impl InspectResult {
    pub fn to_json(&self) -> String {
        serde_json::to_string(self).expect("inspect result should always serialize")
    }
}

pub fn target_kind(input: &str) -> TargetKind {
    if input.starts_with("http://") || input.starts_with("https://") {
        return TargetKind::WebUrl;
    }

    let path = Path::new(input);
    match path
        .extension()
        .and_then(|extension| extension.to_str())
        .map(|extension| extension.to_ascii_lowercase())
        .as_deref()
    {
        Some("md") | Some("markdown") => TargetKind::MarkdownFile,
        Some("html") | Some("htm") => TargetKind::HtmlFile,
        Some("pdf") => TargetKind::PdfFile,
        Some("png") | Some("jpg") | Some("jpeg") | Some("gif") | Some("webp") | Some("svg") => {
            TargetKind::ImageFile
        }
        Some(_) => TargetKind::UnknownFile,
        None => TargetKind::SearchQuery,
    }
}

pub fn inspect_target(input: &str) -> InspectResult {
    InspectResult {
        input: input.to_string(),
        kind: target_kind(input),
    }
}

pub fn supports_direct_terminal_image(path: &str) -> bool {
    matches!(
        Path::new(path)
            .extension()
            .and_then(|extension| extension.to_str())
            .map(|extension| extension.to_ascii_lowercase())
            .as_deref(),
        Some("png" | "jpg" | "jpeg" | "gif" | "webp")
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn target_kind_detects_web_urls() {
        assert_eq!(target_kind("https://example.com"), TargetKind::WebUrl);
        assert_eq!(target_kind("http://localhost:3000"), TargetKind::WebUrl);
    }

    #[test]
    fn target_kind_detects_markdown_files() {
        assert_eq!(target_kind("README.md"), TargetKind::MarkdownFile);
        assert_eq!(target_kind("/tmp/post.markdown"), TargetKind::MarkdownFile);
    }

    #[test]
    fn target_kind_detects_image_files() {
        assert_eq!(target_kind("diagram.png"), TargetKind::ImageFile);
        assert_eq!(target_kind("photo.JPEG"), TargetKind::ImageFile);
        assert_eq!(target_kind("vector.svg"), TargetKind::ImageFile);
    }

    #[test]
    fn target_kind_detects_html_files() {
        assert_eq!(target_kind("index.html"), TargetKind::HtmlFile);
        assert_eq!(target_kind("preview.htm"), TargetKind::HtmlFile);
    }

    #[test]
    fn target_kind_detects_pdf_files() {
        assert_eq!(target_kind("paper.pdf"), TargetKind::PdfFile);
        assert_eq!(target_kind("/tmp/REPORT.PDF"), TargetKind::PdfFile);
    }

    #[test]
    fn inspect_target_serializes_to_json() {
        let json = inspect_target("README.md").to_json();

        assert!(json.contains("\"input\":\"README.md\""));
        assert!(json.contains("\"kind\":\"markdown_file\""));
    }

    #[test]
    fn inspect_target_serializes_pdf_files() {
        let json = inspect_target("paper.pdf").to_json();

        assert!(json.contains("\"input\":\"paper.pdf\""));
        assert!(json.contains("\"kind\":\"pdf_file\""));
    }

    #[test]
    fn direct_terminal_images_are_limited_to_raster_formats() {
        assert!(supports_direct_terminal_image("screenshot.png"));
        assert!(supports_direct_terminal_image("photo.jpeg"));
        assert!(!supports_direct_terminal_image("diagram.svg"));
    }
}
