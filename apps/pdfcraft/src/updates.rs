//! ODIBO PDF has no update service yet. Never contact upstream release endpoints.

use pdfcraft_ui_egui::updates::Release;

/// Keep the existing command callable while making its disabled state explicit.
/// There is deliberately no HTTP client, URL or certificate loading on this path.
pub fn latest_release() -> Result<Release, String> {
    Err(pdfcraft_ui_egui::updates::DISABLED_MESSAGE.into())
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_build_never_offers_an_upstream_update() {
        assert_eq!(super::latest_release(), Err(pdfcraft_ui_egui::updates::DISABLED_MESSAGE.into()));
    }
}
