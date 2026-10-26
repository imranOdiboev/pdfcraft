//! The foundation acceptance path uses real CLI processes and synthetic, labelled pages.
//! qpdf and pdftotext independently check the results when required by the Linux CI job.

use std::path::{Path, PathBuf};
use std::process::{Command, Output};
use std::sync::atomic::{AtomicU64, Ordering};

use pdfcraft_testkit::Pdf;
use serde_json::json;

const BIN: &str = env!("CARGO_BIN_EXE_odibo-pdf-cli");
static NEXT: AtomicU64 = AtomicU64::new(0);

struct Workdir(PathBuf);

impl Workdir {
    fn new() -> Self {
        let path = std::env::temp_dir().join(format!("odibo-foundation-{}-{}", std::process::id(), NEXT.fetch_add(1, Ordering::Relaxed)));
        assert!(!path.exists(), "test directory already exists: {}", path.display());
        std::fs::create_dir(&path).unwrap();
        Self(path)
    }
}

impl Drop for Workdir {
    fn drop(&mut self) {
        // Only the fresh directory this test created, never a caller-supplied path.
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

fn fixture(labels: &[&str]) -> Vec<u8> {
    let kids = (0..labels.len()).map(|i| format!("{} 0 R", 4 + 2 * i)).collect::<Vec<_>>().join(" ");
    let mut pdf = Pdf::new()
        .obj("<< /Type /Catalog /Pages 2 0 R >>")
        .obj(format!("<< /Type /Pages /Kids [{kids}] /Count {} /MediaBox [0 0 200 300] >>", labels.len()))
        .obj("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>");
    for (i, label) in labels.iter().enumerate() {
        pdf = pdf
            .obj(format!("<< /Type /Page /Parent 2 0 R /Contents {} 0 R /Resources << /Font << /F1 3 0 R >> >> >>", 5 + 2 * i))
            .stream("", format!("BT /F1 20 Tf 20 150 Td ({label}) Tj ET"));
    }
    pdf.build()
}

fn cli(root: &Path, args: &[&str]) -> Output {
    Command::new(BIN).current_dir(root).args(args).output().unwrap()
}

fn success(root: &Path, args: &[&str]) -> Output {
    let output = cli(root, args);
    assert!(output.status.success(), "{args:?}: {}", String::from_utf8_lossy(&output.stderr));
    output
}

fn script(root: &Path, steps: serde_json::Value) {
    std::fs::write(root.join("steps.json"), serde_json::to_vec_pretty(&steps).unwrap()).unwrap();
    success(root, &["run", "--script", "steps.json", "--root", ".", "--report"]);
}

fn ordered(text: &str, labels: &[&str]) {
    let found: Vec<&str> = text.split_whitespace().filter(|word| word.starts_with("LEFT-") || word.starts_with("RIGHT-")).collect();
    assert_eq!(found, labels, "unexpected page text or ordering: {text:?}");
}

fn external(program: &str, path: &Path, args: &[&str]) -> Option<Output> {
    match Command::new(program).args(args).current_dir(path).output() {
        Ok(output) => Some(output),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound && std::env::var_os("PDFCRAFT_ORACLES_REQUIRED").is_none() => {
            eprintln!("SKIPPED independent {program}: unavailable on this runner; Linux CI requires it");
            None
        }
        Err(error) => panic!("required independent checker {program}: {error}"),
    }
}

fn verify(root: &Path, name: &str, expected: &[&str]) {
    let info = success(root, &["info", name]);
    let info: serde_json::Value = serde_json::from_slice(&info.stdout).unwrap();
    assert_eq!(info["pages"].as_u64(), Some(expected.len() as u64), "{info}");
    let text = success(root, &["text", name]);
    ordered(&String::from_utf8_lossy(&text.stdout), expected);
    if let Some(output) = external("qpdf", root, &["--check", name]) {
        assert!(output.status.success(), "qpdf {name}: {}", String::from_utf8_lossy(&output.stderr));
    }
    if let Some(output) = external("pdftotext", root, &["-layout", name, "-"]) {
        assert!(output.status.success(), "pdftotext {name}: {}", String::from_utf8_lossy(&output.stderr));
        ordered(&String::from_utf8_lossy(&output.stdout), expected);
    }
}

#[test]
fn open_combine_save_reopen_and_split_preserve_pages_and_sources() {
    let dir = Workdir::new();
    let root = dir.0.join("Документы с пробелами");
    std::fs::create_dir(&root).unwrap();
    let left = fixture(&["LEFT-1", "LEFT-2"]);
    let right = fixture(&["RIGHT-1", "RIGHT-2", "RIGHT-3"]);
    std::fs::write(root.join("left.pdf"), &left).unwrap();
    std::fs::write(root.join("right.pdf"), &right).unwrap();
    verify(&root, "left.pdf", &["LEFT-1", "LEFT-2"]);
    verify(&root, "right.pdf", &["RIGHT-1", "RIGHT-2", "RIGHT-3"]);
    success(&root, &["combine", "left.pdf", "right.pdf", "--out", "merged.pdf"]);
    let all = ["LEFT-1", "LEFT-2", "RIGHT-1", "RIGHT-2", "RIGHT-3"];
    verify(&root, "merged.pdf", &all);

    script(
        &root,
        json!([
            {"tool":"doc_open", "args":{"path":"merged.pdf"}},
            {"tool":"doc_set_info", "args":{"doc":1,"key":"Title","value":"Foundation round trip"}},
            {"tool":"doc_save", "args":{"doc":1,"path":"saved.pdf"}},
            {"tool":"doc_close", "args":{"doc":1}},
            {"tool":"doc_open", "args":{"path":"saved.pdf"}},
            {"tool":"page_render", "args":{"doc":2,"page":1,"dpi":72},"out":"preview.png"}
        ]),
    );
    verify(&root, "saved.pdf", &all);
    let png = std::fs::read(root.join("preview.png")).unwrap();
    assert!(png.starts_with(b"\x89PNG\r\n\x1a\n"));
    assert!(png.len() > 200, "a rendered labelled page must contain image data");

    let saved = std::fs::read(root.join("saved.pdf")).unwrap();
    script(
        &root,
        json!([
            {"tool":"doc_open", "args":{"path":"saved.pdf"}},
            {"tool":"doc_set_info", "args":{"doc":1,"key":"Subject","value":"Incremental save"}},
            {"tool":"doc_save", "args":{"doc":1}},
            {"tool":"doc_close", "args":{"doc":1}}
        ]),
    );
    assert!(std::fs::read(root.join("saved.pdf")).unwrap().starts_with(&saved), "in-place save must preserve the previous revision");
    verify(&root, "saved.pdf", &all);
    success(&root, &["split", "saved.pdf", "--every", "2", "--out-dir", "parts"]);
    let mut parts = std::fs::read_dir(root.join("parts")).unwrap().map(|entry| entry.unwrap().path()).collect::<Vec<_>>();
    parts.sort();
    assert_eq!(parts.len(), 3);
    for (path, expected) in parts.iter().zip(all.chunks(2)) {
        verify(&root, path.to_str().unwrap(), expected);
    }
    assert_eq!(std::fs::read(root.join("left.pdf")).unwrap(), left);
    assert_eq!(std::fs::read(root.join("right.pdf")).unwrap(), right);
}

#[test]
fn invalid_pdf_and_invalid_ranges_fail_without_changing_sources() {
    let dir = Workdir::new();
    let original = fixture(&["LEFT-1", "LEFT-2"]);
    std::fs::write(dir.0.join("source.pdf"), &original).unwrap();
    std::fs::write(dir.0.join("damaged.pdf"), b"This is not a PDF").unwrap();
    assert!(!cli(&dir.0, &["info", "damaged.pdf"]).status.success());
    assert!(!cli(&dir.0, &["extract", "source.pdf", "--pages", "99", "--out", "rejected.pdf"]).status.success());
    assert!(!dir.0.join("rejected.pdf").exists());
    assert_eq!(std::fs::read(dir.0.join("source.pdf")).unwrap(), original);
    verify(&dir.0, "source.pdf", &["LEFT-1", "LEFT-2"]);
}

#[test]
fn a_failed_save_preserves_the_destination_and_the_original() {
    let dir = Workdir::new();
    let original = fixture(&["LEFT-1"]);
    std::fs::write(dir.0.join("source.pdf"), &original).unwrap();
    std::fs::write(dir.0.join("blocked"), b"SENTINEL").unwrap();
    let steps = json!([
        {"tool":"doc_open", "args":{"path":"source.pdf"}},
        {"tool":"doc_set_info", "args":{"doc":1,"key":"Title","value":"Unsaved"}},
        {"tool":"doc_save", "args":{"doc":1,"path":"blocked/out.pdf"}}
    ]);
    std::fs::write(dir.0.join("steps.json"), serde_json::to_vec(&steps).unwrap()).unwrap();
    assert!(!cli(&dir.0, &["run", "--script", "steps.json", "--root", "."]).status.success());
    assert_eq!(std::fs::read(dir.0.join("blocked")).unwrap(), b"SENTINEL");
    assert_eq!(std::fs::read(dir.0.join("source.pdf")).unwrap(), original);
}

#[test]
fn beta_organize_annotation_and_cyrillic_signature_survive_save_reopen() {
    let dir = Workdir::new();
    let root = dir.0.join("Проверка беты");
    std::fs::create_dir(&root).unwrap();
    let original = fixture(&["LEFT-1", "LEFT-2", "LEFT-3", "LEFT-4"]);
    std::fs::write(root.join("Исходный документ.pdf"), &original).unwrap();
    let steps = json!([
        {"tool":"doc_open","args":{"path":"Исходный документ.pdf"}},
        {"tool":"page_move","args":{"doc":1,"pages":[4],"to":1}},
        {"tool":"page_rotate","args":{"doc":1,"pages":[2],"degrees":90}},
        {"tool":"page_delete","args":{"doc":1,"pages":[3]}},
        {"tool":"comment_add","args":{"doc":1,"page":1,"type":"note","at":[25,30],"contents":"Проверено: учебный документ","author":"Тест"}},
        {"tool":"fill_sign_add","args":{"doc":1,"page":1,"type":"signature","at":[30,100],"text":"Иван"}},
        {"tool":"doc_save","args":{"doc":1,"path":"Проверенная копия.pdf"}},
        {"tool":"doc_close","args":{"doc":1}},
        {"tool":"doc_open","args":{"path":"Проверенная копия.pdf"}},
        {"tool":"comment_list","args":{"doc":2}},
        {"tool":"page_render","args":{"doc":2,"page":2,"dpi":72},"out":"rotated.png"}
    ]);
    std::fs::write(root.join("steps.json"), serde_json::to_vec(&steps).unwrap()).unwrap();
    let output = success(&root, &["run", "--script", "steps.json", "--root", ".", "--report"]);
    let report: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(report["ok"], true);
    let comments = report["steps"][9]["result"].to_string();
    assert!(comments.contains("Проверено: учебный документ"), "{comments}");
    assert!(report["steps"][9]["result"][0]["count"].as_u64().unwrap() >= 2, "note and typed signature must survive reopening: {comments}");
    verify(&root, "Проверенная копия.pdf", &["LEFT-4", "LEFT-1", "LEFT-3"]);
    let info = pdfcraft_render::inspect(std::sync::Arc::new(std::fs::read(root.join("Проверенная копия.pdf")).unwrap()), None).unwrap();
    assert_eq!(info.pages[1].rotation, 90);
    assert!(std::fs::read(root.join("rotated.png")).unwrap().starts_with(b"\x89PNG\r\n\x1a\n"));
    assert_eq!(std::fs::read(root.join("Исходный документ.pdf")).unwrap(), original);
}
