//! Navigation is a view of the current document, not a second document or settings model.
use crate::{PdfCraftApp, RightPanel, icons, panels, theme, widgets};

#[derive(Clone)]
struct Navigation {
    panel: RightPanel,
    expanded: bool,
    drawer: bool,
}

impl Default for Navigation {
    fn default() -> Self {
        Self { panel: RightPanel::Pages, expanded: true, drawer: false }
    }
}

pub(crate) fn close_drawer(ctx: &egui::Context) {
    let id = egui::Id::new("odibo-editor-navigation");
    ctx.data_mut(|data| {
        if let Some(mut state) = data.get_temp::<Navigation>(id) {
            state.drawer = false;
            data.insert_temp(id, state);
        }
    });
}

pub fn show(app: &mut PdfCraftApp, ui: &mut egui::Ui) {
    if app.active.is_none() {
        return;
    }
    let id = egui::Id::new("odibo-editor-navigation");
    let mut state = ui.data(|data| data.get_temp::<Navigation>(id)).unwrap_or_default();
    // Preserve legacy/API requests for Pages/Bookmarks in their saved Inspector location.
    // The left controls can explicitly move back to the new navigation view.
    let legacy = matches!(app.right, Some(RightPanel::Pages | RightPanel::Bookmarks));
    let compact = ui.available_width() < 1100.0;
    let close_label = format!("{}: {}", crate::i18n::t("Page navigation"), crate::i18n::t("Close"));
    let t = theme::Tokens::get(ui.ctx());
    let body = !compact && state.expanded && !legacy;
    egui::Panel::left(if body { "odibo-navigation-pane" } else { "odibo-navigation-rail" })
        .resizable(body)
        .default_size(if body { 220.0 } else { 48.0 })
        .size_range(if body { 180.0..=280.0 } else { 48.0..=48.0 })
        .frame(egui::Frame::NONE.fill(t.panel))
        .show(ui, |ui| {
            ui.horizontal_wrapped(|ui| {
                for (panel, icon, label) in [(RightPanel::Pages, "files", "Pages"), (RightPanel::Bookmarks, "bookmark", "Bookmarks")] {
                    let selected = state.panel == panel && if compact { state.drawer } else { body };
                    let name = format!("{}: {}", crate::i18n::t("Page navigation"), crate::i18n::t(label));
                    let response =
                        if body { widgets::mode_tab(ui, crate::i18n::t(label), selected) } else { icons::button(ui, icon, 36.0, selected, &name) };
                    response.widget_info(|| egui::WidgetInfo::selected(egui::WidgetType::Button, true, selected, &name));
                    widgets::focus_ring(ui, &response);
                    if response.clicked() {
                        if legacy {
                            let closed = app.right_panel_closed;
                            app.choose_right_panel(None);
                            // Moving navigation is not a request to suppress future inspectors.
                            app.right_panel_closed = closed;
                        }
                        state.expanded = true;
                        state.drawer = !selected;
                        state.panel = panel;
                        if compact && state.drawer {
                            ui.data_mut(|data| data.remove::<crate::docking::Panel>(egui::Id::new("odibo-editor-context-drawer")));
                        }
                    }
                }
            });
            if body {
                ui.data_mut(|data| data.insert_temp(id.with("body"), ui.max_rect()));
            }
            if body && panels::panel_body(app, ui, state.panel, &close_label) {
                state.expanded = false;
            }
        });
    if compact && state.drawer {
        let ctx = ui.ctx().clone();
        let mut open = true;
        let height = (ctx.content_rect().height() - 140.0).max(120.0);
        egui::Window::new(crate::i18n::t("Page navigation"))
            .id(id.with("drawer"))
            .open(&mut open)
            .anchor(egui::Align2::LEFT_TOP, egui::vec2(52.0, 94.0))
            .fixed_size(egui::vec2(240.0, height))
            .collapsible(false)
            .show(&ctx, |ui| {
                if panels::panel_body(app, ui, state.panel, &close_label) {
                    state.drawer = false;
                }
            });
        if !open {
            state.drawer = false;
        }
    }
    ui.data_mut(|data| data.insert_temp(id, state));
}
