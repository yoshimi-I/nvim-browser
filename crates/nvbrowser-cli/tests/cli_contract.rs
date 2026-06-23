use assert_cmd::Command;
use predicates::prelude::*;
use serde_json::Value;
use std::io::{BufRead, BufReader, Write};
use std::process::{Child, ChildStdin, Command as StdCommand, Stdio};
use std::sync::mpsc::{self, Receiver};
use std::thread;
use std::time::{Duration, Instant};
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

#[test]
fn serve_help_documents_cdp_ws_url_flag() {
    let mut command = Command::cargo_bin("nvbrowser").expect("binary should build");

    command
        .args(["serve", "--help"])
        .assert()
        .success()
        .stdout(predicate::str::contains("--cdp-ws-url"));
}

#[test]
fn opt_in_e2e_serve_loop_drives_real_chromium_over_jsonl() {
    if std::env::var("NVBROWSER_E2E").ok().as_deref() != Some("1") {
        return;
    }

    let directory = tempdir().expect("tempdir should be created");
    let fixture_path = directory.path().join("serve-loop.html");
    std::fs::write(
        &fixture_path,
        r##"<!doctype html>
<html>
  <head>
    <title>NBrowser E2E Fixture</title>
    <style>
      #hover-menu { display: none; margin-top: 8px; }
      #hover-source:hover + #hover-menu { display: inline-block; }
    </style>
  </head>
  <body>
    <main>
      <label>Search <input aria-label="Search" oninput="document.getElementById('out').textContent=this.value"></label>
      <a href="#docs">Docs</a>
      <button>Go</button>
      <button id="hover-source">Menu</button>
      <a id="hover-menu" href="#hovered">Hover Docs</a>
      <div contenteditable="true">Editable target</div>
      <p id="out">empty</p>
      <section id="docs">Docs section</section>
      <section id="hovered">Hovered section</section>
    </main>
  </body>
</html>"##,
    )
    .expect("html fixture should be written");
    let fixture_url = format!("file://{}", fixture_path.display());

    let mut command = StdCommand::new(assert_cmd::cargo::cargo_bin("nvbrowser"));
    command
        .args([
            "serve",
            "--output",
            "ansi",
            "--columns",
            "48",
            "--rows",
            "16",
            "--width",
            "480",
            "--height",
            "320",
            "--url",
            &fixture_url,
        ])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit());
    if std::env::var_os("NVBROWSER_CHROME").is_none() {
        if let Some(chrome) = default_e2e_chrome() {
            command.env("NVBROWSER_CHROME", chrome);
        }
    }

    let mut serve = ServeProcess::spawn(command);

    let initial = serve.read_json();
    assert_eq!(
        initial["id"], 0,
        "initial navigation should use response id 0"
    );
    assert_eq!(initial["status"], "ok", "initial navigation should succeed");
    assert_eq!(
        initial["title"], "NBrowser E2E Fixture",
        "initial response should include the page title"
    );
    assert!(
        initial["payload"]
            .as_str()
            .is_some_and(|payload| payload.contains("\u{1b}[")),
        "ansi serve output should include terminal escape payload"
    );
    let hints = initial["hints"]
        .as_array()
        .expect("initial response should include hints");
    assert!(
        hints
            .iter()
            .any(|hint| hint["kind"] == "link" && hint["href"].as_str().is_some()),
        "real Chromium hints should include direct hrefs for links"
    );
    assert!(
        !hints.iter().any(|hint| hint["label"] == "Hover Docs"),
        "hidden hover links should not be hinted before hover"
    );
    let input_hint = hints
        .iter()
        .find(|hint| hint["kind"] == "input" && hint["label"] == "Search")
        .expect("real Chromium hints should include the labeled input");
    let input_x = input_hint["x"]
        .as_f64()
        .expect("input hint should include x");
    let input_y = input_hint["y"]
        .as_f64()
        .expect("input hint should include y");

    let typed = serve.request(serde_json::json!({
        "id": 1,
        "type": "type_point",
        "x": input_x,
        "y": input_y,
        "text": "hello from jsonl",
        "submit": false
    }));
    assert_eq!(
        typed["id"], 1,
        "type_point response should preserve request id"
    );
    assert_eq!(typed["status"], "ok", "type_point should succeed");

    let page_text = serve.request(serde_json::json!({ "id": 2, "type": "page_text" }));
    assert_eq!(page_text["status"], "ok", "page_text should succeed");
    assert!(
        page_text["text"]["text"]
            .as_str()
            .is_some_and(|text| text.contains("hello from jsonl")),
        "page_text should observe DOM updated by typed input"
    );

    let found = serve
        .request(serde_json::json!({ "id": 3, "type": "find_text", "query": "hello from jsonl" }));
    assert_eq!(found["status"], "ok", "find_text should succeed");
    assert_eq!(
        found["found"], true,
        "find_text should report the typed text"
    );

    let menu_hint = hints
        .iter()
        .find(|hint| hint["kind"] == "button" && hint["label"] == "Menu")
        .expect("real Chromium hints should include the hover trigger button");
    let menu_x = menu_hint["x"].as_f64().expect("menu hint should include x");
    let menu_y = menu_hint["y"].as_f64().expect("menu hint should include y");
    let hovered = serve.request(serde_json::json!({
        "id": 4,
        "type": "hover_point",
        "x": menu_x,
        "y": menu_y
    }));
    assert_eq!(
        hovered["id"], 4,
        "hover_point response should preserve request id"
    );
    assert_eq!(hovered["status"], "ok", "hover_point should succeed");
    assert!(
        hovered["hints"]
            .as_array()
            .is_some_and(|hints| hints.iter().any(|hint| {
                hint["kind"] == "link"
                    && hint["label"] == "Hover Docs"
                    && hint["href"]
                        .as_str()
                        .is_some_and(|href| href.ends_with("#hovered"))
            })),
        "hover_point should reveal hover-only link hints"
    );

    let resized = serve.request(serde_json::json!({
        "id": 5,
        "type": "resize",
        "columns": 32,
        "rows": 10,
        "width": 320,
        "height": 200
    }));
    assert_eq!(resized["runtime"]["cells"]["columns"], 32);
    assert_eq!(resized["runtime"]["viewport"]["width"], 320);

    let quit = serve.request(serde_json::json!({ "id": 6, "type": "quit" }));
    assert_eq!(quit["id"], 6);
    assert_eq!(quit["status"], "ok");

    serve.wait_success();
}

fn tiny_png() -> Vec<u8> {
    const PNG: &str = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==";
    base64::Engine::decode(&base64::engine::general_purpose::STANDARD, PNG)
        .expect("embedded PNG should decode")
}

fn default_e2e_chrome() -> Option<&'static str> {
    [
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "/Applications/Chromium.app/Contents/MacOS/Chromium",
        "/usr/bin/google-chrome",
        "/usr/bin/chromium",
        "/usr/bin/chromium-browser",
    ]
    .into_iter()
    .find(|path| std::path::Path::new(path).is_file())
}

struct ServeProcess {
    child: Child,
    stdin: ChildStdin,
    lines: Receiver<std::io::Result<String>>,
    finished: bool,
}

impl ServeProcess {
    fn spawn(mut command: StdCommand) -> Self {
        let mut child = command.spawn().expect("serve process should start");
        let stdin = child.stdin.take().expect("serve stdin should be piped");
        let stdout = child.stdout.take().expect("serve stdout should be piped");
        let (sender, lines) = mpsc::channel();
        thread::spawn(move || {
            let mut reader = BufReader::new(stdout);
            loop {
                let mut line = String::new();
                match reader.read_line(&mut line) {
                    Ok(0) => break,
                    Ok(_) => {
                        if sender.send(Ok(line)).is_err() {
                            break;
                        }
                    }
                    Err(error) => {
                        let _ = sender.send(Err(error));
                        break;
                    }
                }
            }
        });
        Self {
            child,
            stdin,
            lines,
            finished: false,
        }
    }

    fn request(&mut self, request: Value) -> Value {
        writeln!(self.stdin, "{request}").expect("serve request should be written");
        self.stdin.flush().expect("serve request should be flushed");
        self.read_json()
    }

    fn read_json(&mut self) -> Value {
        let line = self
            .lines
            .recv_timeout(Duration::from_secs(20))
            .expect("serve should write a JSONL response before timeout")
            .expect("serve stdout reader should not fail");
        assert!(
            !line.trim().is_empty(),
            "serve response should not be empty"
        );
        serde_json::from_str(&line).expect("serve response should be valid JSON")
    }

    fn wait_success(&mut self) {
        if let Some(status) = self.wait_for_exit(Duration::from_secs(10)) {
            self.finished = true;
            assert!(status.success(), "serve process should exit successfully");
            return;
        }
        let _ = self.child.kill();
        let _ = self.child.wait();
        self.finished = true;
        panic!("serve process did not exit before timeout");
    }

    fn wait_for_exit(&mut self, timeout: Duration) -> Option<std::process::ExitStatus> {
        let deadline = Instant::now() + timeout;
        loop {
            if let Some(status) = self
                .child
                .try_wait()
                .expect("serve process status should be readable")
            {
                return Some(status);
            }
            if Instant::now() >= deadline {
                return None;
            }
            thread::sleep(Duration::from_millis(50));
        }
    }
}

impl Drop for ServeProcess {
    fn drop(&mut self) {
        if self.finished {
            return;
        }
        if matches!(self.child.try_wait(), Ok(Some(_))) {
            return;
        }
        let _ = writeln!(self.stdin, r#"{{"id":999999,"type":"quit"}}"#);
        let _ = self.stdin.flush();
        if self.wait_for_exit(Duration::from_secs(3)).is_some() {
            self.finished = true;
            return;
        }
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}
