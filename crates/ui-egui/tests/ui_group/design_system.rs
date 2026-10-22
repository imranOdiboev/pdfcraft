//! Stage 3.2: exercise the real shell and its existing mode/command transitions.
use egui_kittest::Harness;
use egui_kittest::kittest::{NodeT, Queryable};
use pdfcraft_ui_egui::{Mode, PdfCraftApp, QuickTool};

#[test]
fn compact_toolbar_keeps_modes_and_palette_reachable() {
    for theme in ["light", "dark"] {
        for scale in [1.0, 1.5, 2.0] {
            let mut h = Harness::builder().with_size(egui::vec2(640.0, 800.0)).with_pixels_per_point(scale).build_eframe(move |_cc| {
                let mut app = PdfCraftApp::new();
                app.set_option("language", "en").unwrap();
                app.set_option("theme", theme).unwrap();
                app
            });
            h.run_steps(4);
            let save = h.get_by_label("Save");
            assert!(save.accesskit_node().is_disabled(), "no document must not enable Save");
            let save_rect = save.rect();
            let search = h.get_by_label("Find tools and commands").rect();
            let mode = h.get_by_label("All tools");
            assert!(mode.accesskit_node().is_selected() == Some(true));
            assert!(mode.rect().right() <= search.left(), "mode and search overlap");
            assert!(search.right() <= save_rect.left(), "search and Save overlap");
            assert!(save_rect.right() <= 640.0, "Save escaped the viewport");
            mode.click();
            h.run_steps(2);
            h.get_by_label("Edit").click();
            h.run_steps(3);
            assert_eq!(h.state().mode, Mode::Edit);
            assert_eq!(h.state().quick_tool, QuickTool::EditText);
            assert!(h.get_by_label("Edit").accesskit_node().is_selected() == Some(true));
            h.get_by_label("Find tools and commands").click();
            h.run_steps(2);
            assert!(h.state().palette_open);
            h.key_press(egui::Key::Escape);
            h.run_steps(2);
            assert!(!h.state().palette_open);
        }
    }
}

#[test]
fn rendering_the_toolbar_preserves_saved_preferences_and_docking() {
    let mut app = PdfCraftApp::new();
    app.set_option("language", "ru").unwrap();
    app.set_option("theme", "dark").unwrap();
    let before: serde_json::Value = serde_json::from_str(&app.persist()).unwrap();
    let mut h = Harness::builder().with_size(egui::vec2(960.0, 800.0)).build_eframe(move |_cc| app);
    h.run_steps(4);
    let after: serde_json::Value = serde_json::from_str(&h.state().persist()).unwrap();
    assert_eq!(before, after, "visual presentation must not rewrite saved preferences");
}
