//! Stage 3.2: exercise the real shell and its existing mode/command transitions.
use egui_kittest::Harness;
use egui_kittest::kittest::{NodeT, Queryable};
use pdfcraft_ui_egui::{Mode, PdfCraftApp, QuickTool};

#[test]
fn tool_selection_follows_the_existing_command_and_accessibility_state() {
    const PDF: &[u8] = b"%PDF-1.7\n1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 300 400] >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF";
    let mut h = Harness::builder().with_size(egui::vec2(1400.0, 900.0)).build_eframe(|_cc| {
        let mut app = PdfCraftApp::new();
        app.set_option("language", "en").unwrap();
        app.open_bytes("synthetic.pdf", None, PDF.to_vec()).unwrap();
        app
    });
    h.run_steps(4);
    h.get_by_label("Edit").click();
    h.run_steps(3);
    assert!(h.get_by_label("Edit text & images").accesskit_node().is_selected() == Some(true));
    h.get_by_role_and_label(egui::accesskit::Role::Button, "Text").click();
    h.run_steps(3);
    assert_eq!(h.state().quick_tool, QuickTool::AddText);
    assert!(h.get_by_role_and_label(egui::accesskit::Role::Button, "Text").accesskit_node().is_selected() == Some(true));
    assert!(h.get_by_label("Edit text & images").accesskit_node().is_selected() == Some(false));
    let doc = h.state().session.get(h.state().views[0].id).unwrap();
    assert!(!doc.dirty, "choosing a tool must not edit the document");
}

#[test]
fn compact_toolbar_keeps_modes_and_palette_reachable() {
    for language in ["en", "ru"] {
        let lang = pdfcraft_ui_egui::i18n::Lang::from_code(language).unwrap();
        let save_label = pdfcraft_ui_egui::i18n::fmt(pdfcraft_ui_egui::i18n::tr(lang, "Save ({key})"), &[("key", "Ctrl+S")]);
        let all_label = pdfcraft_ui_egui::i18n::tr(lang, "All tools");
        let edit_label = pdfcraft_ui_egui::i18n::tr(lang, "Edit");
        let search_label = pdfcraft_ui_egui::i18n::tr(lang, "Find tools and commands");
        for theme in ["light", "dark"] {
            for scale in [1.0, 1.5, 2.0] {
                let mut h = Harness::builder().with_size(egui::vec2(640.0, 800.0)).with_pixels_per_point(scale).build_eframe(move |_cc| {
                    let mut app = PdfCraftApp::new();
                    app.set_option("language", language).unwrap();
                    app.set_option("theme", theme).unwrap();
                    app
                });
                h.ctx.set_os(egui::os::OperatingSystem::Nix);
                h.run_steps(4);
                let save = h.get_by_label(&save_label);
                assert!(save.accesskit_node().is_disabled(), "no document must not enable Save");
                let save_rect = save.rect();
                let search = h.get_by_label(search_label).rect();
                let mode = h.get_by_role_and_label(egui::accesskit::Role::Button, all_label);
                assert!(mode.accesskit_node().is_selected() == Some(true));
                assert!(mode.rect().right() <= search.left(), "mode and search overlap");
                assert!(search.right() <= save_rect.left(), "search and Save overlap");
                assert!(save_rect.right() <= 640.0, "Save escaped the viewport");
                mode.click();
                h.run_steps(2);
                h.get_by_label(edit_label).click();
                h.run_steps(3);
                assert_eq!(h.state().mode, Mode::Edit);
                assert_eq!(h.state().quick_tool, QuickTool::EditText);
                assert!(h.get_by_label(edit_label).accesskit_node().is_selected() == Some(true));
                h.get_by_label(search_label).click();
                h.run_steps(2);
                assert!(h.state().palette_open);
                h.key_press(egui::Key::Escape);
                h.run_steps(2);
                assert!(!h.state().palette_open);
            }
        }
    }
}
