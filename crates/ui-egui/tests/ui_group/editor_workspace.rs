//! Editor navigation/layout uses real commands and keeps saved docking authoritative.
use egui_kittest::Harness;
use egui_kittest::kittest::Queryable;
use pdfcraft_ui_egui::{PdfCraftApp, RightPanel};

const PDF: &[u8] = b"%PDF-1.7\n1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n2 0 obj << /Type /Pages /Kids [3 0 R 4 0 R 5 0 R] /Count 3 >> endobj\n3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] >> endobj\n4 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] >> endobj\n5 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF";

fn harness(size: egui::Vec2, language: &'static str, theme: &'static str, scale: f32, saved: Option<String>) -> Harness<'static, PdfCraftApp> {
    let mut h = Harness::builder().with_size(size).with_pixels_per_point(scale).build_eframe(move |_cc| {
        let mut app = PdfCraftApp::new();
        if let Some(saved) = saved {
            app.restore(&saved);
        }
        app.set_option("language", language).unwrap();
        app.set_option("theme", theme).unwrap();
        app.open_bytes("navigation.pdf", None, PDF.to_vec()).unwrap();
        app
    });
    h.run_steps(5);
    h
}

fn document(h: &Harness<'static, PdfCraftApp>) -> egui::Rect {
    h.ctx.data(|d| d.get_temp(egui::Id::new("odibo-editor-document-body"))).unwrap()
}

#[test]
fn fresh_editor_places_navigation_left_and_tools_right() {
    let h = harness(egui::vec2(1440.0, 900.0), "en", "light", 1.0, None);
    let nav = h.get_by_label("Page navigation: Pages").rect();
    let canvas = document(&h);
    let tools = h.get_by_role_and_label(egui::accesskit::Role::Tab, "Tools").rect();
    assert!(nav.right() < canvas.left());
    assert!(tools.left() >= canvas.right());
    assert!(canvas.width() >= 500.0);
    assert!(h.state().docking.tools_on_right());
}

#[test]
fn left_thumbnails_navigate_by_pointer_and_keyboard_without_editing() {
    let mut h = harness(egui::vec2(1440.0, 900.0), "en", "dark", 1.0, None);
    h.get_by_role_and_label(egui::accesskit::Role::Button, "Page 2").click();
    h.run_steps(3);
    assert_eq!(h.state().views[0].current, 1);
    h.get_by_role_and_label(egui::accesskit::Role::Button, "Page 3").focus();
    h.run_steps(2);
    h.key_press(egui::Key::Enter);
    h.run_steps(3);
    assert_eq!(h.state().views[0].current, 2);
    let doc = h.state().session.get(h.state().views[0].id).unwrap();
    assert!(!doc.dirty);
    assert_eq!(doc.bytes.as_slice(), PDF);
    h.get_by_label("Page navigation: Bookmarks").click();
    h.run_steps(3);
    h.get_by_label("This document has no bookmarks.");
}

#[test]
fn contextual_tools_and_inspector_reuse_existing_commands() {
    let mut h = harness(egui::vec2(1440.0, 900.0), "en", "light", 1.0, None);
    h.state_mut().run_command("comment.note");
    h.run_steps(3);
    assert_eq!(h.state().right, Some(RightPanel::Comments));
    assert!(matches!(h.state().quick_tool, pdfcraft_ui_egui::QuickTool::Comment(_)));
    h.get_by_role_and_label(egui::accesskit::Role::Tab, "Tools").click();
    h.run_steps(3);
    h.get_by_label("Edit").click();
    h.run_steps(3);
    assert_eq!(h.state().quick_tool, pdfcraft_ui_egui::QuickTool::EditText);
    assert_eq!(h.state().right, Some(RightPanel::Comments));
    assert!(!h.state().session.get(h.state().views[0].id).unwrap().dirty);
}

#[test]
fn restored_panel_layout_survives_compact_projection_and_restart() {
    let mut app = PdfCraftApp::new();
    // Simulate an existing stage 3.3 settings file, which has no new pending-default key.
    let mut saved: serde_json::Value = serde_json::from_str(&app.persist()).unwrap();
    saved.as_object_mut().unwrap().remove("editor_workspace_pending");
    app.restore(&saved.to_string());
    app.choose_right_panel(Some(RightPanel::Comments));
    let saved = app.persist();
    let mut h = harness(egui::vec2(820.0, 520.0), "en", "light", 1.0, Some(saved));
    let before = serde_json::to_value(&h.state().docking).unwrap();
    assert!(!h.state().docking.tools_on_right());
    assert!(document(&h).width() >= 600.0);
    h.get_by_role_and_label(egui::accesskit::Role::Button, "Tools").click();
    h.run_steps(3);
    h.get_by_label("Edit a PDF");
    assert_eq!(serde_json::to_value(&h.state().docking).unwrap(), before);
    h.get_by_label("Page navigation: Pages").click();
    h.run_steps(3);
    assert!(h.query_by_label("Edit a PDF").is_none(), "only one temporary drawer should cover the document");
    assert_eq!(serde_json::to_value(&h.state().docking).unwrap(), before);
    let saved = h.state().persist();
    let restored = harness(egui::vec2(1440.0, 900.0), "en", "light", 1.0, Some(saved));
    assert_eq!(serde_json::to_value(&restored.state().docking).unwrap(), before);
}

#[test]
fn compact_editor_preserves_document_width_and_exposes_navigation_in_all_variants() {
    for language in ["en", "ru"] {
        let lang = pdfcraft_ui_egui::i18n::Lang::from_code(language).unwrap();
        let label = format!("{}: {}", pdfcraft_ui_egui::i18n::tr(lang, "Page navigation"), pdfcraft_ui_egui::i18n::tr(lang, "Pages"));
        for theme in ["light", "dark"] {
            for scale in [1.0, 1.5, 2.0] {
                let mut h = harness(egui::vec2(820.0, 520.0), language, theme, scale, None);
                assert!(document(&h).width() >= 600.0);
                h.get_by_label(&label).focus();
                h.run_steps(2);
                h.key_press(egui::Key::Enter);
                h.run_steps(3);
                let page = pdfcraft_ui_egui::i18n::fmt(pdfcraft_ui_egui::i18n::tr(lang, "Page {label}"), &[("label", "2")]);
                h.get_by_role_and_label(egui::accesskit::Role::Button, &page).click();
                h.run_steps(3);
                assert_eq!(h.state().views[0].current, 1);
                assert!(document(&h).width() >= 600.0, "temporary drawer must not shrink the document");
            }
        }
    }
}
