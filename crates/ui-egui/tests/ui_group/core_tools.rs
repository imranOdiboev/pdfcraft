//! Actual egui controls at the supported minimum viewport; no raster mockups.
use egui::accesskit::Role;
use egui_kittest::Harness;
use egui_kittest::kittest::{NodeT, Queryable};
use pdfcraft_ui_egui::{Dialog, PdfCraftApp, SplitMode, i18n};

const PDF: &[u8] = b"%PDF-1.7\n1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n2 0 obj << /Type /Pages /Kids [3 0 R 4 0 R 5 0 R] /Count 3 >> endobj\n3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] >> endobj\n4 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] >> endobj\n5 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF";

#[test]
fn compact_combine_keeps_files_reachable_without_changing_saved_panels() {
    for language in ["en", "ru"] {
    for theme in ["light", "dark"] {
    for scale in [1.0, 1.5, 2.0] {
    let mut h = Harness::builder().with_size(egui::vec2(820.0, 520.0)).with_pixels_per_point(scale).build_eframe(move |_| {
        let mut app = PdfCraftApp::new();
        app.set_option("language", language).unwrap();
        app.set_option("theme", theme).unwrap();
        app.use_files(pdfcraft_ui_egui::FilePurpose::Combine, vec![("First.pdf".into(), PDF.to_vec()), ("Second.pdf".into(), PDF.to_vec())]);
        app
    });
    h.run_steps(5);
    let saved = serde_json::to_value(&h.state().docking).unwrap();
    let body: egui::Rect = h.ctx.data(|d| d.get_temp(egui::Id::new("odibo-editor-document-body"))).unwrap();
    assert!(body.width() > 760.0, "Combine must use the compact full-width projection");
    h.get_by_label("Second.pdf").scroll_to_me();
    h.run_steps(5);
    h.get_by_label("Second.pdf").click();
    h.run_steps(3);
    assert_eq!(h.state().combine_selection(), vec![1]);
    assert_eq!(serde_json::to_value(&h.state().docking).unwrap(), saved);
    }
    }
    }
}

#[test]
fn compact_organize_keyboard_move_and_undo_work_in_all_variants() {
    for language in ["en", "ru"] {
        let lang = i18n::Lang::from_code(language).unwrap();
        for theme in ["light", "dark"] {
            for scale in [1.0, 1.5, 2.0] {
                let mut h = Harness::builder().with_size(egui::vec2(820.0, 520.0)).with_pixels_per_point(scale).build_eframe(move |_| {
                    let mut app = PdfCraftApp::new();
                    app.set_option("language", language).unwrap();
                    app.set_option("theme", theme).unwrap();
                    app.open_bytes("source.pdf", None, PDF.to_vec()).unwrap();
                    app.set_option("organize", "on").unwrap();
                    app.views[0].select_pages(&[1]);
                    app
                });
                h.run_steps(5);
                h.get_by_role_and_label(Role::Button, i18n::tr(lang, "Tools")).click();
                h.run_steps(3);
                let label = i18n::tr(lang, "Move selected pages earlier");
                h.get_by_role_and_label(Role::Button, label).scroll_to_me();
                h.run_steps(4);
                h.get_by_role_and_label(Role::Button, label).focus();
                h.run_steps(1);
                h.key_press(egui::Key::Enter);
                h.run_steps(4);
                assert!(h.state().session.get(h.state().views[0].id).unwrap().dirty);
                h.state_mut().run_command("edit.undo");
                h.run_steps(3);
                assert_eq!(h.state().session.get(h.state().views[0].id).unwrap().bytes.as_slice(), PDF);
            }
        }
    }
}

#[test]
fn split_ranges_validate_and_cancel_with_keyboard_in_both_themes_and_languages() {
    for language in ["en", "ru"] {
        let lang = i18n::Lang::from_code(language).unwrap();
        for theme in ["light", "dark"] {
            for scale in [1.0, 1.5, 2.0] {
                let mut h = Harness::builder().with_size(egui::vec2(820.0, 520.0)).with_pixels_per_point(scale).build_eframe(move |_| {
                    let mut app = PdfCraftApp::new();
                    app.set_option("language", language).unwrap();
                    app.set_option("theme", theme).unwrap();
                    app.open_bytes("source.pdf", None, PDF.to_vec()).unwrap();
                    app.split_draft.mode = SplitMode::Ranges;
                    app.split_draft.ranges = "1-2, 2-3".into();
                    app.run_command("page.split");
                    app
                });
                h.run_steps(5);
                let split = h.get_by_role_and_label(Role::Button, i18n::tr(lang, "Split"));
                assert!(split.accesskit_node().is_disabled());
                assert!(egui::Rect::from_min_size(egui::Pos2::ZERO, egui::vec2(820.0, 520.0)).contains_rect(split.rect()));
                h.state_mut().split_draft.ranges = "1-2,3".into();
                h.run_steps(3);
                assert!(!h.get_by_role_and_label(Role::Button, i18n::tr(lang, "Split")).accesskit_node().is_disabled());
                h.get_by_role_and_label(Role::Button, i18n::tr(lang, "Cancel")).focus();
                h.run_steps(1);
                h.key_press(egui::Key::Enter);
                h.run_steps(3);
                assert_ne!(h.state().dialog, Some(Dialog::Split));
                assert_eq!(h.state().session.get(h.state().views[0].id).unwrap().bytes.as_slice(), PDF);
            }
        }
    }
}
