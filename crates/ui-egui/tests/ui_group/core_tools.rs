//! Actual egui controls at the supported minimum viewport; no raster mockups.
use egui::accesskit::Role;
use egui_kittest::Harness;
use egui_kittest::kittest::{NodeT, Queryable};
use pdfcraft_ui_egui::{Dialog, PdfCraftApp, SplitMode, i18n};

const PDF: &[u8] = b"%PDF-1.7\n1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n2 0 obj << /Type /Pages /Kids [3 0 R 4 0 R 5 0 R] /Count 3 >> endobj\n3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] >> endobj\n4 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] >> endobj\n5 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF";

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
