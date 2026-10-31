//! Bounded, stateless Android worker using the existing PdfCraft object/edit core.
#![forbid(unsafe_code)]

use std::fs::{File, OpenOptions};
use std::io::{Read, Write};
use std::path::Path;
use std::sync::Arc;

use pdfcraft_cos::{Document, Object, SaveOptions};
use serde_json::{Value, json};

mod tools;
pub use tools::{combine_path, parse_indices, reorder_path, split_path};

pub const MAX_INPUT: usize = 16 * 1024 * 1024;
pub const MAX_OUTPUT: usize = 32 * 1024 * 1024;
const MAX_STREAM: usize = 8 * 1024 * 1024;
const MAX_DECODED_METADATA: usize = 32 * 1024 * 1024;
const MAX_OBJECTS: usize = 20_000;
const MAX_PAGES: usize = 2_000;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Failure(pub &'static str, pub &'static str);
pub type Result<T> = std::result::Result<T, Failure>;

impl Failure {
    pub fn json(self) -> Value {
        json!({"error": self.0, "message": self.1})
    }
}

const INVALID: Failure = Failure("invalid_pdf", "This PDF could not be safely processed.");
const LIMIT: Failure = Failure("limit_exceeded", "This document exceeds the Android safety limits.");
const SECURITY: Failure = Failure("unsupported_security", "Encrypted PDFs are not supported in Android.");
const SIGNED: Failure = Failure("unsupported_signed", "Signed PDFs are not editable in Android.");
const REPAIRED: Failure = Failure("unsupported_repaired", "This PDF needs repair and cannot be edited in Android.");

pub fn read_input(path: &Path) -> Result<Vec<u8>> {
    let file = File::open(path).map_err(|_| Failure("read_failed", "The selected PDF could not be read."))?;
    if file.metadata().map_err(|_| INVALID)?.len() > MAX_INPUT as u64 {
        return Err(LIMIT);
    }
    let mut bytes = Vec::new();
    file.take(MAX_INPUT as u64 + 1).read_to_end(&mut bytes).map_err(|_| Failure("read_failed", "The selected PDF could not be read."))?;
    if bytes.len() > MAX_INPUT {
        return Err(LIMIT);
    }
    Ok(bytes)
}

fn inspect_nested(value: &Object, budget: &mut usize, depth: usize) -> Result<()> {
    if depth > 32 || *budget == 0 {
        return Err(LIMIT);
    }
    *budget -= 1;
    let dict = match value {
        Object::Dict(d) => Some(d),
        Object::Stream(s) => Some(&s.dict),
        _ => None,
    };
    if let Some(dict) = dict {
        if dict.name(b"Type") == Some(b"Sig") || dict.get(b"ByteRange").is_some() || dict.name(b"FT") == Some(b"Sig") {
            return Err(SIGNED);
        }
        for (_, child) in dict.iter() {
            inspect_nested(child, budget, depth + 1)?;
        }
    } else if let Object::Array(items) = value {
        for item in items {
            inspect_nested(item, budget, depth + 1)?;
        }
    }
    Ok(())
}

/// A stream-limited document is used only for preflight and is never saved.
/// Validate every live object and bound decoded metadata before normal opening.
#[derive(Default)]
struct Budget {
    objects: usize,
    decoded: usize,
    nodes: usize,
}

fn preflight(bytes: Arc<Vec<u8>>, editing: bool) -> Result<Document> {
    preflight_budget(bytes, editing, &mut Budget { nodes: 100_000, ..Budget::default() })
}

fn preflight_budget(bytes: Arc<Vec<u8>>, editing: bool, budget: &mut Budget) -> Result<Document> {
    if bytes.is_empty() || bytes.len() > MAX_OUTPUT {
        return Err(LIMIT);
    }
    let limited = Document::open_with_stream_limit(bytes.clone(), None, MAX_STREAM).map_err(|error| match error {
        pdfcraft_cos::CosError::NeedsPassword | pdfcraft_cos::CosError::WrongPassword | pdfcraft_cos::CosError::Security(_) => SECURITY,
        _ => INVALID,
    })?;
    if limited.security().is_some() || limited.trailer().get(b"Encrypt").is_some() {
        return Err(SECURITY);
    }
    if limited.reconstructed() {
        return Err(REPAIRED);
    }
    for (_, object) in limited.scan_objects_checked() {
        budget.objects = budget.objects.checked_add(1).ok_or(LIMIT)?;
        if budget.objects > MAX_OBJECTS {
            return Err(LIMIT);
        }
        let object = object.map_err(|_| INVALID)?;
        // Viewing stays available for signed documents; all editing is refused.
        if editing {
            inspect_nested(&object, &mut budget.nodes, 0)?;
        }
        if let Object::Stream(stream) = object.as_ref() {
            let metadata = matches!(stream.dict.name(b"Type"), Some(b"ObjStm" | b"XRef"))
                || stream.dict.get(b"N").is_some()
                || stream.dict.get(b"First").is_some()
                || stream.dict.get(b"W").is_some();
            if metadata {
                let data = stream.decoded_within(MAX_STREAM).map_err(|_| LIMIT)?;
                budget.decoded = budget.decoded.checked_add(data.len()).ok_or(LIMIT)?;
                if budget.decoded > MAX_DECODED_METADATA {
                    return Err(LIMIT);
                }
            }
        }
    }
    let count = pdfcraft_organize::page_count(&limited).map_err(|_| INVALID)?;
    if count == 0 || count > MAX_PAGES {
        return Err(LIMIT);
    }
    // This open uses exactly the immutable, metadata-preflighted source bytes.
    // Writers intentionally reject the stream-limited read-only document above.
    Document::open(bytes).map_err(|_| INVALID)
}

fn information(document: &Document) -> Result<Value> {
    let count = pdfcraft_organize::page_count(document).map_err(|_| INVALID)?;
    if count == 0 || count > MAX_PAGES {
        return Err(LIMIT);
    }
    let rotations = (0..count).map(|page| pdfcraft_organize::page_rotation(document, page).map_err(|_| INVALID)).collect::<Result<Vec<_>>>()?;
    Ok(json!({"pageCount": count, "rotations": rotations}))
}

pub fn inspect_bytes(bytes: Vec<u8>) -> Result<Value> {
    if bytes.len() > MAX_INPUT {
        return Err(LIMIT);
    }
    information(&preflight(Arc::new(bytes), false)?)
}

pub fn rotate_bytes(bytes: Vec<u8>, page: usize) -> Result<(Vec<u8>, Value)> {
    if bytes.len() > MAX_INPUT {
        return Err(LIMIT);
    }
    let source = Arc::new(bytes);
    let original = preflight(source.clone(), true)?;
    let count = pdfcraft_organize::page_count(&original).map_err(|_| INVALID)?;
    if page >= count {
        return Err(Failure("invalid_page", "Choose an existing page."));
    }
    let previous = pdfcraft_organize::page_rotation(&original, page).map_err(|_| INVALID)?;
    let mut edited = original.clone();
    pdfcraft_organize::rotate_pages(&mut edited, &[page], 90).map_err(|_| INVALID)?;
    let output = pdfcraft_cos::write_incremental(&edited, &SaveOptions::default()).map_err(|_| INVALID)?;
    if output.len() > MAX_OUTPUT {
        return Err(LIMIT);
    }
    let reopened = preflight(Arc::new(output.clone()), true)?;
    if pdfcraft_organize::page_count(&reopened).map_err(|_| INVALID)? != count
        || pdfcraft_organize::page_rotation(&reopened, page).map_err(|_| INVALID)? != (previous + 90).rem_euclid(360)
    {
        return Err(Failure("verification_failed", "The edited PDF could not be verified."));
    }
    let mut info = information(&reopened)?;
    // `information` always constructs a JSON object; this key cannot index user data.
    info["saved"] = json!(true);
    Ok((output, info))
}

pub fn inspect_path(input: &Path) -> Result<Value> {
    inspect_bytes(read_input(input)?)
}

pub fn rotate_path(input: &Path, output: &Path, page: usize) -> Result<Value> {
    if input == output {
        return Err(Failure("destination_exists", "Choose a new output file."));
    }
    let (bytes, info) = rotate_bytes(read_input(input)?, page)?;
    // No existing file, directory or symlink may be replaced, including the source.
    let mut file = OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(output)
        .map_err(|_| Failure("destination_exists", "A new output file could not be created."))?;
    file.write_all(&bytes)
        .and_then(|_| file.sync_all())
        .map_err(|_| Failure("write_failed", "The output could not be saved. The original PDF is unchanged."))?;
    Ok(info)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fixture(extra: &str) -> Vec<u8> {
        let objects = [
            "<< /Type /Catalog /Pages 2 0 R >>".to_string(),
            "<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>".to_string(),
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 300] >>".to_string(),
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 300] >>".to_string(),
            extra.to_string(),
        ];
        let mut data = b"%PDF-1.4\n".to_vec();
        let mut offsets = vec![0];
        for (index, object) in objects.iter().enumerate() {
            offsets.push(data.len());
            data.extend_from_slice(format!("{} 0 obj\n{}\nendobj\n", index + 1, object).as_bytes());
        }
        let xref = data.len();
        data.extend_from_slice(format!("xref\n0 {}\n0000000000 65535 f \n", offsets.len()).as_bytes());
        for offset in offsets.iter().skip(1) {
            data.extend_from_slice(format!("{offset:010} 00000 n \n").as_bytes());
        }
        data.extend_from_slice(format!("trailer\n<< /Size {} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n", offsets.len()).as_bytes());
        data
    }

    #[test]
    fn actual_rotate_save_reopen_keeps_source_and_other_page() {
        let source = fixture("null");
        let before = source.clone();
        let (output, info) = rotate_bytes(source.clone(), 0).unwrap();
        assert_eq!(source, before);
        assert!(output.starts_with(&before));
        assert_eq!(info["pageCount"], 2);
        assert_eq!(info["rotations"], json!([90, 0]));
        assert_eq!(inspect_bytes(output).unwrap()["rotations"], json!([90, 0]));
    }

    #[test]
    fn malformed_and_missing_page_fail() {
        assert_eq!(inspect_bytes(b"not PDF".to_vec()).unwrap_err(), INVALID);
        assert_eq!(rotate_bytes(fixture("null"), 2).unwrap_err().0, "invalid_page");
    }

    #[test]
    fn signed_document_can_be_inspected_but_not_modified() {
        let bytes = fixture("<< /Type /Sig /ByteRange [0 10 20 30] >>");
        assert_eq!(inspect_bytes(bytes.clone()).unwrap()["pageCount"], 2);
        assert_eq!(rotate_bytes(bytes, 0).unwrap_err(), SIGNED);
    }

    #[test]
    fn oversized_input_is_rejected() {
        assert_eq!(inspect_bytes(vec![0; MAX_INPUT + 1]).unwrap_err(), LIMIT);
    }

    #[test]
    fn encrypted_empty_password_is_refused_without_bypassing_permissions() {
        let mut doc = Document::open(Arc::new(fixture("null"))).unwrap();
        doc.set_encryption(&pdfcraft_cos::NewEncryption {
            algorithm: pdfcraft_cos::Algorithm::Aes128,
            user_password: "",
            owner_password: "owner",
            permissions: -4,
            encrypt_metadata: true,
            seed: [9; 32],
        })
        .unwrap();
        let bytes = pdfcraft_cos::write_full(&doc, &SaveOptions::default()).unwrap();
        assert_eq!(rotate_bytes(bytes, 0).unwrap_err(), SECURITY);
    }

    #[test]
    fn compressed_metadata_is_bounded_before_editing_open() {
        let mut doc = Document::open(Arc::new(fixture("null"))).unwrap();
        let mut dict = pdfcraft_cos::Dict::new();
        dict.set(b"Type".to_vec(), Object::name("ObjStm"));
        dict.set(b"N".to_vec(), Object::Int(0));
        dict.set(b"First".to_vec(), Object::Int(0));
        let stream = doc.add(Object::Stream(pdfcraft_cos::Stream::flate(dict, &vec![b' '; MAX_STREAM + 1])));
        doc.update_dict(doc.root().unwrap(), |d| d.set(b"TestMetadata".to_vec(), Object::Ref(stream))).unwrap();
        let bytes = pdfcraft_cos::write_full(&doc, &SaveOptions { object_streams: false, ..SaveOptions::default() }).unwrap();
        assert!(bytes.len() < MAX_INPUT);
        assert_eq!(rotate_bytes(bytes, 0).unwrap_err(), LIMIT);
    }

    #[test]
    fn existing_destination_is_not_replaced() {
        let stamp = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos();
        let dir = std::env::temp_dir().join(format!("odibo-core-test-{}-{stamp}", std::process::id()));
        std::fs::create_dir(&dir).unwrap();
        let input = dir.join("source.pdf");
        let output = dir.join("existing.pdf");
        let bytes = fixture("null");
        std::fs::write(&input, &bytes).unwrap();
        std::fs::write(&output, b"keep me").unwrap();
        assert_eq!(rotate_path(&input, &output, 0).unwrap_err().0, "destination_exists");
        assert_eq!(std::fs::read(&output).unwrap(), b"keep me");
        assert_eq!(std::fs::read(&input).unwrap(), bytes);
        std::fs::remove_file(&input).unwrap();
        std::fs::remove_file(&output).unwrap();
        std::fs::remove_dir(&dir).unwrap();
    }
}
