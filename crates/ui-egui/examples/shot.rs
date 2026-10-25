//! Headless screenshot of the real PdfCraft shell (egui_kittest + wgpu, no window needed).
//!
//! ```text
//! cargo run -p pdfcraft-ui-egui --example shot -- out.png [file.pdf] [--size 1440x900] [--scale 2] [--page 3 --panel pages …]
//! ```
//! `--width N` downscales the image to N pixels wide (README screenshots).
//! `--click LABEL` activates a real egui control after initial layout, before capture.
//! Any other `--key value` pair is passed to `PdfCraftApp::set_option`
//! (the same verbs as the desktop app's command-line flags and the future control channel).

use std::time::{Duration, Instant};

use egui_kittest::Harness;
use egui_kittest::kittest::Queryable;
use pdfcraft_ui_egui::PdfCraftApp;

fn main() -> Result<(), String> {
    let mut args = std::env::args().skip(1);
    let out = args.next().ok_or("usage: shot <out.png> [file.pdf] [--option value …]")?;
    let (mut file, mut opts) = (None, Vec::new());
    let (mut size, mut scale) = (egui::vec2(1440.0, 900.0), 2.0f32);
    let mut width: Option<u32> = None;
    let mut metrics_path = None;
    while let Some(a) = args.next() {
        match a.strip_prefix("--") {
            Some("size") => {
                let v = args.next().unwrap_or_default();
                let (w, h) = v.split_once('x').ok_or("--size WxH")?;
                size = egui::vec2(w.parse().map_err(|_| "bad width")?, h.parse().map_err(|_| "bad height")?);
            }
            Some("scale") => scale = args.next().and_then(|v| v.parse().ok()).ok_or("bad --scale")?,
            Some("width") => width = Some(args.next().and_then(|v| v.parse().ok()).ok_or("bad --width")?),
            Some("metrics") => metrics_path = Some(args.next().ok_or("--metrics needs a JSON path")?),
            Some(k) => opts.push((k.to_string(), args.next().unwrap_or_default())),
            None => file = Some(a),
        }
    }
    let click = opts.iter().find(|(key, _)| key == "click").map(|(_, label)| label.clone());
    let combine_fixture = opts.iter().any(|(key, value)| key == "combine-fixture" && value == "yes");
    let split_ranges = opts.iter().find(|(key, _)| key == "split-ranges").map(|(_, value)| value.clone());
    let invoke = opts.iter().find(|(key, _)| key == "invoke").map(|(_, value)| value.clone());
    opts.retain(|(key, _)| key != "click" && key != "combine-fixture" && key != "split-ranges" && key != "invoke");
    let opening = std::sync::Arc::new(std::sync::Mutex::new(None));
    let opening_record = opening.clone();
    let capture_start = Instant::now();
    let mut harness = Harness::builder().with_size(size).with_pixels_per_point(scale).build_eframe(move |_cc| {
        let mut app = PdfCraftApp::new();
        if let Some(f) = &file {
            let opened = Instant::now();
            let bytes = std::fs::read(f).unwrap_or_default();
            let input_size = bytes.len();
            let name = std::path::Path::new(f).file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
            if let Err(e) = app.open_bytes(&name, Some(f.clone()), bytes) {
                eprintln!("shot: {f}: {e}");
            } else {
                *opening_record.lock().unwrap_or_else(std::sync::PoisonError::into_inner) = Some((opened.elapsed().as_secs_f64(), input_size));
            }
        }
        for (k, v) in &opts {
            if let Err(e) = app.set_option(k, v) {
                eprintln!("shot: --{k} {v}: {e}");
            }
        }
        if combine_fixture && let Some(f) = &file {
            let bytes = std::fs::read(f).unwrap_or_default();
            app.use_files(pdfcraft_ui_egui::FilePurpose::Combine, vec![("First.pdf".into(), bytes.clone()), ("Second.pdf".into(), bytes)]);
        }
        if let Some(ranges) = &split_ranges {
            app.split_draft.mode = pdfcraft_ui_egui::SplitMode::Ranges;
            app.split_draft.ranges = ranges.clone();
        }
        if let Some(command) = &invoke {
            app.execute(command);
        }
        app
    });
    // Let fonts install, layout settle and background renders arrive.
    let start = Instant::now();
    harness.run_steps(4);
    if let Some(label) = click {
        let Some(node) = harness.query_by_role_and_label(egui::accesskit::Role::Button, &label) else {
            return Err(format!("shot: clickable button not found: {label}"));
        };
        node.click();
        harness.run_steps(4);
    }
    while start.elapsed() < Duration::from_secs(20) {
        harness.run_steps(2);
        if !harness.state().render_pending() {
            harness.run_steps(3);
            if !harness.state().render_pending() {
                break;
            }
        }
        std::thread::sleep(Duration::from_millis(30));
    }
    let mut image = harness.render()?;
    let first_capture_seconds = capture_start.elapsed().as_secs_f64();
    if let Some(path) = metrics_path {
        let (open_seconds, input_bytes) = opening.lock().unwrap_or_else(std::sync::PoisonError::into_inner).ok_or("metrics requires a successfully opened PDF")?;
        if harness.state().render_pending() { return Err("first-page rendering did not settle within the bounded wait".into()); }
        let report = serde_json::json!({"source": std::env::var("GITHUB_SHA").unwrap_or_default(), "file_read_and_open_seconds": open_seconds,
            "first_ready_capture_seconds": first_capture_seconds, "input_bytes": input_bytes, "viewport": [size.x, size.y], "pixels_per_point": scale,
            "method": "Fresh headless egui_kittest/wgpu app; first settled capture includes app creation, font setup, layout and rendering. Not native Windows window startup."});
        std::fs::write(path, serde_json::to_vec_pretty(&report).map_err(|e| e.to_string())?).map_err(|e| e.to_string())?;
    }
    if let Some(w) = width.filter(|w| *w < image.width()) {
        let h = (image.height() as f64 * w as f64 / image.width() as f64).round() as u32;
        image = image::imageops::resize(&image, w, h, image::imageops::FilterType::Lanczos3);
    }
    image.save(&out).map_err(|e| e.to_string())?;
    eprintln!("shot: wrote {out} ({}×{})", image.width(), image.height());
    Ok(())
}
