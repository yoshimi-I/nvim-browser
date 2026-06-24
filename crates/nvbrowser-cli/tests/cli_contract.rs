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
        .stdout(predicate::str::contains("--cdp-ws-url"))
        .stdout(predicate::str::contains("--user-data-dir"));
}

#[test]
fn chromium_commands_help_document_user_data_dir_flag() {
    for subcommand in ["browse", "capture"] {
        let mut command = Command::cargo_bin("nvbrowser").expect("binary should build");

        command
            .args([subcommand, "--help"])
            .assert()
            .success()
            .stdout(predicate::str::contains("--user-data-dir"));
    }
}

#[test]
fn opt_in_e2e_serve_loop_drives_real_chromium_over_jsonl() {
    if std::env::var("NVBROWSER_E2E").ok().as_deref() != Some("1") {
        return;
    }

    let directory = tempdir().expect("tempdir should be created");
    let fixture_path = directory.path().join("serve-loop.html");
    let blank_path = directory.path().join("blank-target.html");
    let opened_path = directory.path().join("window-open-target.html");
    let blank_url = format!("file://{}", blank_path.display());
    let opened_url = format!("file://{}", opened_path.display());
    std::fs::write(
        &blank_path,
        format!(
            r##"<!doctype html>
<html>
  <head><title>Blank Target Adopted</title></head>
  <body>
    <main>
      <p>blank target adopted text</p>
      <button onclick="alert('adopted alert'); document.getElementById('adopted-out').textContent='adopted alert handled'">Adopted Alert</button>
      <p id="adopted-out">adopted empty</p>
      <button onclick="window.open('{opened_url}', '_blank')">Open Window Target</button>
    </main>
  </body>
</html>"##
        ),
    )
    .expect("blank target fixture should be written");
    std::fs::write(
        &opened_path,
        r##"<!doctype html>
<html>
  <head><title>Window Open Adopted</title></head>
  <body><main><p>window open adopted text</p></main></body>
</html>"##,
    )
    .expect("window open target fixture should be written");
    std::fs::write(
        &fixture_path,
        format!(
            r##"<!doctype html>
<html>
  <head>
    <title>NBrowser E2E Fixture</title>
    <style>
      #hover-menu {{ display: none; margin-top: 8px; }}
      #hover-source:hover + #hover-menu {{ display: inline-block; }}
      #wheel-box {{ position: fixed; left: 16px; top: 220px; width: 220px; height: 60px; overflow: auto; border: 1px solid #333; }}
      #wheel-box-inner {{ height: 240px; }}
    </style>
  </head>
  <body>
    <main>
      <a target="_blank" href="{blank_url}" onpointerdown="window.open(this.href, this.target); event.preventDefault(); return false;">Open Blank Target</a>
      <label>Search <input aria-label="Search" oninput="document.getElementById('out').textContent=this.value"></label>
      <a href="#docs">Docs</a>
      <button onpointerdown="document.getElementById('out').textContent='clicked from jsonl'">Go</button>
      <button onclick="alert('hello'); document.getElementById('out').textContent='alert handled'">Alert Dialog</button>
      <button onclick="document.getElementById('out').textContent = confirm('continue?') ? 'confirm accepted' : 'confirm dismissed'">Confirm Dialog</button>
      <button onclick="const value = prompt('name', 'default'); document.getElementById('out').textContent = value === null ? 'prompt dismissed' : value">Prompt Dialog</button>
      <button id="hover-source">Menu</button>
      <a id="hover-menu" href="#hovered">Hover Docs</a>
      <div contenteditable="true">Editable target</div>
      <p id="out">empty</p>
      <div id="wheel-box" onwheel="document.getElementById('out').textContent='wheel box wheeled'" onscroll="document.getElementById('out').textContent='wheel box scrolled'"><button id="wheel-button">Wheel Target</button><div id="wheel-box-inner">Wheel space</div></div>
      <section id="docs">Docs section</section>
      <section id="hovered">Hovered section</section>
    </main>
  </body>
</html>"##
        ),
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
    let input_hint_id = input_hint["id"]
        .as_u64()
        .expect("input hint should include id");

    let typed = serve.request(serde_json::json!({
        "id": 1,
        "type": "type_hint",
        "hint_id": input_hint_id,
        "text": "hello from jsonl",
        "submit": false
    }));
    assert_eq!(
        typed["id"], 1,
        "type_hint response should preserve request id"
    );
    assert_eq!(typed["status"], "ok", "type_hint should succeed");

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

    let button_hint = hints
        .iter()
        .find(|hint| hint["kind"] == "button" && hint["label"] == "Go")
        .expect("real Chromium hints should include the clickable button");
    let button_hint_id = button_hint["id"]
        .as_u64()
        .expect("button hint should include id");
    let clicked = serve.request(serde_json::json!({
        "id": 4,
        "type": "click_hint",
        "hint_id": button_hint_id
    }));
    assert_eq!(
        clicked["id"], 4,
        "click_hint response should preserve request id"
    );
    assert_eq!(clicked["status"], "ok", "click_hint should succeed");
    let clicked_text = serve.request(serde_json::json!({ "id": 5, "type": "page_text" }));
    assert_eq!(
        clicked_text["status"], "ok",
        "page_text after click_hint should succeed"
    );
    assert!(
        clicked_text["text"]["text"]
            .as_str()
            .is_some_and(|text| text.contains("clicked from jsonl")),
        "page_text should observe DOM updated by clicked button"
    );

    let dialog_hints = clicked["hints"]
        .as_array()
        .expect("clicked response should include fresh hints");
    let alert_hint_id = dialog_hints
        .iter()
        .find(|hint| hint["kind"] == "button" && hint["label"] == "Alert Dialog")
        .expect("real Chromium hints should include the alert button")["id"]
        .as_u64()
        .expect("alert hint should include id");
    let alerted = serve.request(serde_json::json!({
        "id": 6,
        "type": "click_hint",
        "hint_id": alert_hint_id
    }));
    assert_eq!(alerted["status"], "ok", "alert click should not hang");
    let alerted_text = serve.request(serde_json::json!({ "id": 7, "type": "page_text" }));
    assert!(
        alerted_text["text"]["text"]
            .as_str()
            .is_some_and(|text| text.contains("alert handled")),
        "alert should be accepted so page script can continue"
    );

    let dialog_hints = alerted["hints"]
        .as_array()
        .expect("alert response should include fresh hints");
    let confirm_hint_id = dialog_hints
        .iter()
        .find(|hint| hint["kind"] == "button" && hint["label"] == "Confirm Dialog")
        .expect("real Chromium hints should include the confirm button")["id"]
        .as_u64()
        .expect("confirm hint should include id");
    let confirmed = serve.request(serde_json::json!({
        "id": 8,
        "type": "click_hint",
        "hint_id": confirm_hint_id
    }));
    assert_eq!(confirmed["status"], "ok", "confirm click should not hang");
    let confirmed_text = serve.request(serde_json::json!({ "id": 9, "type": "page_text" }));
    assert!(
        confirmed_text["text"]["text"]
            .as_str()
            .is_some_and(|text| text.contains("confirm dismissed")),
        "confirm should be dismissed by default"
    );

    let dialog_hints = confirmed["hints"]
        .as_array()
        .expect("confirm response should include fresh hints");
    let prompt_hint_id = dialog_hints
        .iter()
        .find(|hint| hint["kind"] == "button" && hint["label"] == "Prompt Dialog")
        .expect("real Chromium hints should include the prompt button")["id"]
        .as_u64()
        .expect("prompt hint should include id");
    let prompted = serve.request(serde_json::json!({
        "id": 10,
        "type": "click_hint",
        "hint_id": prompt_hint_id
    }));
    assert_eq!(prompted["status"], "ok", "prompt click should not hang");
    let prompted_text = serve.request(serde_json::json!({ "id": 11, "type": "page_text" }));
    assert!(
        prompted_text["text"]["text"]
            .as_str()
            .is_some_and(|text| text.contains("prompt dismissed")),
        "prompt should be dismissed by default"
    );

    let menu_hint = hints
        .iter()
        .find(|hint| hint["kind"] == "button" && hint["label"] == "Menu")
        .expect("real Chromium hints should include the hover trigger button");
    let menu_hint_id = menu_hint["id"]
        .as_u64()
        .expect("menu hint should include id");
    let hovered = serve.request(serde_json::json!({
        "id": 12,
        "type": "hover_hint",
        "hint_id": menu_hint_id
    }));
    assert_eq!(
        hovered["id"], 12,
        "hover_hint response should preserve request id"
    );
    assert_eq!(hovered["status"], "ok", "hover_hint should succeed");
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
        "hover_hint should reveal hover-only link hints"
    );

    let wheel_hint = hovered["hints"]
        .as_array()
        .expect("hover response should include fresh hints")
        .iter()
        .find(|hint| hint["kind"] == "button" && hint["label"] == "Wheel Target")
        .expect("real Chromium hints should include the nested wheel target button");
    let wheeled = serve.request(serde_json::json!({
        "id": 13,
        "type": "wheel_point",
        "x": wheel_hint["x"].as_f64().expect("wheel target should include x"),
        "y": wheel_hint["y"].as_f64().expect("wheel target should include y"),
        "delta_x": 0.0,
        "delta_y": 160.0
    }));
    assert_eq!(wheeled["status"], "ok", "wheel_point should succeed");
    let wheeled_text = serve.request(serde_json::json!({ "id": 14, "type": "page_text" }));
    let wheeled_page_text = wheeled_text["text"]["text"]
        .as_str()
        .expect("page_text after wheel should include text");
    assert!(
        wheeled_page_text.contains("wheel box scrolled"),
        "wheel_point should scroll the nested element at the target coordinates; page text was {wheeled_page_text:?}"
    );

    let resized = serve.request(serde_json::json!({
        "id": 15,
        "type": "resize",
        "columns": 32,
        "rows": 10,
        "width": 320,
        "height": 200
    }));
    assert_eq!(resized["runtime"]["cells"]["columns"], 32);
    assert_eq!(resized["runtime"]["viewport"]["width"], 320);

    let blank_target_hint = resized["hints"]
        .as_array()
        .expect("resized response should include hints")
        .iter()
        .find(|hint| hint["kind"] == "link" && hint["label"] == "Open Blank Target")
        .expect("real Chromium hints should include the target blank link")["id"]
        .as_u64()
        .expect("target blank link hint should include id");
    let adopted_blank = serve.request(serde_json::json!({
        "id": 16,
        "type": "click_hint",
        "hint_id": blank_target_hint
    }));
    assert_eq!(
        adopted_blank["status"], "ok",
        "target blank click should succeed; response={adopted_blank:?}"
    );
    assert_eq!(
        adopted_blank["title"], "Blank Target Adopted",
        "target blank click should adopt the new page target"
    );
    assert!(
        adopted_blank["url"]
            .as_str()
            .is_some_and(|url| url.ends_with("blank-target.html")),
        "target blank response should use the adopted page URL"
    );
    let adopted_blank_text = serve.request(serde_json::json!({ "id": 17, "type": "page_text" }));
    assert!(
        adopted_blank_text["text"]["text"]
            .as_str()
            .is_some_and(|text| text.contains("blank target adopted text")),
        "page_text should read from the adopted target blank page"
    );

    let adopted_alert_hint = adopted_blank["hints"]
        .as_array()
        .expect("adopted blank response should include hints")
        .iter()
        .find(|hint| hint["kind"] == "button" && hint["label"] == "Adopted Alert")
        .expect("adopted blank page should expose alert button")["id"]
        .as_u64()
        .expect("adopted alert hint should include id");
    let adopted_alert = serve.request(serde_json::json!({
        "id": 18,
        "type": "click_hint",
        "hint_id": adopted_alert_hint
    }));
    assert_eq!(
        adopted_alert["status"], "ok",
        "adopted tab alert should not hang"
    );
    let adopted_alert_text = serve.request(serde_json::json!({ "id": 19, "type": "page_text" }));
    assert!(
        adopted_alert_text["text"]["text"]
            .as_str()
            .is_some_and(|text| text.contains("adopted alert handled")),
        "adopted tab alert should be handled by the installed dialog listener"
    );

    let open_window_hint = adopted_alert["hints"]
        .as_array()
        .expect("adopted alert response should include hints")
        .iter()
        .find(|hint| hint["kind"] == "button" && hint["label"] == "Open Window Target")
        .expect("adopted blank page should expose window.open button")["id"]
        .as_u64()
        .expect("window open button hint should include id");
    let adopted_window = serve.request(serde_json::json!({
        "id": 20,
        "type": "click_hint",
        "hint_id": open_window_hint
    }));
    assert_eq!(
        adopted_window["status"], "ok",
        "window.open click should succeed"
    );
    assert_eq!(
        adopted_window["title"], "Window Open Adopted",
        "window.open click should adopt the newly opened page target"
    );
    let adopted_window_text = serve.request(serde_json::json!({ "id": 21, "type": "page_text" }));
    assert!(
        adopted_window_text["text"]["text"]
            .as_str()
            .is_some_and(|text| text.contains("window open adopted text")),
        "page_text should read from the adopted window.open page"
    );

    let quit = serve.request(serde_json::json!({ "id": 22, "type": "quit" }));
    assert_eq!(quit["id"], 22);
    assert_eq!(quit["status"], "ok");

    serve.wait_success();
}

#[test]
fn opt_in_e2e_serve_loop_focuses_hint_for_text_entry() {
    if std::env::var("NVBROWSER_E2E").ok().as_deref() != Some("1") {
        return;
    }

    let directory = tempdir().expect("tempdir should be created");
    let fixture_path = directory.path().join("focus-hint.html");
    std::fs::write(
        &fixture_path,
        r##"<!doctype html>
<html>
  <head><title>NBrowser Focus E2E Fixture</title></head>
  <body>
    <main>
      <label>Search <input aria-label="Search" oninput="document.getElementById('out').textContent='search ' + this.value"></label>
      <textarea aria-label="Notes" oninput="document.getElementById('notes-out').textContent='notes ' + this.value"></textarea>
      <div contenteditable="true" aria-label="Editable" style="min-height: 1em" oninput="document.getElementById('edit-out').textContent='editable ' + this.textContent"></div>
      <p id="out">empty</p>
      <p id="notes-out">notes empty</p>
      <p id="edit-out">editable empty</p>
    </main>
  </body>
</html>"##,
    )
    .expect("focus fixture should be written");
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
    assert_eq!(initial["status"], "ok", "initial navigation should succeed");
    let hints = initial["hints"]
        .as_array()
        .expect("initial response should include hints");
    let search_hint_id = hints
        .iter()
        .find(|hint| hint["kind"] == "input" && hint["label"] == "Search")
        .expect("real Chromium hints should include the search input")["id"]
        .as_u64()
        .expect("search hint should include id");

    let focused_input = serve.request(serde_json::json!({
        "id": 1,
        "type": "focus_hint",
        "hint_id": search_hint_id
    }));
    assert_eq!(
        focused_input["status"], "ok",
        "focus_hint should focus a hinted input"
    );
    let focused_text = serve.request(serde_json::json!({
        "id": 2,
        "type": "text_input",
        "text": "focused search"
    }));
    assert_eq!(
        focused_text["status"], "ok",
        "text_input should type into the focused hint"
    );
    let focused_page_text = serve.request(serde_json::json!({ "id": 3, "type": "page_text" }));
    assert!(
        focused_page_text["text"]["text"]
            .as_str()
            .is_some_and(|text| text.contains("search focused search")),
        "page_text should observe DOM updated after focus_hint plus text_input"
    );

    let textarea_hint_id = initial["hints"]
        .as_array()
        .expect("initial response should include hints")
        .iter()
        .find(|hint| hint["kind"] == "text_area" && hint["label"] == "Notes")
        .expect("real Chromium hints should include the textarea")["id"]
        .as_u64()
        .expect("textarea hint should include id");
    let textarea_typed = serve.request(serde_json::json!({
        "id": 4,
        "type": "type_hint",
        "hint_id": textarea_hint_id,
        "text": "draft notes",
        "submit": false
    }));
    assert_eq!(
        textarea_typed["status"], "ok",
        "type_hint should type into textarea hints"
    );
    let textarea_page_text = serve.request(serde_json::json!({ "id": 5, "type": "page_text" }));
    assert!(
        textarea_page_text["text"]["text"]
            .as_str()
            .is_some_and(|text| text.contains("notes draft notes")),
        "page_text should observe textarea updates from type_hint"
    );

    let editable_hint_id = initial["hints"]
        .as_array()
        .expect("initial response should include hints")
        .iter()
        .find(|hint| hint["kind"] == "editable" && hint["label"] == "Editable")
        .expect("real Chromium hints should include the editable region")["id"]
        .as_u64()
        .expect("editable hint should include id");
    let editable_typed = serve.request(serde_json::json!({
        "id": 6,
        "type": "type_hint",
        "hint_id": editable_hint_id,
        "text": "editable content",
        "submit": false
    }));
    assert_eq!(
        editable_typed["status"], "ok",
        "type_hint should type into contenteditable hints"
    );
    let editable_page_text = serve.request(serde_json::json!({ "id": 7, "type": "page_text" }));
    assert!(
        editable_page_text["text"]["text"]
            .as_str()
            .is_some_and(|text| text.contains("editable content")),
        "page_text should observe contenteditable text updates from type_hint; response={editable_page_text:?}"
    );

    let quit = serve.request(serde_json::json!({ "id": 8, "type": "quit" }));
    assert_eq!(quit["status"], "ok");
    serve.wait_success();
}

#[test]
fn opt_in_e2e_serve_loop_reports_focused_elements_and_submits_current_focus() {
    if std::env::var("NVBROWSER_E2E").ok().as_deref() != Some("1") {
        return;
    }

    let directory = tempdir().expect("tempdir should be created");
    let fixture_path = directory.path().join("focused-elements.html");
    std::fs::write(
        &fixture_path,
        r##"<!doctype html>
<html>
  <head><title>NBrowser Focus Metadata E2E Fixture</title></head>
  <body>
    <main>
      <form onsubmit="event.preventDefault(); document.getElementById('out').textContent='submitted ' + document.getElementById('search').value">
        <label>Search <input id="search" aria-label="Search" value="query"></label>
        <label>Notes <textarea aria-label="Notes"></textarea></label>
        <label>Country
          <select aria-label="Country" onchange="document.getElementById('country-out').textContent='country ' + this.value">
            <option value="jp">Japan</option>
            <option value="ca">Canada</option>
          </select>
        </label>
        <label><input id="newsletter" type="checkbox"> Newsletter</label>
      </form>
      <p id="out">empty</p>
      <p id="country-out">country empty</p>
    </main>
  </body>
</html>"##,
    )
    .expect("focus metadata fixture should be written");
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
    assert_eq!(initial["status"], "ok", "initial navigation should succeed");
    assert!(
        initial.get("focused").is_none_or(Value::is_null),
        "initial page load should not report a body-only active element"
    );
    let hints = initial["hints"]
        .as_array()
        .expect("initial response should include hints");
    let search_hint_id = hints
        .iter()
        .find(|hint| hint["kind"] == "input" && hint["label"] == "Search")
        .expect("real Chromium hints should include the search input")["id"]
        .as_u64()
        .expect("search hint should include id");
    let select_hint_id = hints
        .iter()
        .find(|hint| hint["kind"] == "select" && hint["label"] == "Country")
        .expect("real Chromium hints should include the select")["id"]
        .as_u64()
        .expect("select hint should include id");
    let checkbox_hint_id = hints
        .iter()
        .find(|hint| hint["kind"] == "checkbox" && hint["label"] == "Newsletter")
        .expect("real Chromium hints should include the checkbox")["id"]
        .as_u64()
        .expect("checkbox hint should include id");

    let focused_input = serve.request(serde_json::json!({
        "id": 1,
        "type": "focus_hint",
        "hint_id": search_hint_id
    }));
    assert_eq!(focused_input["status"], "ok");
    assert_eq!(focused_input["focused"]["kind"], "input");
    assert_eq!(focused_input["focused"]["label"], "Search");
    assert_eq!(focused_input["focused"]["value"], "query");
    assert_eq!(focused_input["focused"]["submittable"], true);

    let submitted = serve.request(serde_json::json!({
        "id": 2,
        "type": "submit_focused"
    }));
    assert_eq!(
        submitted["status"], "ok",
        "submit_focused should submit a focused form input"
    );
    let submitted_text = serve.request(serde_json::json!({ "id": 3, "type": "page_text" }));
    assert!(
        submitted_text["text"]["text"]
            .as_str()
            .is_some_and(|text| text.contains("submitted query")),
        "page_text should observe form submit triggered by submit_focused"
    );

    let tabbed = serve.request(serde_json::json!({
        "id": 4,
        "type": "key_press",
        "key": "Tab"
    }));
    assert_eq!(tabbed["status"], "ok");
    assert_eq!(tabbed["focused"]["kind"], "text_area");
    assert_eq!(tabbed["focused"]["label"], "Notes");

    let selected = serve.request(serde_json::json!({
        "id": 5,
        "type": "select_hint",
        "hint_id": select_hint_id,
        "choice": "Canada"
    }));
    assert_eq!(selected["status"], "ok", "select_hint should succeed");
    assert_eq!(selected["focused"]["kind"], "select");
    assert_eq!(selected["focused"]["label"], "Country");
    assert_eq!(selected["focused"]["value"], "ca");

    let checked = serve.request(serde_json::json!({
        "id": 6,
        "type": "toggle_hint",
        "hint_id": checkbox_hint_id
    }));
    assert_eq!(checked["status"], "ok", "toggle_hint should succeed");
    assert_eq!(checked["focused"]["kind"], "checkbox");
    assert_eq!(checked["focused"]["label"], "Newsletter");
    assert_eq!(checked["focused"]["checked"], true);

    let quit = serve.request(serde_json::json!({ "id": 7, "type": "quit" }));
    assert_eq!(quit["status"], "ok");
    serve.wait_success();
}

#[test]
fn opt_in_e2e_serve_loop_reports_metrics_for_top_bottom_scroll() {
    if std::env::var("NVBROWSER_E2E").ok().as_deref() != Some("1") {
        return;
    }

    let directory = tempdir().expect("tempdir should be created");
    let fixture_path = directory.path().join("scroll-metrics.html");
    std::fs::write(
        &fixture_path,
        r##"<!doctype html>
<html>
  <head>
    <title>NBrowser Scroll Metrics E2E Fixture</title>
    <style>body { margin: 0; } main { min-height: 2400px; padding-top: 1px; }</style>
  </head>
  <body><main><p>top</p><p style="margin-top: 2200px">bottom</p></main></body>
</html>"##,
    )
    .expect("scroll fixture should be written");
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
    assert_eq!(initial["status"], "ok", "initial navigation should succeed");
    let page = initial["page"]
        .as_object()
        .expect("initial response should include page metrics");
    let scroll_y = page["scroll_y"]
        .as_f64()
        .expect("scroll_y should be numeric");
    let viewport_height = page["viewport_height"]
        .as_f64()
        .expect("viewport_height should be numeric");
    let document_height = page["document_height"]
        .as_f64()
        .expect("document_height should be numeric");
    assert_eq!(scroll_y, 0.0, "initial page should start at the top");
    assert!(
        document_height > viewport_height,
        "fixture should be taller than the viewport"
    );

    let bottom_delta = (document_height - viewport_height - scroll_y).floor() as i32;
    let bottom = serve.request(serde_json::json!({
        "id": 1,
        "type": "scroll",
        "delta_y": bottom_delta,
        "delta_x": 0
    }));
    assert_eq!(
        bottom["status"], "ok",
        "bottom scroll should succeed; response={bottom:?}"
    );
    let bottom_scroll_y = bottom["page"]["scroll_y"]
        .as_f64()
        .expect("bottom response should include scroll_y");
    assert!(
        bottom_scroll_y >= f64::from(bottom_delta) - 4.0,
        "bottom scroll should reach near the document bottom; response={bottom:?}"
    );

    let top = serve.request(serde_json::json!({
        "id": 2,
        "type": "scroll",
        "delta_y": -(bottom_scroll_y.floor() as i32),
        "delta_x": 0
    }));
    assert_eq!(top["status"], "ok", "top scroll should succeed");
    let top_scroll_y = top["page"]["scroll_y"]
        .as_f64()
        .expect("top response should include scroll_y");
    assert!(
        top_scroll_y <= 4.0,
        "top scroll should return near the document top; response={top:?}"
    );

    let quit = serve.request(serde_json::json!({ "id": 3, "type": "quit" }));
    assert_eq!(quit["status"], "ok");
    serve.wait_success();
}

#[test]
fn opt_in_e2e_serve_loop_applies_page_zoom() {
    if std::env::var("NVBROWSER_E2E").ok().as_deref() != Some("1") {
        return;
    }

    fn observed_inner_width(response: &Value) -> u32 {
        let text = response["text"]["text"]
            .as_str()
            .expect("page_text response should include text");
        text.split("innerWidth: ")
            .nth(1)
            .and_then(|width| width.split_whitespace().next())
            .and_then(|width| width.parse::<u32>().ok())
            .unwrap_or_else(|| panic!("page_text should include innerWidth; response={response:?}"))
    }

    let directory = tempdir().expect("tempdir should be created");
    let fixture_path = directory.path().join("zoom.html");
    std::fs::write(
        &fixture_path,
        r##"<!doctype html>
<html>
  <head>
    <title>NBrowser Zoom E2E Fixture</title>
    <style>
      body { background: white; color: black; font-family: sans-serif; margin: 24px; }
      #zoom-state::before { content: 'wide'; }
      @media (max-width: 420px) {
        body { background: black; color: white; }
        #zoom-state::before { content: 'narrow'; }
      }
    </style>
    <script>
      function updateWidth() {
        document.getElementById('width').textContent = 'innerWidth: ' + window.innerWidth;
      }
      window.addEventListener('resize', updateWidth);
      window.addEventListener('DOMContentLoaded', updateWidth);
      setInterval(updateWidth, 50);
    </script>
  </head>
  <body><main><h1>Zoom target</h1><p id="zoom-state"></p><p id="width">innerWidth: pending</p></main></body>
</html>"##,
    )
    .expect("zoom fixture should be written");
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
    assert_eq!(initial["status"], "ok", "initial navigation should succeed");
    let initial_payload = initial["payload"]
        .as_str()
        .expect("initial response should include a frame payload")
        .to_string();
    let initial_text = serve.request(serde_json::json!({ "id": 1, "type": "page_text" }));
    let initial_width = observed_inner_width(&initial_text);
    assert!(
        initial_width > 420,
        "initial fixture should start in wide mode; response={initial_text:?}"
    );

    let zoomed = serve.request(serde_json::json!({
        "id": 2,
        "type": "zoom",
        "scale": 1.25
    }));
    assert_eq!(
        zoomed["status"], "ok",
        "zoom request should succeed through real CDP; response={zoomed:?}"
    );
    assert!(
        zoomed["payload"]
            .as_str()
            .is_some_and(|payload| !payload.is_empty()),
        "zoom response should include a fresh frame payload"
    );
    assert_eq!(
        zoomed["title"].as_str(),
        Some("NBrowser Zoom E2E Fixture"),
        "zoom response should preserve page title metadata"
    );
    let zoomed_payload = zoomed["payload"]
        .as_str()
        .expect("zoom response should include a frame payload");
    assert!(
        zoomed_payload != initial_payload,
        "zoom should visibly change the captured frame payload"
    );
    let zoomed_text = serve.request(serde_json::json!({ "id": 3, "type": "page_text" }));
    let zoomed_width = observed_inner_width(&zoomed_text);
    assert!(
        zoomed_width < initial_width && zoomed_width <= 420,
        "zoom should shrink the effective CSS viewport enough to enter narrow mode; initial={initial_width}, zoomed={zoomed_width}, response={zoomed_text:?}"
    );

    let reset = serve.request(serde_json::json!({
        "id": 4,
        "type": "zoom",
        "scale": 1.0
    }));
    assert_eq!(
        reset["status"], "ok",
        "zoom reset should succeed through real CDP; response={reset:?}"
    );

    let reset_text = serve.request(serde_json::json!({ "id": 5, "type": "page_text" }));
    let reset_width = observed_inner_width(&reset_text);
    assert_eq!(
        reset_width, initial_width,
        "zoom reset should restore the effective CSS viewport; response={reset_text:?}"
    );

    let quit = serve.request(serde_json::json!({ "id": 6, "type": "quit" }));
    assert_eq!(quit["status"], "ok");
    serve.wait_success();
}

#[test]
fn opt_in_e2e_serve_loop_adopts_delayed_about_blank_window_open() {
    if std::env::var("NVBROWSER_E2E").ok().as_deref() != Some("1") {
        return;
    }

    let directory = tempdir().expect("tempdir should be created");
    let fixture_path = directory.path().join("delayed-window-open.html");
    let delayed_path = directory.path().join("delayed-target.html");
    let delayed_url = format!("file://{}", delayed_path.display());
    std::fs::write(
        &delayed_path,
        r##"<!doctype html>
<html>
  <head><title>Delayed Window Adopted</title></head>
  <body>
    <main>
      <p>delayed adopted text</p>
      <button onclick="alert('delayed alert'); document.getElementById('out').textContent='delayed alert handled'">Delayed Alert</button>
      <p id="out">delayed empty</p>
    </main>
  </body>
</html>"##,
    )
    .expect("delayed target fixture should be written");
    std::fs::write(
        &fixture_path,
        format!(
            r##"<!doctype html>
<html>
  <head><title>NBrowser Delayed Window Fixture</title></head>
  <body>
    <main>
      <button onclick="const child = window.open('about:blank', '_blank'); setTimeout(() => {{ child.location.href = '{delayed_url}'; }}, 250)">Open Delayed Window</button>
    </main>
  </body>
</html>"##
        ),
    )
    .expect("delayed opener fixture should be written");
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
    assert_eq!(initial["status"], "ok", "initial navigation should succeed");
    let delayed_open_hint = initial["hints"]
        .as_array()
        .expect("initial response should include hints")
        .iter()
        .find(|hint| hint["kind"] == "button" && hint["label"] == "Open Delayed Window")
        .expect("real Chromium hints should include delayed window button")["id"]
        .as_u64()
        .expect("delayed window hint should include id");

    let adopted = serve.request(serde_json::json!({
        "id": 1,
        "type": "click_hint",
        "hint_id": delayed_open_hint
    }));
    assert_eq!(
        adopted["status"], "ok",
        "delayed about:blank window.open should succeed; response={adopted:?}"
    );
    assert_eq!(
        adopted["title"], "Delayed Window Adopted",
        "delayed about:blank window.open should adopt the navigated child target"
    );
    assert!(
        adopted["url"]
            .as_str()
            .is_some_and(|url| url.ends_with("delayed-target.html")),
        "delayed window response should use the adopted page URL"
    );
    let text = serve.request(serde_json::json!({ "id": 2, "type": "page_text" }));
    assert!(
        text["text"]["text"]
            .as_str()
            .is_some_and(|text| text.contains("delayed adopted text")),
        "page_text should read from the delayed adopted target"
    );

    let alert_hint = adopted["hints"]
        .as_array()
        .expect("adopted response should include hints")
        .iter()
        .find(|hint| hint["kind"] == "button" && hint["label"] == "Delayed Alert")
        .expect("adopted delayed target should expose alert button")["id"]
        .as_u64()
        .expect("delayed alert hint should include id");
    let alert = serve.request(serde_json::json!({
        "id": 3,
        "type": "click_hint",
        "hint_id": alert_hint
    }));
    assert_eq!(
        alert["status"], "ok",
        "adopted delayed target should have a dialog handler"
    );
    let alert_text = serve.request(serde_json::json!({ "id": 4, "type": "page_text" }));
    assert!(
        alert_text["text"]["text"]
            .as_str()
            .is_some_and(|text| text.contains("delayed alert handled")),
        "adopted delayed target dialog should be handled"
    );

    let quit = serve.request(serde_json::json!({ "id": 5, "type": "quit" }));
    assert_eq!(quit["status"], "ok");
    serve.wait_success();
}

#[test]
fn opt_in_e2e_serve_loop_selects_real_chromium_hint() {
    if std::env::var("NVBROWSER_E2E").ok().as_deref() != Some("1") {
        return;
    }

    let directory = tempdir().expect("tempdir should be created");
    let fixture_path = directory.path().join("select-hint.html");
    std::fs::write(
        &fixture_path,
        r##"<!doctype html>
<html>
  <head><title>NBrowser Select E2E Fixture</title></head>
  <body>
    <main>
      <label>Country
        <select aria-label="Country" onchange="document.getElementById('out').textContent='country ' + this.value">
          <option value="jp">Japan</option>
          <option value="ca">Canada</option>
          <option value="de">Germany</option>
        </select>
      </label>
      <p id="out">empty</p>
    </main>
  </body>
</html>"##,
    )
    .expect("select fixture should be written");
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
    assert_eq!(initial["status"], "ok", "initial navigation should succeed");
    let select_hint_id = initial["hints"]
        .as_array()
        .expect("initial response should include hints")
        .iter()
        .find(|hint| hint["kind"] == "select")
        .expect("real Chromium hints should include the select")["id"]
        .as_u64()
        .expect("select hint should include id");

    let selected = serve.request(serde_json::json!({
        "id": 1,
        "type": "select_hint",
        "hint_id": select_hint_id,
        "choice": "Canada"
    }));
    assert_eq!(
        selected["status"], "ok",
        "select_hint should succeed; response={selected:?}"
    );
    let selected_text = serve.request(serde_json::json!({ "id": 2, "type": "page_text" }));
    assert!(
        selected_text["text"]["text"]
            .as_str()
            .is_some_and(|text| text.contains("country ca")),
        "page_text should observe DOM updated by selected option"
    );

    let quit = serve.request(serde_json::json!({ "id": 3, "type": "quit" }));
    assert_eq!(quit["status"], "ok");
    serve.wait_success();
}

#[test]
fn opt_in_e2e_serve_loop_toggles_checkbox_and_radio_hints() {
    if std::env::var("NVBROWSER_E2E").ok().as_deref() != Some("1") {
        return;
    }

    let directory = tempdir().expect("tempdir should be created");
    let fixture_path = directory.path().join("toggle-hint.html");
    std::fs::write(
        &fixture_path,
        r##"<!doctype html>
<html>
  <head><title>NBrowser Toggle E2E Fixture</title></head>
  <body>
    <main>
      <label><input id="newsletter" type="checkbox" onclick="document.getElementById('out').textContent='newsletter click ' + this.checked"> Newsletter</label>
      <input id="standard" type="radio" name="plan" value="standard" aria-labelledby="standard-label" onclick="document.getElementById('out').textContent='plan click ' + this.value">
      <span id="standard-label">Standard Plan</span>
      <p id="out">empty</p>
    </main>
  </body>
</html>"##,
    )
    .expect("toggle fixture should be written");
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
    assert_eq!(initial["status"], "ok", "initial navigation should succeed");
    let hints = initial["hints"]
        .as_array()
        .expect("initial response should include hints");
    let checkbox_hint = hints
        .iter()
        .find(|hint| hint["kind"] == "checkbox" && hint["label"] == "Newsletter")
        .expect("real Chromium hints should include labeled checkbox");
    assert_eq!(checkbox_hint["checked"], false);
    let checkbox_hint_id = checkbox_hint["id"]
        .as_u64()
        .expect("checkbox hint should include id");

    let checked = serve.request(serde_json::json!({
        "id": 1,
        "type": "toggle_hint",
        "hint_id": checkbox_hint_id
    }));
    assert_eq!(
        checked["status"], "ok",
        "checkbox toggle_hint should succeed; response={checked:?}"
    );
    assert!(
        checked["hints"]
            .as_array()
            .is_some_and(|hints| hints.iter().any(|hint| {
                hint["kind"] == "checkbox"
                    && hint["label"] == "Newsletter"
                    && hint["checked"] == true
            })),
        "checkbox hint should report checked state after toggle"
    );
    let checked_text = serve.request(serde_json::json!({ "id": 2, "type": "page_text" }));
    assert!(
        checked_text["text"]["text"]
            .as_str()
            .is_some_and(|text| text.contains("newsletter click true")),
        "page_text should observe checkbox click handler"
    );

    let radio_hint = checked["hints"]
        .as_array()
        .expect("checked response should include hints")
        .iter()
        .find(|hint| hint["kind"] == "radio" && hint["label"] == "Standard Plan")
        .expect("real Chromium hints should include labeled radio");
    assert_eq!(radio_hint["checked"], false);
    let radio_hint_id = radio_hint["id"]
        .as_u64()
        .expect("radio hint should include id");
    let selected = serve.request(serde_json::json!({
        "id": 3,
        "type": "toggle_hint",
        "hint_id": radio_hint_id
    }));
    assert_eq!(
        selected["status"], "ok",
        "radio toggle_hint should succeed; response={selected:?}"
    );
    assert!(
        selected["hints"]
            .as_array()
            .is_some_and(|hints| hints.iter().any(|hint| {
                hint["kind"] == "radio"
                    && hint["label"] == "Standard Plan"
                    && hint["checked"] == true
            })),
        "radio hint should report checked state after toggle"
    );
    let selected_text = serve.request(serde_json::json!({ "id": 4, "type": "page_text" }));
    assert!(
        selected_text["text"]["text"]
            .as_str()
            .is_some_and(|text| text.contains("plan click standard")),
        "page_text should observe radio click handler"
    );

    let quit = serve.request(serde_json::json!({ "id": 5, "type": "quit" }));
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
