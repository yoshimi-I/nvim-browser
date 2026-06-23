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
        .stdout(predicate::str::contains("<base href=\"file://"))
        .stdout(predicate::str::contains("<style>"))
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

#[test]
fn show_image_can_fit_to_kitty_placement() {
    let directory = tempdir().expect("tempdir should be created");
    let image_path = directory.path().join("pixel.png");
    std::fs::write(&image_path, tiny_png()).expect("image fixture should be written");

    let mut command = Command::cargo_bin("nvbrowser").expect("binary should build");

    command
        .arg("show-image")
        .arg(image_path)
        .args([
            "--output",
            "kitty",
            "--columns",
            "2",
            "--rows",
            "2",
            "--width",
            "20",
            "--height",
            "40",
            "--fit",
            "contain",
        ])
        .assert()
        .success()
        .stdout(predicate::str::contains("p=1,c=2,r=2"))
        .stdout(predicate::str::contains("s=20,v=20"));
}

#[test]
fn show_image_outputs_ansi_halfblocks() {
    let directory = tempdir().expect("tempdir should be created");
    let image_path = directory.path().join("pixel.png");
    std::fs::write(&image_path, tiny_png()).expect("image fixture should be written");

    let mut command = Command::cargo_bin("nvbrowser").expect("binary should build");

    command
        .arg("show-image")
        .arg(image_path)
        .args(["--output", "ansi", "--columns", "1"])
        .assert()
        .success()
        .stdout(predicate::str::contains("\x1b[38;2;"))
        .stdout(predicate::str::contains("▀"))
        .stdout(predicate::str::ends_with("\x1b[0m\n"));
}

#[test]
fn show_image_ansi_contain_respects_rows() {
    let directory = tempdir().expect("tempdir should be created");
    let image_path = directory.path().join("pixel.png");
    std::fs::write(&image_path, tiny_png()).expect("image fixture should be written");

    let mut command = Command::cargo_bin("nvbrowser").expect("binary should build");

    let output = command
        .arg("show-image")
        .arg(image_path)
        .args([
            "--output",
            "ansi",
            "--columns",
            "4",
            "--rows",
            "2",
            "--width",
            "40",
            "--height",
            "40",
            "--fit",
            "contain",
        ])
        .assert()
        .success()
        .get_output()
        .stdout
        .clone();
    let output = String::from_utf8(output).expect("ansi output should be utf-8");

    assert_eq!(output.lines().count(), 2);
}

#[test]
fn capture_rejects_conflicting_stdout_outputs_before_chrome_launch() {
    let mut command = Command::cargo_bin("nvbrowser").expect("binary should build");

    command
        .args([
            "capture",
            "https://example.com",
            "--output",
            "-",
            "--metadata",
            "-",
        ])
        .assert()
        .failure()
        .stderr(predicate::str::contains(
            "cannot write PNG and metadata to stdout",
        ));
}

fn tiny_png() -> Vec<u8> {
    const PNG: &str = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==";
    base64::Engine::decode(&base64::engine::general_purpose::STANDARD, PNG)
        .expect("embedded PNG should decode")
}
