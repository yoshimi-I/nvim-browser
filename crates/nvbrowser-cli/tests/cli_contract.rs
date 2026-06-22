use assert_cmd::Command;
use predicates::prelude::*;
use tempfile::tempdir;

#[test]
fn inspect_outputs_target_json() {
    let mut command = Command::cargo_bin("nvbrowser").expect("binary should build");

    command
        .args(["inspect", "https://example.com"])
        .assert()
        .success()
        .stdout(predicate::str::contains(
            r#"{"input":"https://example.com","kind":"web_url"}"#,
        ));
}

#[test]
fn render_md_outputs_html_document() {
    let directory = tempdir().expect("tempdir should be created");
    let markdown_path = directory.path().join("README.md");
    std::fs::write(&markdown_path, "# Title\n\nHello **Neovim**.")
        .expect("markdown fixture should be written");

    let mut command = Command::cargo_bin("nvbrowser").expect("binary should build");

    command
        .arg("render-md")
        .arg(markdown_path)
        .assert()
        .success()
        .stdout(predicate::str::contains("<!doctype html>"))
        .stdout(predicate::str::contains("<h1>Title</h1>"))
        .stdout(predicate::str::contains("<strong>Neovim</strong>"));
}

#[test]
fn show_image_outputs_kitty_escape() {
    let directory = tempdir().expect("tempdir should be created");
    let image_path = directory.path().join("pixel.png");
    std::fs::write(&image_path, tiny_png()).expect("image fixture should be written");

    let mut command = Command::cargo_bin("nvbrowser").expect("binary should build");

    command
        .arg("show-image")
        .arg(image_path)
        .assert()
        .success()
        .stdout(predicate::str::starts_with("\x1b_G"))
        .stdout(predicate::str::contains("a=T"))
        .stdout(predicate::str::contains("f=100"))
        .stdout(predicate::str::ends_with("\x1b\\"));
}

fn tiny_png() -> Vec<u8> {
    const PNG: &str = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==";
    base64::Engine::decode(&base64::engine::general_purpose::STANDARD, PNG)
        .expect("embedded PNG should decode")
}
