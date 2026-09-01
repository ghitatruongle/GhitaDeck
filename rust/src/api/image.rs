//! Image module — ghita_image (T06).
//!
//! Mirrors the deterministic Dart `image` pipeline in
//! `lib/services/html_image_loader.dart`: EXIF orientation is baked, wide
//! images are downscaled, large opaque PNGs may be re-encoded as JPEG, and
//! GIF/JPEG passthroughs keep the original bytes. The Dart facade falls back
//! to its own implementation if the DLL is unavailable, so both backends must
//! stay behaviour-compatible (pixel-diff gate, not byte-identical).

use flutter_rust_bridge::frb;
use image::codecs::jpeg::JpegEncoder;
use image::imageops::FilterType;
use image::{DynamicImage, ImageEncoder, ImageFormat};
use rayon::prelude::*;
use sha2::{Digest, Sha256};

/// One image job: the raw bytes plus the processing options.
pub struct ImageJob {
    pub bytes: Vec<u8>,
    /// "png" | "jpg" | "gif" (normalized; jpeg → jpg).
    pub ext: String,
    /// Downscale width; <= 0 means no resize.
    pub max_width: i64,
    /// Allow PNG → JPEG re-encode for large opaque images.
    pub allow_jpeg: bool,
    /// JPEG quality used by every re-encode (1..=100).
    pub jpeg_quality: i64,
}

/// Result of one processed image, mirroring Dart `LoadedImage`.
pub struct ImageOpResult {
    pub bytes: Vec<u8>,
    /// "png" | "jpg" | "gif" of the OUTPUT bytes.
    pub ext: String,
    pub width: i32,
    pub height: i32,
    /// Whether the output bytes differ from the input (passthrough == false).
    pub changed: bool,
    /// Whether the image was downscaled (drives the Dart-side savings tally).
    pub resized: bool,
}

#[inline]
fn normalize_ext(ext: &str) -> String {
    let lower = ext.to_lowercase();
    if lower == "jpeg" {
        "jpg".into()
    } else {
        lower
    }
}

/// Process one image. Errors never panic: a decode failure returns Err and
/// the Dart facade falls back (or records the warning like the Dart path).
/// `#[frb(sync)]`: the Dart facade must stay synchronous — it is called from
/// the export generation hot path (like the Dart `image` implementation it
/// replaces on the engine path).
#[frb(sync)]
pub fn img_process(job: ImageJob) -> Result<ImageOpResult, String> {
    let ext = normalize_ext(&job.ext);
    let quality = job.jpeg_quality.clamp(1, 100) as u8;

    let mut decoded = image::load_from_memory_with_format(
        &job.bytes,
        match ext.as_str() {
            "png" => ImageFormat::Png,
            "gif" => ImageFormat::Gif,
            _ => ImageFormat::Jpeg,
        },
    )
    .map_err(|e| format!("decode: {e}"))?;

    // The Dart path lets its decoders bake EXIF; the Rust image crate does
    // not, so read the orientation ourselves (JPEG APP1 / PNG eXIf) and apply
    // it for every format — same final pixels on both backends.
    let orientation = read_exif_orientation(&job.bytes);
    if orientation != 1 {
        decoded.apply_orientation(orientation_from_tag(orientation));
    }

    // package:image is 8-bit only — normalize 16-bit/other rows to the 8-bit
    // variants so both engines produce the same color model (which drives the
    // alpha check and therefore the PNG→JPEG conversion).
    let decoded = match decoded {
        DynamicImage::ImageRgb8(i) => DynamicImage::ImageRgb8(i),
        DynamicImage::ImageRgba8(i) => DynamicImage::ImageRgba8(i),
        DynamicImage::ImageLuma8(i) => DynamicImage::ImageLuma8(i),
        DynamicImage::ImageLumaA8(i) => DynamicImage::ImageLumaA8(i),
        other => DynamicImage::ImageRgba8(other.to_rgba8()),
    };

    let (orig_w, orig_h) = (decoded.width(), decoded.height());
    let resized = job.max_width > 0 && orig_w > job.max_width as u32;
    // imageops::resize preserves the source pixel type — resize per variant so
    // an opaque RGB image stays RGB (forcing Rgba8 would make every resized
    // image "alpha" and would break the PNG→JPEG conversion).
    let out = if resized {
        let new_w = job.max_width as u32;
        let new_h = (orig_h as f64 * (new_w as f64 / orig_w as f64)).round() as u32;
        let (nw, nh) = (new_w, new_h.max(1));
        match decoded {
            DynamicImage::ImageRgb8(i) => DynamicImage::ImageRgb8(
                image::imageops::resize(&i, nw, nh, FilterType::Lanczos3),
            ),
            DynamicImage::ImageRgba8(i) => DynamicImage::ImageRgba8(
                image::imageops::resize(&i, nw, nh, FilterType::Lanczos3),
            ),
            DynamicImage::ImageLuma8(i) => DynamicImage::ImageLuma8(
                image::imageops::resize(&i, nw, nh, FilterType::Lanczos3),
            ),
            DynamicImage::ImageLumaA8(i) => DynamicImage::ImageLumaA8(
                image::imageops::resize(&i, nw, nh, FilterType::Lanczos3),
            ),
            _ => DynamicImage::ImageRgba8(
                image::imageops::resize(&decoded, nw, nh, FilterType::Lanczos3),
            ),
        }
    } else {
        decoded
    };
    let out_ext = if resized { "png" } else { &ext };

    // GIF keeps its animation when untouched; resize/rotate would flatten it
    // by re-encoding — matching the Dart path (GIF passthrough only when
    // neither resize nor orientation happened).
    if ext == "gif" && !resized && orientation == 1 {
        return Ok(ImageOpResult {
            bytes: job.bytes,
            ext,
            width: orig_w as i32,
            height: orig_h as i32,
            changed: false,
            resized: false,
        });
    }

    if out_ext == "png" && job.allow_jpeg && !has_alpha(&out) {
        // Opaque PNG → JPEG (alpha images keep PNG), matching the Dart path.
        let (w, h) = (out.width(), out.height());
        if w >= 512 {
            let jpg = encode_jpeg(&out, quality)?;
            return Ok(ImageOpResult {
                bytes: jpg,
                ext: "jpg".into(),
                width: w as i32,
                height: h as i32,
                changed: true,
                resized,
            });
        }
    }

    let (w, h) = (out.width(), out.height());
    if out_ext == "png" {
        let mut png = Vec::new();
        image::codecs::png::PngEncoder::new(&mut png)
            .write_image(
                out.as_bytes(),
                w,
                h,
                out.color().into(),
            )
            .map_err(|e| format!("png encode: {e}"))?;
        return Ok(ImageOpResult {
            bytes: png,
            ext: "png".into(),
            width: w as i32,
            height: h as i32,
            changed: true,
            resized,
        });
    }

    if resized || orientation != 1 {
        let jpg = encode_jpeg(&out, quality.clamp(60, 95))?;
        return Ok(ImageOpResult {
            bytes: jpg,
            ext: "jpg".into(),
            width: w as i32,
            height: h as i32,
            changed: true,
            resized,
        });
    }

    // JPEG passthrough — bytes unchanged (like the Dart path).
    Ok(ImageOpResult {
        bytes: job.bytes,
        ext: "jpg".into(),
        width: orig_w as i32,
        height: orig_h as i32,
        changed: false,
        resized: false,
    })
}

fn encode_jpeg(img: &DynamicImage, quality: u8) -> Result<Vec<u8>, String> {
    let mut buf = Vec::new();
    let mut encoder = JpegEncoder::new_with_quality(&mut buf, quality);
    // image 0.25's JPEG encoder only accepts RGB/Luma — alpha is only an
    // issue for PNG→JPEG which is gated on fully opaque pixels anyway.
    let rgb = img.to_rgb8();
    encoder
        .encode(
            &rgb,
            rgb.width(),
            rgb.height(),
            image::ExtendedColorType::Rgb8,
        )
        .map_err(|e| format!("jpeg encode: {e}"))?;
    Ok(buf)
}

fn has_alpha(img: &DynamicImage) -> bool {
    // Channel-based, mirroring package:image's `Image.hasAlpha` (RGBA/LA
    // color models report alpha even when every pixel is opaque) — keeps the
    // Rust and Dart backends behaviour-identical and the N2 flag-on result
    // byte-compatible with the demo pipeline.
    img.as_rgba8().is_some() || img.as_luma_alpha8().is_some()
}

/// Process a batch in parallel (used by N2 optimizer exports).
pub fn img_process_batch(jobs: Vec<ImageJob>) -> Result<Vec<ImageOpResult>, String> {
    jobs.into_par_iter()
        .map(img_process)
        .collect::<Result<Vec<_>, _>>()
}

/// SHA-256 of arbitrary bytes — media dedupe / cache keys (T06 phase 9).
#[frb(sync)]
pub fn img_sha256(bytes: Vec<u8>) -> String {
    let digest = Sha256::digest(&bytes);
    let mut out = String::with_capacity(64);
    for b in digest {
        out.push_str(&format!("{b:02x}"));
    }
    out
}

// ---- EXIF orientation (port of the Dart TIFF reader) ---------------------

fn read_exif_orientation(bytes: &[u8]) -> u16 {
    if bytes.len() >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 {
        return orientation_from_jpeg(bytes);
    }
    if bytes.len() >= 8
        && bytes[0] == 0x89
        && bytes[1] == 0x50
        && bytes[2] == 0x4E
        && bytes[3] == 0x47
    {
        return orientation_from_png(bytes);
    }
    1
}

fn orientation_from_jpeg(bytes: &[u8]) -> u16 {
    let mut i = 2usize;
    while i + 4 <= bytes.len() {
        if bytes[i] != 0xFF {
            i += 1;
            continue;
        }
        let marker = bytes[i + 1];
        if marker == 0xD8 || marker == 0x01 || (0xD0..=0xD7).contains(&marker) {
            i += 2;
            continue;
        }
        let length = ((bytes[i + 2] as usize) << 8) | bytes[i + 3] as usize;
        if length < 2 || i + 2 + length > bytes.len() {
            break;
        }
        if marker == 0xE1 {
            let segment = &bytes[i + 4..i + 2 + length];
            if segment.len() >= 6 && &segment[..6] == b"Exif\x00\x00" {
                return orientation_from_tiff(&segment[6..]);
            }
        }
        i += 2 + length;
    }
    1
}

fn orientation_from_png(bytes: &[u8]) -> u16 {
    let mut i = 8usize;
    while i + 12 <= bytes.len() {
        let len = u32::from_be_bytes(bytes[i..i + 4].try_into().unwrap()) as usize;
        if &bytes[i + 4..i + 8] == b"eXIf" {
            if i + 8 + len > bytes.len() {
                return 1;
            }
            return orientation_from_tiff(&bytes[i + 8..i + 8 + len]);
        }
        i += 12 + len;
    }
    1
}

fn orientation_from_tiff(data: &[u8]) -> u16 {
    if data.len() < 8 {
        return 1;
    }
    let little = data[0] == 0x49 && data[1] == 0x49;
    let magic = if little {
        data[2] as u16 | (data[3] as u16) << 8
    } else {
        (data[2] as u16) << 8 | data[3] as u16
    };
    if magic != 42 {
        return 1;
    }
    let u16at = |off: usize| -> usize {
        if little {
            data[off] as usize | (data[off + 1] as usize) << 8
        } else {
            (data[off] as usize) << 8 | data[off + 1] as usize
        }
    };
    let u32at = |off: usize| -> usize {
        let mut v = 0usize;
        if little {
            for b in (off..off + 4).rev() {
                v = (v << 8) | data[b] as usize;
            }
        } else {
            for b in off..off + 4 {
                v = (v << 8) | data[b] as usize;
            }
        }
        v
    };
    let ifd_offset = u32at(4);
    if ifd_offset + 2 > data.len() {
        return 1;
    }
    let count = u16at(ifd_offset);
    for e in 0..count {
        let entry = ifd_offset + 2 + e * 12;
        if entry + 12 > data.len() {
            break;
        }
        if u16at(entry) == 0x0112 {
            return if little {
                data[entry + 8] as u16 | (data[entry + 9] as u16) << 8
            } else {
                (data[entry + 8] as u16) << 8 | data[entry + 9] as u16
            };
        }
    }
    1
}

fn orientation_from_tag(orientation: u16) -> image::metadata::Orientation {
    use image::metadata::Orientation;
    match orientation {
        2 => Orientation::FlipHorizontal,
        3 => Orientation::Rotate180,
        4 => Orientation::FlipVertical,
        5 => Orientation::Rotate90FlipH,
        6 => Orientation::Rotate90,
        7 => Orientation::Rotate270FlipH,
        8 => Orientation::Rotate270,
        _ => Orientation::NoTransforms,
    }
}

// ---- Tests ---------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn rgba(w: u32, h: u32, seed: u8) -> Vec<u8> {
        let mut pixels = Vec::with_capacity((w * h * 4) as usize);
        for i in 0..w * h {
            pixels.push((i % 251) as u8 ^ seed);
            pixels.push((i / 13 % 251) as u8 ^ seed);
            pixels.push((i / 7 % 251) as u8 ^ seed);
            pixels.push(255);
        }
        pixels
    }

    fn rgb(w: u32, h: u32, seed: u8) -> Vec<u8> {
        let mut pixels = Vec::with_capacity((w * h * 3) as usize);
        for i in 0..w * h {
            pixels.push((i % 251) as u8 ^ seed);
            pixels.push((i / 13 % 251) as u8 ^ seed);
            pixels.push((i / 7 % 251) as u8 ^ seed);
        }
        pixels
    }

    #[test]
    fn png_roundtrip_and_resize() {
        let mut png = Vec::new();
        image::codecs::png::PngEncoder::new(&mut png)
            .write_image(&rgba(640, 480, 1), 640, 480, image::ExtendedColorType::Rgba8)
            .unwrap();
        let res = img_process(ImageJob {
            bytes: png,
            ext: "png".into(),
            max_width: 320,
            allow_jpeg: false,
            jpeg_quality: 80,
        })
        .unwrap();
        assert_eq!(res.ext, "png");
        assert_eq!(res.width, 320);
        assert_eq!(res.height, 240);
        assert!(res.changed && res.resized);
    }

    #[test]
    fn large_opaque_png_converts_to_jpeg() {
        let mut png = Vec::new();
        image::codecs::png::PngEncoder::new(&mut png)
            .write_image(&rgb(512, 512, 7), 512, 512, image::ExtendedColorType::Rgb8)
            .unwrap();
        let png_len = png.len();
        let res = img_process(ImageJob {
            bytes: png,
            ext: "png".into(),
            max_width: 0,
            allow_jpeg: true,
            jpeg_quality: 80,
        })
        .unwrap();
        assert_eq!(res.ext, "jpg");
        // Noisy synthetic content — only asset that JPEG beats the PNG form.
        assert!(res.bytes.len() < png_len, "jpeg must be smaller than png");
    }

    #[test]
    fn jpeg_passthrough_is_unchanged() {
        let mut jpg = Vec::new();
        {
            let mut enc = JpegEncoder::new_with_quality(&mut jpg, 90);
            enc.encode(&rgb(300, 200, 3), 300, 200, image::ExtendedColorType::Rgb8)
                .unwrap();
        }
        let res = img_process(ImageJob {
            bytes: jpg.clone(),
            ext: "jpg".into(),
            max_width: 0,
            allow_jpeg: true,
            jpeg_quality: 80,
        })
        .unwrap();
        assert!(!res.changed);
        assert_eq!(res.bytes, jpg);
    }

    #[test]
    fn corrupt_bytes_are_an_error_not_panic() {
        let res = img_process(ImageJob {
            bytes: vec![1, 2, 3, 4, 5],
            ext: "png".into(),
            max_width: 0,
            allow_jpeg: false,
            jpeg_quality: 80,
        });
        assert!(res.is_err());
    }

    #[test]
    fn sha256_is_stable() {
        let a = img_sha256(b"hello".to_vec());
        let b = img_sha256(b"hello".to_vec());
        let c = img_sha256(b"hello!".to_vec());
        assert_eq!(a, b);
        assert_eq!(a.len(), 64);
        assert_ne!(a, c);
    }

    #[test]
    fn exif_orientation_in_png_chunk() {
        // Hand-crafted PNG with an eXIf chunk carrying orientation 6 (rotate
        // 90): 1×2 pixels become 2×1 after baking.
        let mut png = Vec::new();
        image::codecs::png::PngEncoder::new(&mut png)
            .write_image(&rgba(1, 2, 9), 1, 2, image::ExtendedColorType::Rgba8)
            .unwrap();

        // Build the eXIf chunk: TIFF header (little-endian, II 42), IFD with
        // one entry for tag 0x0112 = 6.
        let mut tiff = Vec::new();
        tiff.extend(b"II*\x00");
        tiff.extend(8u32.to_le_bytes());
        tiff.extend(1u16.to_le_bytes());
        tiff.extend(0x0112u16.to_le_bytes());
        tiff.extend(3u16.to_le_bytes()); // SHORT
        tiff.extend(1u32.to_le_bytes());
        tiff.extend(6u16.to_le_bytes()); // orientation 6
        tiff.extend([0, 0]);
        tiff.extend(0u32.to_le_bytes()); // next IFD

        let mut chunk = Vec::new();
        chunk.extend((tiff.len() as u32).to_be_bytes());
        chunk.extend(b"eXIf");
        chunk.extend(&tiff);
        chunk.extend([0, 0, 0, 0]); // CRC (ignored by our-length parser)

        // Insert the eXIf chunk right after the IHDR chunk (offset 8).
        let mut with_exif = Vec::new();
        with_exif.extend(&png[..8]);
        let ihdr_len = u32::from_be_bytes(png[8..12].try_into().unwrap()) as usize;
        let ihdr_end = 8 + 12 + ihdr_len;
        with_exif.extend(&png[8..ihdr_end]);
        with_exif.extend(&chunk);
        with_exif.extend(&png[ihdr_end..]);

        let res = img_process(ImageJob {
            bytes: with_exif,
            ext: "png".into(),
            max_width: 0,
            allow_jpeg: false,
            jpeg_quality: 80,
        })
        .unwrap();
        // 1×2 rotated 90° → 2×1.
        assert_eq!(res.width, 2);
        assert_eq!(res.height, 1);
    }
}
