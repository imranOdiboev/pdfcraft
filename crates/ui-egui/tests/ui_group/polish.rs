//! Stage 3.6: real egui regressions, not a mock layout.
use egui::accesskit::Role;
use egui_kittest::{Harness, kittest::{Queryable, NodeT}};
use pdfcraft_ui_egui::{PdfCraftApp, SplitMode, i18n};

#[test]
fn polish_palette_last_keyboard_result_stays_inside_compact_viewport() {
    for language in ["en", "ru"] { for theme in ["light", "dark"] { for scale in [1.0, 1.5, 2.0] {
        let mut h = Harness::builder().with_size(egui::vec2(820.0,520.0)).with_pixels_per_point(scale).build_eframe(move |_| {
            let mut app=PdfCraftApp::new(); app.set_option("language",language).unwrap(); app.set_option("theme",theme).unwrap(); app.palette_open=true; app
        });
        h.run_steps(5);
        for _ in 0..11 { h.key_press(egui::Key::ArrowDown); h.run_steps(2); }
        h.run_steps(20);
        let rect:egui::Rect=h.ctx.data(|d| d.get_temp(egui::Id::new("palette-selected-rect"))).unwrap();
        assert!(rect.top()>=0.0 && rect.bottom()<=520.0,"selected result must be visible: {rect:?}");
        h.state_mut().palette_query="e".into(); h.run_steps(20);
        let rect:egui::Rect=h.ctx.data(|d| d.get_temp(egui::Id::new("palette-selected-rect"))).unwrap();
        assert!(rect.top()>=96.0 && rect.bottom()<=520.0,"new query must reveal first selected result: {rect:?}");
        h.key_press(egui::Key::Escape); h.run_steps(2); assert!(!h.state().palette_open);
    }}}
}

#[test]
fn polish_split_invalid_input_has_no_fabricated_preview_and_single_output_explains_why() {
    for language in ["en","ru"] { for theme in ["light","dark"] {
        let lang=i18n::Lang::from_code(language).unwrap();
        let mut h=Harness::builder().with_size(egui::vec2(820.0,520.0)).build_eframe(move |_| {
            let mut app=PdfCraftApp::new(); app.set_option("language",language).unwrap(); app.set_option("theme",theme).unwrap();
            app.open_bytes("source.pdf",None,b"%PDF-1.7\n1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF".to_vec()).unwrap();
            app.split_draft.mode=SplitMode::Ranges; app.split_draft.ranges=String::new(); app.run_command("page.split"); app
        });
        h.run_steps(5);
        let invalid=i18n::tr(lang,"Enter consecutive ranges covering every page, for example 1-3, 4-6.");
        assert!(h.query_by_label(invalid).is_some());
        assert!(h.query_by_label("1. 1–1").is_none());
        assert!(h.get_by_role_and_label(Role::Button,i18n::tr(lang,"Split")).accesskit_node().is_disabled());
        h.state_mut().split_draft.mode=SplitMode::Pages; h.state_mut().split_draft.every=1; h.run_steps(4);
        assert!(h.query_by_label(i18n::tr(lang,"Choose settings that create at least two files.")).is_some());
    }}
}

#[test]
fn polish_failure_survives_success_and_time_until_explicit_dismissal() {
    let mut h=Harness::builder().with_size(egui::vec2(820.0,520.0)).build_eframe(|_| {
        let mut app=PdfCraftApp::new(); app.set_option("language","en").unwrap(); app.operation_error=Some("Output not written. Original unchanged. ".repeat(120)); app
    });
    h.run_steps(5); h.state_mut().notify("Saved another document");
    h.input_mut().time=Some(h.ctx.input(|i| i.time)+10.0); h.run_steps(2);
    assert!(h.state().operation_error.is_some());
    let dismiss=h.get_by_role_and_label(Role::Button,"Dismiss").rect(); assert!(dismiss.top()>=0.0 && dismiss.bottom()<=520.0);
    h.get_by_role_and_label(Role::Button,"Dismiss").focus(); h.run_steps(2); h.key_press(egui::Key::Enter); h.run_steps(3);
    assert!(h.state().operation_error.is_none());
}
