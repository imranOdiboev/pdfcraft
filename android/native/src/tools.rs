//! Mobile operations delegate to the existing desktop organize implementation.
use super::*;
use std::hash::{Hash, Hasher};
use std::path::PathBuf;

const ARGUMENTS: Failure = Failure("invalid_arguments", "Choose valid page numbers in the required order.");
const VERIFY: Failure = Failure("verification_failed", "The resulting PDF could not be verified.");
const WRITE: Failure = Failure("write_failed", "The new copy could not be saved. Original PDFs are unchanged.");
const DESTINATION: Failure = Failure("destination_exists", "Choose a new output file or folder.");
pub const MAX_PARTS: usize = 32;

pub fn parse_indices(text: &str) -> Result<Vec<usize>> {
    if text.is_empty() || text.len() > MAX_PAGES * 12 {
        return Err(ARGUMENTS);
    }
    let values = text
        .split(',')
        .map(|part| {
            if part.is_empty() || !part.bytes().all(|byte| byte.is_ascii_digit()) {
                return Err(ARGUMENTS);
            }
            part.parse::<usize>().map_err(|_| ARGUMENTS)
        })
        .collect::<Result<Vec<_>>>()?;
    if values.len() > MAX_PAGES {
        return Err(ARGUMENTS);
    }
    Ok(values)
}

#[derive(PartialEq)]
struct PageIdentity {
    boxes: [[f64; 4]; 5],
    rotation: i64,
    content: u64,
}

fn open_for_tools(bytes: Vec<u8>, budget: &mut Budget) -> Result<Document> {
    let document = preflight_budget(Arc::new(bytes), true, budget)?;
    // Organize's import/prune pass can decode page/Form content. Bound those
    // streams first, so compact compression bombs never reach its default cap.
    for (_, object) in document.scan_objects_checked() {
        let object = object.map_err(|_| INVALID)?;
        if let Object::Stream(stream) = object.as_ref() {
            let metadata = matches!(stream.dict.name(b"Type"), Some(b"ObjStm" | b"XRef"))
                || stream.dict.get(b"N").is_some()
                || stream.dict.get(b"First").is_some()
                || stream.dict.get(b"W").is_some();
            if !metadata && stream.dict.name(b"Subtype") != Some(b"Image") {
                let decoded = stream.decoded_within(MAX_STREAM).map_err(|_| LIMIT)?;
                budget.decoded = budget.decoded.checked_add(decoded.len()).ok_or(LIMIT)?;
                if budget.decoded > MAX_DECODED_METADATA {
                    return Err(LIMIT);
                }
            }
        }
    }
    Ok(document)
}

fn identities(doc: &Document) -> Result<Vec<PageIdentity>> {
    let boxes = pdfcraft_organize::page_boxes(doc).map_err(|_| INVALID)?;
    let pages = pdfcraft_organize::pages(doc).map_err(|_| INVALID)?;
    pages
        .iter()
        .enumerate()
        .map(|(index, page)| {
            let page = doc.get(page.obj);
            let dictionary = page.as_dict().ok_or(INVALID)?;
            let mut hash = std::collections::hash_map::DefaultHasher::new();
            if let Some(contents) = dictionary.get(b"Contents") {
                let resolved = doc.resolve(contents);
                let objects = match resolved.as_ref() {
                    Object::Array(items) => items.clone(),
                    _ => vec![contents.clone()],
                };
                if objects.len() > MAX_OBJECTS {
                    return Err(LIMIT);
                }
                for object in objects {
                    let resolved = doc.resolve(&object);
                    if let Object::Stream(stream) = resolved.as_ref() {
                        // Import/full and incremental saves preserve encoded content bytes.
                        // This is a structural verification fingerprint, not a signature.
                        stream.raw.hash(&mut hash);
                    } else {
                        return Err(INVALID);
                    }
                }
            }
            Ok(PageIdentity {
                boxes: *boxes.get(index).ok_or(INVALID)?,
                rotation: pdfcraft_organize::page_rotation(doc, index).map_err(|_| INVALID)?,
                content: hash.finish(),
            })
        })
        .collect()
}

fn encode_verified(document: &Document, expected: &[PageIdentity], incremental: bool) -> Result<(Vec<u8>, Value)> {
    let options = SaveOptions::default();
    let bytes = if incremental { pdfcraft_cos::write_incremental(document, &options) } else { pdfcraft_cos::write_full(document, &options) }
        .map_err(|_| INVALID)?;
    // Every generated part must also be reopenable by the unchanged 16MiB
    // inspect/import path. Split's aggregate allowance remains 32MiB.
    if bytes.len() > MAX_INPUT {
        return Err(LIMIT);
    }
    let reopened = preflight(Arc::new(bytes.clone()), true)?;
    if identities(&reopened)? != expected {
        return Err(VERIFY);
    }
    let mut info = information(&reopened)?;
    info["saved"] = json!(true);
    Ok((bytes, info))
}

// Only remove files created exclusively by this invocation, never existing paths.
fn write_new(output: &Path, bytes: &[u8]) -> Result<()> {
    let mut file = OpenOptions::new().write(true).create_new(true).open(output).map_err(|_| DESTINATION)?;
    let result = file.write_all(bytes).and_then(|_| file.sync_all());
    drop(file);
    if result.is_err() {
        let _ = std::fs::remove_file(output);
        return Err(WRITE);
    }
    Ok(())
}

pub fn combine_path(output: &Path, inputs: &[PathBuf]) -> Result<Value> {
    if !(2..=MAX_PARTS).contains(&inputs.len()) {
        return Err(ARGUMENTS);
    }
    // Reject oversized sets before opening/retaining any parsed documents.
    let mut declared_total = 0u64;
    for input in inputs {
        if input == output {
            return Err(DESTINATION);
        }
        let size = std::fs::metadata(input).map_err(|_| Failure("read_failed", "The selected PDF could not be read."))?.len();
        declared_total = declared_total.checked_add(size).ok_or(LIMIT)?;
        if declared_total > MAX_INPUT as u64 {
            return Err(LIMIT);
        }
    }
    // Recheck actual byte counts as files may change between metadata and read.
    let mut total = 0usize;
    let mut budget = Budget { nodes: 100_000, ..Budget::default() };
    let mut expected = Vec::new();
    let mut combiner = pdfcraft_organize::Combiner::new();
    for input in inputs {
        if input == output {
            return Err(DESTINATION);
        }
        let bytes = read_input(input)?;
        total = total.checked_add(bytes.len()).ok_or(LIMIT)?;
        if total > MAX_INPUT {
            return Err(LIMIT);
        }
        let document = open_for_tools(bytes, &mut budget)?;
        expected.extend(identities(&document)?);
        if expected.len() > MAX_PAGES {
            return Err(LIMIT);
        }
        combiner.add("Document", &document, None).map_err(|_| INVALID)?;
    }
    let document = combiner.finish().map_err(|_| INVALID)?;
    let (bytes, info) = encode_verified(&document, &expected, false)?;
    write_new(output, &bytes)?;
    Ok(info)
}

pub fn reorder_path(input: &Path, output: &Path, order: &[usize]) -> Result<Value> {
    if input == output {
        return Err(DESTINATION);
    }
    let mut document = open_for_tools(read_input(input)?, &mut Budget { nodes: 100_000, ..Budget::default() })?;
    let original = identities(&document)?;
    if order.len() != original.len() {
        return Err(ARGUMENTS);
    }
    let mut seen = std::collections::HashSet::new();
    for page in order {
        if *page >= original.len() || !seen.insert(*page) {
            return Err(ARGUMENTS);
        }
    }
    let expected = order.iter().map(|page| original.get(*page).ok_or(ARGUMENTS)).collect::<Result<Vec<_>>>()?;
    let mut positions = (0..original.len()).collect::<Vec<_>>();
    for (target, wanted) in order.iter().enumerate() {
        let current = positions.iter().position(|page| page == wanted).ok_or(ARGUMENTS)?;
        if current != target {
            pdfcraft_organize::move_pages(&mut document, &[current], target).map_err(|_| INVALID)?;
            // `current` comes from position(), target from this same length's enumerate.
            let moved = positions.remove(current);
            positions.insert(target, moved);
        }
    }
    let expected =
        expected.into_iter().map(|page| PageIdentity { boxes: page.boxes, rotation: page.rotation, content: page.content }).collect::<Vec<_>>();
    let (bytes, info) = encode_verified(&document, &expected, true)?;
    write_new(output, &bytes)?;
    Ok(info)
}

pub fn split_path(input: &Path, directory: &Path, cuts: &[usize]) -> Result<Value> {
    let document = open_for_tools(read_input(input)?, &mut Budget { nodes: 100_000, ..Budget::default() })?;
    let expected = identities(&document)?;
    if cuts.is_empty() || cuts.len() >= MAX_PARTS {
        return Err(ARGUMENTS);
    }
    let mut previous = 0;
    for cut in cuts {
        if *cut <= previous || *cut >= expected.len() {
            return Err(ARGUMENTS);
        }
        previous = *cut;
    }
    let by = pdfcraft_organize::SplitBy::Before(cuts.to_vec());
    let ranges = pdfcraft_organize::split_ranges(expected.len(), &by);
    let parts = pdfcraft_organize::split(&document, &by).map_err(|_| INVALID)?;
    if parts.len() != ranges.len() {
        return Err(VERIFY);
    }
    // Verify all outputs and the aggregate size before creating any destination.
    let mut outputs = Vec::new();
    let mut total = 0usize;
    for (part, range) in parts.iter().zip(ranges) {
        let (bytes, info) = encode_verified(part, expected.get(range).ok_or(VERIFY)?, false)?;
        total = total.checked_add(bytes.len()).ok_or(LIMIT)?;
        if total > MAX_OUTPUT {
            return Err(LIMIT);
        }
        outputs.push((bytes, info));
    }
    std::fs::create_dir(directory).map_err(|_| DESTINATION)?;
    let mut created = Vec::new();
    let mut results = Vec::new();
    for (index, (bytes, mut info)) in outputs.into_iter().enumerate() {
        let name = format!("part-{:03}.pdf", index + 1);
        let output = directory.join(&name);
        if let Err(error) = write_new(&output, &bytes) {
            for path in created {
                let _ = std::fs::remove_file(path);
            }
            let _ = std::fs::remove_dir(directory);
            return Err(error);
        }
        created.push(output);
        info["file"] = json!(name);
        results.push(info);
    }
    Ok(json!({"saved": true, "outputs": results}))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};
    static SEQUENCE: AtomicUsize = AtomicUsize::new(0);

    struct FixtureDir(PathBuf);
    impl FixtureDir {
        fn new() -> Self {
            let stamp = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos();
            let path = std::env::temp_dir().join(format!("odibo-tools-{}-{stamp}-{}", std::process::id(), SEQUENCE.fetch_add(1, Ordering::Relaxed)));
            std::fs::create_dir(&path).unwrap();
            Self(path)
        }
        fn path(&self, name: &str) -> PathBuf {
            self.0.join(name)
        }
        fn source(&self, name: &str, widths: &[u32]) -> PathBuf {
            let path = self.path(name);
            std::fs::write(&path, fixture(widths)).unwrap();
            path
        }
    }
    impl Drop for FixtureDir {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.0);
        }
    }

    // Different MediaBoxes, rotations and vector content make order observable.
    fn fixture(widths: &[u32]) -> Vec<u8> {
        let kids = widths.iter().enumerate().map(|(i, _)| format!("{} 0 R", 3 + 2 * i)).collect::<Vec<_>>().join(" ");
        let mut objects = vec!["<< /Type /Catalog /Pages 2 0 R >>".to_string(), format!("<< /Type /Pages /Kids [{kids}] /Count {} >>", widths.len())];
        for (index, width) in widths.iter().enumerate() {
            let contents = format!("q 0.2 0.4 0.6 rg 10 20 {width} 100 re f Q\n");
            objects.push(format!(
                "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {width} 300] /Rotate {} /Contents {} 0 R >>",
                (index % 4) * 90,
                4 + index * 2
            ));
            objects.push(format!("<< /Length {} >>\nstream\n{contents}endstream", contents.len()));
        }
        let mut data = b"%PDF-1.4\n".to_vec();
        let mut offsets = vec![0];
        for (index, object) in objects.iter().enumerate() {
            offsets.push(data.len());
            data.extend_from_slice(format!("{} 0 obj\n{object}\nendobj\n", index + 1).as_bytes());
        }
        let xref = data.len();
        data.extend_from_slice(format!("xref\n0 {}\n0000000000 65535 f \n", offsets.len()).as_bytes());
        for offset in offsets.iter().skip(1) {
            data.extend_from_slice(format!("{offset:010} 00000 n \n").as_bytes());
        }
        data.extend_from_slice(format!("trailer\n<< /Size {} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n", offsets.len()).as_bytes());
        data
    }

    fn widths(path: &Path) -> Vec<u32> {
        let document = preflight(Arc::new(read_input(path).unwrap()), true).unwrap();
        pdfcraft_organize::page_boxes(&document).unwrap().iter().map(|boxes| boxes[0][2] as u32).collect()
    }

    #[test]
    fn combine_honors_document_and_page_order_and_sources_exactly() {
        let dir = FixtureDir::new();
        let a = dir.source("a.pdf", &[101, 102]);
        let b = dir.source("b.pdf", &[201, 202]);
        let before_a = std::fs::read(&a).unwrap();
        let before_b = std::fs::read(&b).unwrap();
        let output = dir.path("combined.pdf");
        let info = combine_path(&output, &[b.clone(), a.clone()]).unwrap();
        assert_eq!(info["pageCount"], 4);
        assert_eq!(widths(&output), vec![201, 202, 101, 102]);
        assert_eq!(std::fs::read(&a).unwrap(), before_a);
        assert_eq!(std::fs::read(&b).unwrap(), before_b);
    }

    #[test]
    fn reorder_is_exact_permutation_with_preserved_content_and_source() {
        let dir = FixtureDir::new();
        let input = dir.source("source.pdf", &[101, 102, 103, 104]);
        let before = std::fs::read(&input).unwrap();
        let output = dir.path("reordered.pdf");
        let info = reorder_path(&input, &output, &[3, 1, 0, 2]).unwrap();
        assert_eq!(widths(&output), vec![104, 102, 101, 103]);
        assert_eq!(info["rotations"], json!([270, 90, 0, 180]));
        assert_eq!(std::fs::read(&input).unwrap(), before);
        assert!(std::fs::read(&output).unwrap().starts_with(&before));
    }

    #[test]
    fn split_partitions_whole_document_reopens_every_part_and_keeps_source() {
        let dir = FixtureDir::new();
        let input = dir.source("source.pdf", &[101, 102, 103, 104]);
        let before = std::fs::read(&input).unwrap();
        let output = dir.path("split");
        let result = split_path(&input, &output, &[1, 3]).unwrap();
        assert_eq!(result["outputs"].as_array().unwrap().len(), 3);
        assert_eq!(widths(&output.join("part-001.pdf")), vec![101]);
        assert_eq!(widths(&output.join("part-002.pdf")), vec![102, 103]);
        assert_eq!(widths(&output.join("part-003.pdf")), vec![104]);
        assert_eq!(std::fs::read(&input).unwrap(), before);
        assert_eq!(std::fs::read_dir(output).unwrap().count(), 3);
    }

    #[test]
    fn invalid_permutations_and_cuts_never_create_outputs() {
        let dir = FixtureDir::new();
        let input = dir.source("source.pdf", &[101, 102, 103]);
        let before = std::fs::read(&input).unwrap();
        for order in [vec![], vec![0, 1], vec![0, 1, 3], vec![0, 0, 2]] {
            let output = dir.path("new.pdf");
            assert_eq!(reorder_path(&input, &output, &order).unwrap_err(), ARGUMENTS);
            assert!(!output.exists());
        }
        for cuts in [vec![], vec![0], vec![3], vec![1, 1], vec![2, 1], vec![usize::MAX]] {
            let output = dir.path("new-folder");
            assert_eq!(split_path(&input, &output, &cuts).unwrap_err(), ARGUMENTS);
            assert!(!output.exists());
        }
        assert_eq!(std::fs::read(&input).unwrap(), before);
        for value in ["", ",", "1,", ",1", "-1", " 1", "1.0", "184467440737095516160"] {
            assert_eq!(parse_indices(value).unwrap_err(), ARGUMENTS);
        }
        assert_eq!(parse_indices("2,4").unwrap(), vec![2, 4]);
    }

    #[test]
    fn existing_files_directories_and_missing_parent_fail_safely() {
        let dir = FixtureDir::new();
        let input = dir.source("source.pdf", &[101, 102]);
        let before = std::fs::read(&input).unwrap();
        assert_eq!(combine_path(&input, &[input.clone(), input.clone()]).unwrap_err(), DESTINATION);
        assert_eq!(reorder_path(&input, &input, &[1, 0]).unwrap_err(), DESTINATION);
        assert_eq!(split_path(&input, &dir.0, &[1]).unwrap_err(), DESTINATION);
        assert_eq!(reorder_path(&input, &dir.path("missing/new.pdf"), &[1, 0]).unwrap_err(), DESTINATION);
        assert_eq!(std::fs::read(&input).unwrap(), before);
    }

    #[test]
    fn malformed_signed_and_encrypted_inputs_are_refused_for_every_tool() {
        let dir = FixtureDir::new();
        let valid = dir.source("good.pdf", &[101, 102]);
        for kind in ["corrupt", "signed", "encrypted"] {
            let input = dir.path("invalid.pdf");
            let bytes = if kind == "corrupt" {
                b"not PDF".to_vec()
            } else {
                let mut document = preflight(Arc::new(fixture(&[101, 102])), true).unwrap();
                if kind == "signed" {
                    let mut signature = pdfcraft_cos::Dict::new();
                    signature.set(b"Type".to_vec(), Object::name("Sig"));
                    let reference = document.add(Object::Dict(signature));
                    document.update_dict(document.root().unwrap(), |d| d.set(b"TestSig".to_vec(), Object::Ref(reference))).unwrap();
                } else {
                    document
                        .set_encryption(&pdfcraft_cos::NewEncryption {
                            algorithm: pdfcraft_cos::Algorithm::Aes128,
                            user_password: "",
                            owner_password: "owner",
                            permissions: -4,
                            encrypt_metadata: true,
                            seed: [7; 32],
                        })
                        .unwrap();
                }
                pdfcraft_cos::write_full(&document, &SaveOptions::default()).unwrap()
            };
            std::fs::write(&input, &bytes).unwrap();
            assert!(combine_path(&dir.path("out.pdf"), &[valid.clone(), input.clone()]).is_err());
            assert!(reorder_path(&input, &dir.path("out.pdf"), &[1, 0]).is_err());
            assert!(split_path(&input, &dir.path("parts"), &[1]).is_err());
            assert!(!dir.path("out.pdf").exists());
            assert!(!dir.path("parts").exists());
            assert_eq!(std::fs::read(input).unwrap(), bytes);
        }
    }

    #[test]
    fn combine_enforces_aggregate_input_limit() {
        let dir = FixtureDir::new();
        let input = dir.path("large.pdf");
        let mut bytes = fixture(&[101, 102]);
        bytes.resize(MAX_INPUT / 2 + 1, b' ');
        std::fs::write(&input, &bytes).unwrap();
        assert_eq!(combine_path(&dir.path("out.pdf"), &[input.clone(), input]).unwrap_err(), LIMIT);
        assert!(!dir.path("out.pdf").exists());
    }

    #[test]
    fn content_compression_bomb_is_refused_before_organize_decodes_it() {
        let dir = FixtureDir::new();
        let mut document = preflight(Arc::new(fixture(&[101, 102])), true).unwrap();
        let stream = document.add(Object::Stream(pdfcraft_cos::Stream::flate(pdfcraft_cos::Dict::new(), &vec![b' '; MAX_STREAM + 1])));
        let page = pdfcraft_organize::pages(&document).unwrap()[0].obj;
        document.update_dict(page, |d| d.set(b"Contents".to_vec(), Object::Ref(stream))).unwrap();
        let bytes = pdfcraft_cos::write_full(&document, &SaveOptions::default()).unwrap();
        assert!(bytes.len() < MAX_INPUT);
        let input = dir.path("bomb.pdf");
        std::fs::write(&input, &bytes).unwrap();
        let other = dir.source("other.pdf", &[201, 202]);
        assert_eq!(combine_path(&dir.path("out.pdf"), &[other, input.clone()]).unwrap_err(), LIMIT);
        assert_eq!(split_path(&input, &dir.path("parts"), &[1]).unwrap_err(), LIMIT);
        assert_eq!(reorder_path(&input, &dir.path("out.pdf"), &[1, 0]).unwrap_err(), LIMIT);
        assert!(!dir.path("parts").exists());
        assert!(!dir.path("out.pdf").exists());
        assert_eq!(std::fs::read(input).unwrap(), bytes);
    }
}
