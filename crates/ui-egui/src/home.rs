//! Home tab: real quick actions, recent files and pinned folders (local only, never
//! another app's list).

use egui::{Align2, CornerRadius, Rect, Sense, Stroke, vec2};

use crate::theme::{self, Tokens};
use crate::{PdfCraftApp, icons, panels::human_size, widgets};

/// Only existing catalogue commands: document actions use the same asynchronous
/// open-then-run path as the tool panel, including cancellation and permission checks.
const ACTIONS: [(&str, &str, &str); 7] = [
    ("file.open", "Open file", "folder-open"),
    ("page.combine", "Combine files", "files"),
    ("page.split", "Split", "scissors"),
    ("edit.edit_text", "Edit text & images", "text-cursor-input"),
    ("comment.note", "Add comments", "message-square"),
    ("sign.fill.signature", "Fill & Sign", "signature"),
    ("page.organize", "Organize pages", "layout-grid"),
];

fn action_card(ui: &mut egui::Ui, t: &Tokens, width: f32, command: &str, label: &str, icon: &str) -> egui::Response {
    let (rect, response) = ui.allocate_exact_size(vec2(width, 104.0), Sense::click());
    let label = tl!(label);
    response.widget_info(|| egui::WidgetInfo::labeled(egui::WidgetType::Button, true, label));
    let press = theme::Press::track(ui, &response);
    card_lift(ui, t, rect, press);
    let primary = command == "file.open";
    ui.painter().rect(
        rect,
        CornerRadius::same(10),
        press.fill(t.card, t.hover, t.pressed),
        Stroke::new(if primary { 2.0 } else { 1.0 }, if primary { t.accent_text } else { t.border }),
        egui::StrokeKind::Inside,
    );
    let body = rect.translate(press.offset());
    icons::paint(ui, Rect::from_min_size(body.min + vec2(14.0, 14.0), vec2(24.0, 24.0)), icon, 22.0, t.accent_text);
    let mut job = egui::text::LayoutJob::simple(label.to_owned(), theme::semibold(theme::TOOL_LABEL), t.text, body.width() - 28.0);
    job.wrap.max_rows = 2;
    let galley = ui.fonts_mut(|f| f.layout_job(job));
    ui.painter().galley(body.min + vec2(14.0, 48.0), galley, t.text);
    widgets::focus_ring(ui, &response);
    theme::hand(response).on_hover_text(label)
}

fn quick_actions(app: &mut PdfCraftApp, ui: &mut egui::Ui, t: &Tokens) {
    ui.label(egui::RichText::new(tl!("Recommended tools")).font(theme::semibold(17.0)));
    ui.add_space(12.0);
    let gap = 12.0;
    let columns = (((ui.available_width() + gap) / 202.0).floor() as usize).clamp(1, 4);
    let width = ((ui.available_width() - gap * columns.saturating_sub(1) as f32) / columns as f32).max(1.0);
    for row in ACTIONS.chunks(columns) {
        ui.horizontal(|ui| {
            ui.spacing_mut().item_spacing.x = gap;
            for &(command, label, icon) in row {
                // Commands are dispatched after painting through the existing guarded path.
                if action_card(ui, t, width, command, label, icon).clicked() {
                    app.run_command(command);
                }
            }
        });
        ui.add_space(gap);
    }
}

/// A soft shadow that rises on hover and settles when the card is pressed.
fn card_lift(ui: &egui::Ui, t: &Tokens, rect: Rect, press: theme::Press) {
    let lift = press.hover * (1.0 - press.down);
    if lift > 0.04 {
        let shadow = egui::Shadow { offset: [0, 3], blur: (14.0 * lift) as u8, spread: 0, color: t.page_shadow.gamma_multiply(0.85 * lift) };
        ui.painter().add(shadow.as_shape(rect, CornerRadius::same(10)));
    }
}

pub fn show(app: &mut PdfCraftApp, ui: &mut egui::Ui) {
    let t = Tokens::get(ui.ctx());
    egui::ScrollArea::vertical().auto_shrink([false, false]).show(ui, |ui| {
        egui::Frame::NONE.inner_margin(egui::Margin { left: 24, right: 24, top: 20, bottom: 24 }).show(ui, |ui| {
            #[cfg(not(feature = "unbranded"))]
            widgets::odibo_logo(ui, 96.0);
            ui.label(egui::RichText::new(tl!("Welcome to ODIBO PDF")).font(theme::semibold(24.0)));
            ui.label(
                egui::RichText::new(tl!("An open-source PDF workbench — local, private, and scriptable."))
                    .color(t.text_muted)
                    .font(theme::regular(14.0)),
            );
            ui.add_space(20.0);
            quick_actions(app, ui, &t);
            ui.add_space(26.0);
            let mut clear = false;
            ui.horizontal(|ui| {
                ui.label(egui::RichText::new(tl!("Recent")).font(theme::semibold(17.0)));
                if !app.recent.is_empty() {
                    ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                        let resp = widgets::ghost_button(ui, "trash-2", tl!("Clear"));
                        resp.widget_info(|| egui::WidgetInfo::labeled(egui::WidgetType::Button, true, tl!("Clear Recent Files")));
                        clear = resp.on_hover_text(tl!("Clear Recent Files")).clicked();
                    });
                }
            });
            ui.add_space(8.0);
            if app.recent.is_empty() {
                ui.label(egui::RichText::new(tl!("Files you open in ODIBO PDF appear here. Drop a PDF anywhere to open it.")).color(t.text_muted));
            }
            let mut open = None;
            let mut remove = None;
            for r in &app.recent {
                let (rect, resp) = ui.allocate_exact_size(vec2(ui.available_width(), 46.0), Sense::click());
                resp.widget_info(|| egui::WidgetInfo::labeled(egui::WidgetType::Button, true, &r.name));
                let press = theme::Press::track(ui, &resp);
                // The row, not its response: the pointer stays "in" the row over its remove button.
                let hovered = ui.rect_contains_pointer(rect);
                if hovered && press.hover < 0.04 && press.down < 0.04 {
                    // The remove button sits in the row, so the row response may not be hovered.
                    ui.painter().rect_filled(rect, CornerRadius::same(8), t.hover);
                } else {
                    press.wash(ui, rect, 8, false);
                }
                if hovered || resp.has_focus() || ui.memory(|m| m.has_focus(ui.id().with(("remove-recent", &r.path)))) {
                    // Remove just this file from the list (#430); the file itself is untouched.
                    let x_rect = Rect::from_center_size(rect.right_center() - vec2(26.0, 0.0), vec2(28.0, 28.0));
                    let x = ui.interact(x_rect, ui.id().with(("remove-recent", &r.path)), Sense::click());
                    let label = crate::i18n::fmt(tl!("Remove {name} from Recent"), &[("name", &r.name)]);
                    x.widget_info(|| egui::WidgetInfo::labeled(egui::WidgetType::Button, true, &label));
                    if x.hovered() {
                        ui.painter().rect_filled(x_rect, CornerRadius::same(6), t.pressed);
                    }
                    icons::paint(ui, x_rect.shrink(6.0), "x", 16.0, t.icon);
                    widgets::focus_ring(ui, &x);
                    if x.on_hover_text(tl!("Remove from Recent")).clicked() {
                        remove = Some(r.path.clone());
                    }
                }
                let body = rect.translate(press.offset());
                icons::paint(
                    ui,
                    Rect::from_min_size(body.min + vec2(10.0, 11.0), vec2(24.0, 24.0)),
                    "file-text",
                    22.0,
                    egui::Color32::from_rgb(0xE0, 0x3E, 0x3E),
                );
                // Room on the right for the remove button.
                let detail = ui.painter().text(
                    body.right_center() - vec2(48.0, 0.0),
                    Align2::RIGHT_CENTER,
                    format!("{}  ·  {}", crate::i18n::trn(crate::i18n::current(), r.pages as u64, "{n} page", "{n} pages"), human_size(r.size)),
                    theme::regular(12.0),
                    t.text_muted,
                );
                // The name and path stop short of the page count; hovering shows the whole path.
                let width = detail.left() - 16.0 - (body.left() + 46.0);
                widgets::row_text(ui, body.min + vec2(46.0, 15.0), crate::bidi::visual(&r.name), theme::medium(13.5), t.text, width);
                widgets::row_text(
                    ui,
                    body.min + vec2(46.0, 32.0),
                    crate::bidi::visual(&r.path),
                    theme::regular(theme::SECONDARY),
                    t.text_muted,
                    width,
                );
                widgets::focus_ring(ui, &resp);
                if theme::hand(resp).on_hover_text(&r.path).clicked() {
                    open = Some(r.path.clone());
                }
            }
            if let Some(p) = open {
                app.open_recent(&p);
            }
            if let Some(p) = remove {
                app.recent.retain(|r| r.path != p);
            }
            if clear {
                app.execute("file.clear_recent");
            }
            #[cfg(not(target_arch = "wasm32"))]
            {
                ui.add_space(24.0);
                crate::folders_ui::section(app, ui);
            }
            ui.add_space(24.0);
            ui.label(egui::RichText::new(tl!("ODIBO PDF project")).font(theme::semibold(15.0)));
            if let Some(command) = widgets::community_links(ui) {
                app.execute(command);
            }
            ui.add_space(20.0);
            ui.label(egui::RichText::new(tl!("Privacy")).font(theme::semibold(theme::SECONDARY)).color(t.text_muted));
            ui.label(
                egui::RichText::new(tl!("ODIBO PDF works offline. No telemetry, no account, and no cloud processing unless you add a provider."))
                    .color(t.text_muted),
            );
        });
    });
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn home_actions_are_ready_catalogue_commands() {
        for (id, _, _) in ACTIONS {
            assert!(pdfcraft_engine::commands::command(id).is_some(), "missing command {id}");
            if id != "file.open" {
                assert!(
                    pdfcraft_engine::catalog::TOOL_GROUPS
                        .iter()
                        .flat_map(|g| g.sections.iter())
                        .flat_map(|s| s.items.iter())
                        .any(|item| item.command == id && item.availability == pdfcraft_engine::catalog::Availability::Ready)
                );
            }
        }
    }

    #[test]
    fn translated_cards_fit_two_rows_without_clipping() {
        for lang in crate::i18n::Lang::all() {
            crate::i18n::set_current(lang);
            let ctx = egui::Context::default();
            ctx.set_fonts(theme::font_definitions());
            let output = ctx.run_ui(egui::RawInput::default(), |ui| {
                let t = Tokens::get(ui.ctx());
                for &(command, label, icon) in &ACTIONS {
                    action_card(ui, &t, 190.0, command, label, icon);
                }
            });
            let fits = output
                .shapes
                .iter()
                .filter_map(|s| match &s.shape {
                    egui::Shape::Text(t) => Some(t),
                    _ => None,
                })
                .all(|t| !t.galley.elided && t.galley.rows.len() <= 2);
            output.drop_without_applying_deltas();
            assert!(fits, "card label clipped for {lang:?}");
        }
        crate::i18n::set_current(crate::i18n::Lang::EN);
    }
}
