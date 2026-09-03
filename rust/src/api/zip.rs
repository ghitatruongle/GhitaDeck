//! ZIP module — ghita_zip (T02).
//!
//! Mirrors the Dart `archive` path semantics: XML/text parts are deflated at
//! the requested level, media (already-compressed JPEG/PNG/GIF) is stored
//! as-is. Output stays a standard ZIP so PowerPoint and the Dart decoder both
//! accept it.

use std::io::{Cursor, Write};

use zip::write::{SimpleFileOptions, ZipWriter};
use zip::CompressionMethod;

/// One member of the archive. `stored: true` writes the bytes without a
/// second deflate pass (media arrives already compressed).
pub struct ZipEntry {
    pub name: String,
    pub data: Vec<u8>,
    pub stored: bool,
}

/// Build a ZIP archive from [ZipEntry] list, returning the archive bytes.
///
/// `level` is the deflate level for text entries (0 disables deflate).
/// Deterministic: the same entries produce byte-identical output, which keeps
/// the existing .ghita/PPTX hash/verification behavior intact.
pub fn zip_archive(entries: Vec<ZipEntry>, level: i64) -> Result<Vec<u8>, String> {
    let mut cursor = Cursor::new(Vec::new());
    {
        let mut writer = ZipWriter::new(&mut cursor).set_auto_large_file();
        // zip 8.x rejects a compression level on Stored members and maps
        // levels >= 10 to zopfli (very slow); keep text deflate inside the
        // flate2 (zlib-rs) range 1..=9 and never pass a level for stored.
        // B4: level <= 0 means STORE (the Dart path stores too) — clamping it
        // to 1 would silently deflate the member and break the contract.
        let deflate_level = if level <= 0 { 0 } else { level.clamp(1, 9) };
        for entry in entries {
            let stored = entry.stored || deflate_level <= 0;
            let mut options = SimpleFileOptions::default()
                .compression_method(if stored {
                    CompressionMethod::Stored
                } else {
                    CompressionMethod::Deflated
                })
                // B5: no unconditional ZIP64 — small members keep plain
                // 32-bit headers (the Dart emitter does the same), which old
                // readers accept; set_auto_large_file promotes automatically
                // only when a member actually exceeds 4 GB.
                .large_file(false);
            if !stored {
                options = options.compression_level(Some(deflate_level));
            }
            writer
                .start_file(entry.name, options)
                .map_err(|e| e.to_string())?;
            writer.write_all(&entry.data).map_err(|e| e.to_string())?;
        }
        writer.finish().map_err(|e| e.to_string())?;
    }
    Ok(cursor.into_inner())
}

#[cfg(test)]
mod tests {
    use super::*;
    use zip::read::ZipArchive;

    #[test]
    fn roundtrip_deflate_and_stored() {
        let out = zip_archive(
            vec![
                ZipEntry {
                    name: "text.txt".into(),
                    data: b"hello vietnamese: \xc3\xa0 \xc3\xa1 \xc3\xa2".to_vec(),
                    stored: false,
                },
                ZipEntry {
                    name: "img.jpg".into(),
                    data: vec![0xAB; 1024],
                    stored: true,
                },
            ],
            9,
        )
        .unwrap();

        let mut reader = ZipArchive::new(Cursor::new(out)).unwrap();
        assert_eq!(reader.len(), 2);
        let text = reader.by_name("text.txt").unwrap();
        assert!(text.compression() == CompressionMethod::Deflated);
        drop(text);
        let img = reader.by_name("img.jpg").unwrap();
        assert!(img.compression() == CompressionMethod::Stored);
        assert_eq!(img.size(), 1024);
    }

    #[test]
    fn empty_list_is_valid_archive() {
        let out = zip_archive(vec![], 9).unwrap();
        let reader = ZipArchive::new(Cursor::new(out)).unwrap();
        assert_eq!(reader.len(), 0);
    }

    /// B4: level 0 means STORE (same contract as the Dart emitter) — the old
    /// `clamp(1,9)` silently deflated these members.
    #[test]
    fn level_zero_stores_instead_of_deflating() {
        let out = zip_archive(
            vec![ZipEntry {
                name: "raw.bin".into(),
                data: b"compress me compress me compress me compress me".to_vec(),
                stored: false,
            }],
            0,
        )
        .unwrap();
        let mut reader = ZipArchive::new(Cursor::new(out)).unwrap();
        let entry = reader.by_name("raw.bin").unwrap();
        assert!(
            entry.compression() == CompressionMethod::Stored,
            "level 0 must not deflate"
        );
    }

    /// B5: small members are plain 32-bit entries — no ZIP64 record.
    #[test]
    fn small_archive_has_no_zip64() {
        let out = zip_archive(
            vec![ZipEntry {
                name: "small.txt".into(),
                data: b"tiny".to_vec(),
                stored: true,
            }],
            9,
        )
        .unwrap();
        let mut i = 0;
        while i + 4 <= out.len() {
            if out[i..i + 4] == [0x50, 0x4B, 0x06, 0x06] {
                panic!("unexpected ZIP64 EOCD62 record in a small archive");
            }
            i += 1;
        }
        let mut reader = ZipArchive::new(Cursor::new(out)).unwrap();
        let entry = reader.by_name("small.txt").unwrap();
        assert_eq!(entry.compression(), CompressionMethod::Stored);
    }
}
