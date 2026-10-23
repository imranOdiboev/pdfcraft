//! Home cards drive existing asynchronous pickers and guarded commands, not mock actions.
use egui_kittest::Harness;
use egui_kittest::kittest::Queryable;
use pdfcraft_ui_egui::{Dialog, PdfCraftApp, QuickTool, RecentFile};

const PDF: &[u8] = b"%PDF-1.7\n1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 300 400] >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF";

fn harness(size: egui::Vec2, language: &'static str, theme: &'static str, scale: f32) -> Harness<'static, PdfCraftApp> {
    let mut h = Harness::builder().with_size(size).with_pixels_per_point(scale).build_eframe(move |_cc| {
        let mut app = PdfCraftApp::new();
        app.set_option("language", language).unwrap();
        app.set_option("theme", theme).unwrap();
        app.run_inline = true;
        app
    });
    h.run_steps(4);
    h
}

#[test]
fn home_cards_open_a_pdf_then_run_the_real_action() {
    let dir = std::env::temp_dir().join(format!("odibo-home-actions-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join("synthetic.pdf");
    std::fs::write(&path, PDF).unwrap();
    for label in ["Open file", "Split", "Edit text & images", "Add comments", "Fill & Sign", "Organize pages"] {
        let mut h = harness(egui::vec2(1400.0, 1000.0), "en", "light", 1.0);
        h.state_mut().pick_override = Some(vec![path.to_string_lossy().into_owned()]);
        // The catalogue can contain the same label; Home cards are in the central area.
        h.query_all_by_label(label).find(|n| n.rect().left() > 260.0).unwrap().click();
        super::support::wait_until(&mut h, "Home picked document", |app| app.views.len() == 1);
        h.run_steps(3);
        assert_eq!(h.state().views.len(), 1, "{label} must open the picked PDF");
        assert_eq!(h.state().active, Some(0));
        match label {
            "Split" => assert!(matches!(h.state().dialog, Some(Dialog::Split))),
            "Edit text & images" => assert_eq!(h.state().quick_tool, QuickTool::EditText),
            "Add comments" => assert!(matches!(h.state().quick_tool, QuickTool::Comment(_))),
            "Fill & Sign" => assert!(matches!(h.state().dialog, Some(Dialog::Signature))),
            "Organize pages" => assert!(h.state().views[0].organize),
            _ => {}
        }
        let doc = h.state().session.get(h.state().views[0].id).unwrap();
        assert!(!doc.dirty, "choosing {label} must not mutate the document");
        assert_eq!(std::fs::read(&path).unwrap(), PDF);
    }
    std::fs::remove_dir_all(dir).unwrap();
}

#[test]
fn home_card_cancel_does_not_run_or_change_documents() {
    for label in ["Open file", "Split", "Edit text & images", "Add comments", "Fill & Sign", "Organize pages"] {
        let mut h = harness(egui::vec2(1400.0, 1000.0), "en", "dark", 1.0);
        h.state_mut().pick_override = Some(vec![]);
        h.query_all_by_label(label).find(|n| n.rect().left() > 260.0).unwrap().click();
        h.run_steps(6);
        assert!(h.state().views.is_empty());
        assert!(h.state().dialog.is_none());
    }
}

#[test]
fn home_combine_card_opens_existing_combine_workspace() {
    let mut h = harness(egui::vec2(1400.0, 1000.0), "en", "light", 1.0);
    h.query_all_by_label("Combine files").find(|n| n.rect().left() > 260.0).unwrap().click();
    h.run_steps(4);
    assert!(h.state().combine_showing());
    assert!(h.state().views.is_empty());
}

#[test]
fn home_recent_opens_a_real_file_from_disk() {
    let dir = std::env::temp_dir().join(format!("odibo-home-recent-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join("recent-synthetic.pdf");
    std::fs::write(&path, PDF).unwrap();
    let mut h = harness(egui::vec2(1400.0, 1100.0), "en", "dark", 1.0);
    h.state_mut().recent.push(RecentFile {
        name: "recent-synthetic.pdf".into(),
        path: path.to_string_lossy().into_owned(),
        pages: 1,
        size: PDF.len(),
    });
    h.run_steps(3);
    h.get_by_label("recent-synthetic.pdf").click();
    super::support::wait_until(&mut h, "recent PDF", |app| app.views.len() == 1);
    assert_eq!(h.state().active, Some(0));
    let doc = h.state().session.get(h.state().views[0].id).unwrap();
    assert_eq!(pdfcraft_render::PageRenderer::new(doc.bytes.clone(), Default::default()).page_count(), 1);
    assert_eq!(std::fs::read(&path).unwrap(), PDF);
    std::fs::remove_dir_all(dir).unwrap();
}

#[test]
fn home_recent_reuses_open_tab_and_missing_file_keeps_it_safe() {
    let mut h = harness(egui::vec2(1400.0, 1100.0), "en", "light", 1.0);
    let path = "/odibo-synthetic/already-open.pdf";
    h.state_mut().open_bytes("already-open.pdf", Some(path.into()), PDF.to_vec()).unwrap();
    h.state_mut().set_option("home", "true").unwrap();
    h.run_steps(4);
    h.get_by_role_and_label(egui::accesskit::Role::Button, "already-open.pdf").click();
    h.run_steps(4);
    assert_eq!(h.state().views.len(), 1);
    assert_eq!(h.state().active, Some(0));
    h.state_mut().recent.push(RecentFile { name: "missing.pdf".into(), path: "/odibo-synthetic/absent.pdf".into(), pages: 1, size: 0 });
    h.state_mut().set_option("home", "true").unwrap();
    h.run_steps(4);
    h.get_by_label("missing.pdf").click();
    super::support::wait_until(&mut h, "missing recent error", |app| app.toast.is_some());
    assert_eq!(h.state().views.len(), 1);
    assert!(h.state().toast.is_some());
    assert!(!h.state().session.get(h.state().views[0].id).unwrap().dirty);
}

#[test]
fn home_cards_fit_minimum_window_in_both_languages_themes_and_scales() {
    for language in ["en", "ru"] {
        let lang = pdfcraft_ui_egui::i18n::Lang::from_code(language).unwrap();
        for theme in ["light", "dark"] {
            for scale in [1.0, 1.5, 2.0] {
                let mut h = harness(egui::vec2(820.0, 520.0), language, theme, scale);
                let labels = ["Open file", "Combine files", "Split", "Edit text & images", "Add comments", "Fill & Sign", "Organize pages"];
                for label in labels {
                    let label = pdfcraft_ui_egui::i18n::tr(lang, label);
                    let node = h.query_all_by_label(label).find(|n| n.rect().left() > 250.0).unwrap();
                    assert!(node.rect().right() <= 820.0, "{label} escaped the window");
                    assert!(node.rect().width() >= 140.0);
                }
                // Tab is handled by stock egui focus navigation; Enter activates the focused card.
                let node = h.query_all_by_label(pdfcraft_ui_egui::i18n::tr(lang, "Combine files")).find(|n| n.rect().left() > 250.0).unwrap();
                node.focus();
                h.run_steps(2);
                h.key_press(egui::Key::Enter);
                h.run_steps(3);
                assert!(h.state().combine_showing());
            }
        }
    }
}
