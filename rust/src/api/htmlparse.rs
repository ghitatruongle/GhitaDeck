//! ghita_htmlparse — one-shot HTML tokenizer shared by PPTX/PDF/HTML export
//! (T13.3–T13.5).
//!
//! Mirrors `PPTGenerator._extractBlocks` (lib/services/ppt_generator.dart)
//! faithfully so the Rust and Dart paths produce identical block trees.
//! The Dart side keeps the map contract (`Map<String, dynamic>` with string
//! run properties); Rust returns JSON and Dart decodes it.
//!
//! Parity is enforced by `test/htmlparse_parity_test.dart` over a corpus of
//! real templates + hand-written edge cases — any divergence fails the test.

use flutter_rust_bridge::frb;
use std::collections::HashMap;

use html5ever::tendril::TendrilSink;
use html5ever::parse_document;
use markup5ever_rcdom::{Handle, NodeData, RcDom};
use serde_json::{json, Map as JsonMap, Value};

/// One-shot entry: parse [html] and return the four artifacts the session
/// parse cache needs (blocks / blocksNoFirstH2 / notes / subtitle) as a JSON
/// object. html5ever is always-recovering, so errors are rare; when one does
/// surface the Dart facade falls back to the Dart parser.
#[frb(sync)]
pub fn htmlparse_blocks(html: String) -> String {
    match try_parse(&html) {
        Ok(out) => out,
        Err(e) => json!({"error": e}).to_string(),
    }
}

fn try_parse(html: &str) -> Result<String, String> {
    let dom = parse_document(RcDom::default(), Default::default())
        .from_utf8()
        .read_from(&mut html.as_bytes())
        .map_err(|e| format!("html5ever: {e}"))?;
    let doc = dom.document;

    // Notes: first `aside.notes` text (trimmed), like querySelector.
    let notes = text_of_first_elem(&doc, &|el| {
        elem_is(el, "aside") && class_contains(el, "notes")
    })
    .map(|s| s.trim().to_string())
    .unwrap_or_default();

    // Subtitle: first non-empty h2 (trimmed).
    let subtitle = text_of_first_elem(&doc, &|el| elem_is(el, "h2"))
        .map(|s| s.trim().to_string())
        .unwrap_or_default();

    // Body element (html5ever always inserts html/head/body for fragments).
    let body = find_elem(&doc, &|el| elem_is(el, "body"))
        .ok_or_else(|| "no body".to_string())?;

    // Dart's parseHtmlContentFullFromDoc strips every `aside.notes` before
    // block extraction (notes are the dedicated notes artifact, not content).
    remove_all_from_tree(&body, &|el| {
        elem_is(el, "aside") && class_contains(el, "notes")
    });

    let blocks = extract_blocks_or_fallback(&body);
    let first_h2 = find_elem_ref(&doc, &|el| elem_is(el, "h2"));
    if let Some(h2) = first_h2 {
        remove_from_tree(&h2);
    }
    let blocks_no_h2 = extract_blocks_or_fallback(&body);

    Ok(json!({
        "blocks": blocks,
        "blocksNoFirstH2": blocks_no_h2,
        "notes": notes,
        "subtitle": subtitle,
    })
    .to_string())
}

// ---------------------------------------------------------------------------
// Element predicate helpers (no node data re-creation)
// ---------------------------------------------------------------------------

fn elem_is(node: &Handle, local: &str) -> bool {
    match &node.data {
        NodeData::Element { name, .. } => name.local.as_ref() == local,
        _ => false,
    }
}

fn local_tag(node: &Handle) -> Option<String> {
    match &node.data {
        NodeData::Element { name, .. } => Some(name.local.as_ref().to_string()),
        _ => None,
    }
}

fn text_of(node: &Handle) -> String {
    let mut out = String::new();
    if let NodeData::Text { contents } = &node.data {
        out.push_str(&contents.borrow());
    }
    for child in children_of(node) {
        out.push_str(&text_of(&child));
    }
    out
}

fn text_of_first_elem(
    node: &Handle,
    pred: &dyn Fn(&Handle) -> bool,
) -> Option<String> {
    if elem_is_tag_any(node) && pred(node) {
        return Some(text_of(node));
    }
    for child in children_of(node) {
        if let Some(t) = text_of_first_elem(&child, pred) {
            return Some(t);
        }
    }
    None
}

fn elem_is_tag_any(node: &Handle) -> bool {
    matches!(node.data, NodeData::Element { .. })
}

fn find_elem(node: &Handle, pred: &dyn Fn(&Handle) -> bool) -> Option<Handle> {
    if elem_is_tag_any(node) && pred(node) {
        return Some(node.clone());
    }
    for child in children_of(node) {
        if let Some(hit) = find_elem(&child, pred) {
            return Some(hit);
        }
    }
    None
}

fn find_elem_ref(node: &Handle, pred: &dyn Fn(&Handle) -> bool) -> Option<Handle> {
    find_elem(node, pred)
}

fn children_of(node: &Handle) -> Vec<Handle> {
    node.children.borrow().clone()
}

fn remove_from_tree(node: &Handle) {
    let parent = node.parent.take();
    node.parent.set(parent.clone());
    if let Some(parent) = parent {
        if let Some(p) = parent.upgrade() {
            p.children.borrow_mut().retain(|c| !std::rc::Rc::ptr_eq(c, node));
        }
    }
}

/// Remove every element matching [pred] from [root]'s subtree.
fn remove_all_from_tree(root: &Handle, pred: &dyn Fn(&Handle) -> bool) {
    for child in children_of(root) {
        if elem_is_tag_any(&child) && pred(&child) {
            remove_from_tree(&child);
            continue;
        }
        remove_all_from_tree(&child, pred);
    }
}

fn attr_str(node: &Handle, name: &str) -> Option<String> {
    match &node.data {
        NodeData::Element { attrs, .. } => {
            for a in attrs.borrow().iter() {
                if a.name.local.as_ref() == name {
                    return Some(a.value.to_string());
                }
            }
            None
        }
        _ => None,
    }
}

fn attr_bool(node: &Handle, name: &str) -> bool {
    match &node.data {
        NodeData::Element { attrs, .. } => attrs.borrow().iter().any(|a| a.name.local.as_ref() == name),
        _ => false,
    }
}

fn class_contains(node: &Handle, cls: &str) -> bool {
    match &node.data {
        NodeData::Element { attrs, .. } => {
            for a in attrs.borrow().iter() {
                if a.name.local.as_ref() == "class" {
                    return a.value.split_whitespace().any(|c| c == cls);
                }
            }
            false
        }
        _ => false,
    }
}

fn is_text_node(node: &Handle) -> Option<String> {
    match &node.data {
        NodeData::Text { contents } => Some(contents.borrow().to_string()),
        _ => None,
    }
}

// ---------------------------------------------------------------------------
// CSS style merging (mirrors _mergeElementStyle + color/font/align helpers)
// ---------------------------------------------------------------------------

fn css_color_names() -> &'static [(&'static str, &'static str)] {
    &[
        ("black", "000000"),
        ("white", "FFFFFF"),
        ("red", "FF0000"),
        ("green", "008000"),
        ("blue", "0000FF"),
        ("yellow", "FFFF00"),
        ("orange", "FFA500"),
        ("purple", "800080"),
        ("gray", "808080"),
        ("grey", "808080"),
        ("silver", "C0C0C0"),
        ("navy", "000080"),
        ("teal", "008080"),
        ("maroon", "800000"),
        ("olive", "808000"),
        ("lime", "00FF00"),
        ("aqua", "00FFFF"),
        ("cyan", "00FFFF"),
        ("magenta", "FF00FF"),
        ("fuchsia", "FF00FF"),
        ("pink", "FFC0CB"),
        ("brown", "A52A2A"),
        ("gold", "FFD700"),
    ]
}

fn css_color_to_hex(raw: &str) -> Option<String> {
    let v = raw.trim().to_lowercase();
    if v.is_empty() {
        return None;
    }
    if let Some(hex) = v.strip_prefix('#') {
        let h: Vec<char> = hex.chars().collect();
        if h.len() == 6 && h.iter().all(|c| c.is_ascii_hexdigit()) {
            return Some(hex.to_uppercase());
        }
        if h.len() == 3 && h.iter().all(|c| c.is_ascii_hexdigit()) {
            let mut out = String::new();
            for c in h {
                out.push(c);
                out.push(c);
            }
            return Some(out.to_uppercase());
        }
        return None;
    }
    let compact = v.replace(' ', "");
    if compact.starts_with("rgb") {
        let rest = compact.split('(').nth(1).unwrap_or("");
        let rest = rest.split(')').next().unwrap_or("");
        let parts: Vec<&str> = rest.split(',').collect();
        if parts.len() >= 3 {
            let mut hex = String::new();
            for p in parts.iter().take(3) {
                let n = p.parse::<f64>().ok()?.clamp(0.0, 255.0) as u32;
                hex.push_str(&format!("{:02X}", n));
            }
            return Some(hex);
        }
        return None;
    }
    for (name, hex) in css_color_names() {
        if *name == v {
            return Some(hex.to_string());
        }
    }
    None
}

fn css_font_size_to_sz(raw: &str) -> Option<String> {
    let v = raw.trim().to_lowercase();
    let bytes = v.as_bytes();
    let mut end = 0;
    while end < bytes.len() && (bytes[end].is_ascii_digit() || bytes[end] == b'.') {
        end += 1;
    }
    if end == 0 {
        return None;
    }
    let num = v[..end].parse::<f64>().ok()?;
    if num <= 0.0 {
        return None;
    }
    let rest = v[end..].trim();
    let unit = if rest.is_empty() { "px" } else { rest };
    let pt = match unit {
        "pt" => num,
        "em" | "rem" => num * 12.0,
        "px" => num * 0.75,
        _ => return None,
    };
    let sz = (pt * 100.0).round() as i64;
    if sz < 100 || sz > 40000 {
        return None;
    }
    Some(sz.to_string())
}

fn css_align_to_algn(v: &str) -> Option<&'static str> {
    match v.trim().to_lowercase().as_str() {
        "left" => Some("l"),
        "center" => Some("ctr"),
        "right" => Some("r"),
        "justify" => Some("just"),
        _ => None,
    }
}

fn merge_style(
    node: &Handle,
    style: &HashMap<String, String>,
) -> HashMap<String, String> {
    let mut merged = style.clone();
    if let Some(style_attr) = attr_str(node, "style") {
        for decl in style_attr.split(';') {
            let Some(colon) = decl.find(':') else { continue };
            let prop = decl[..colon].trim().to_lowercase();
            let value = decl[colon + 1..].trim();
            let lower = value.to_lowercase();
            match prop.as_str() {
                "color" => {
                    if let Some(hex) = css_color_to_hex(value) {
                        merged.insert("color".into(), hex);
                    }
                }
                "background-color" => {
                    if let Some(hex) = css_color_to_hex(value) {
                        merged.insert("highlight".into(), hex);
                    }
                }
                "font-size" => {
                    if let Some(sz) = css_font_size_to_sz(value) {
                        merged.insert("size".into(), sz);
                    }
                }
                "font-family" => {
                    let family = value.split(',').next().unwrap_or("").trim();
                    let family = family.replace(['"', '\''], "");
                    if !family.is_empty() {
                        merged.insert("font".into(), family);
                    }
                }
                "font-weight" => {
                    if lower == "bold"
                        || value
                            .parse::<i64>()
                            .map(|n| n >= 600)
                            .unwrap_or(false)
                    {
                        merged.insert("bold".into(), "true".into());
                    }
                }
                "font-style" => {
                    if lower == "italic" {
                        merged.insert("italic".into(), "true".into());
                    }
                }
                "text-decoration" => {
                    if value.contains("underline") {
                        merged.insert("underline".into(), "true".into());
                    }
                    if value.contains("line-through") {
                        merged.insert("strike".into(), "true".into());
                    }
                }
                "text-align" => {
                    if let Some(algn) = css_align_to_algn(value) {
                        merged.insert("align".into(), algn.into());
                    }
                }
                _ => {}
            }
        }
    }
    if let Some(align) = attr_str(node, "align") {
        if let Some(algn) = css_align_to_algn(&align) {
            merged.insert("align".into(), algn.into());
        }
    }
    merged
}

fn make_run(text: &str, style: &HashMap<String, String>, is_break: bool) -> JsonMap<String, Value> {
    let mut run = JsonMap::new();
    run.insert("text".into(), json!(text));
    run.insert(
        "bold".into(),
        json!(style.get("bold").map(|s| s.as_str()).unwrap_or("false")),
    );
    run.insert(
        "italic".into(),
        json!(style.get("italic").map(|s| s.as_str()).unwrap_or("false")),
    );
    for (key, field) in [
        ("underline", "underline"),
        ("strike", "strike"),
        ("color", "color"),
        ("highlight", "highlight"),
        ("size", "size"),
        ("font", "font"),
        ("align", "align"),
        ("href", "href"),
    ] {
        if let Some(v) = style.get(key) {
            if !v.is_empty() {
                run.insert(field.into(), json!(v));
            }
        }
    }
    if is_break {
        run.insert("isBreak".into(), json!("true"));
    }
    run
}

/// HTML collapses normal whitespace (mirrors _prepareRunGroup).
fn prepare_run_group(
    runs: &[JsonMap<String, Value>],
    start_marker: &str,
) -> Vec<JsonMap<String, Value>> {
    let mut prepared: Vec<JsonMap<String, Value>> = runs.iter().cloned().collect();
    if prepared.is_empty() {
        return prepared;
    }
    let is_break_run =
        |r: &JsonMap<String, Value>| r.get("isBreak").and_then(Value::as_str) == Some("true");
    for run in prepared.iter_mut() {
        if !is_break_run(run) {
            if let Some(Value::String(t)) = run.get_mut("text") {
                *t = collapse_ws(t);
            }
        }
    }
    let text_run_idx: Vec<usize> = prepared
        .iter()
        .enumerate()
        .filter(|(_, r)| !is_break_run(r))
        .map(|(i, _)| i)
        .collect();
    if let (Some(&first), Some(&last)) = (text_run_idx.first(), text_run_idx.last()) {
        if let Some(Value::String(t)) = prepared[first].get_mut("text") {
            *t = t.trim_start().to_string();
        }
        if let Some(Value::String(t)) = prepared[last].get_mut("text") {
            *t = t.trim_end().to_string();
        }
    }
    prepared.retain(|r| {
        is_break_run(r)
            || r.get("text")
                .and_then(Value::as_str)
                .map(|t| !t.is_empty())
                .unwrap_or(true)
    });
    if !prepared.is_empty() {
        if let Some(first) = prepared.first_mut() {
            first.insert(start_marker.into(), json!("true"));
        }
    }
    prepared
}

fn is_ws(c: char) -> bool {
    matches!(
        c,
        '\u{0009}'..='\u{000D}'
            | '\u{0020}'
            | '\u{00A0}'
            | '\u{1680}'
            | '\u{2000}'..='\u{200A}'
            | '\u{2028}'
            | '\u{2029}'
            | '\u{202F}'
            | '\u{205F}'
            | '\u{3000}'
            | '\u{FEFF}'
    )
}

/// Mirrors Dart `replaceAll(RegExp(r'\s+'), ' ')` — every whitespace run
/// becomes a single space, including leading/trailing ones (prepare_run_group
/// trims the first/last text run afterwards, exactly like Dart).
fn collapse_ws(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut in_ws = false;
    for c in s.chars() {
        if is_ws(c) {
            in_ws = true;
        } else {
            if in_ws {
                out.push(' ');
            }
            out.push(c);
            in_ws = false;
        }
    }
    if in_ws {
        out.push(' ');
    }
    out
}

// ---------------------------------------------------------------------------
// Block extraction (mirrors _extractBlocks)
// ---------------------------------------------------------------------------

struct BlockStream {
    result: Vec<Value>,
    current_paragraphs: Vec<JsonMap<String, Value>>,
    current_list_items: Vec<JsonMap<String, Value>>,
    current_list_ordered: bool,
    in_list: bool,
}

impl BlockStream {
    fn new() -> Self {
        Self {
            result: Vec::new(),
            current_paragraphs: Vec::new(),
            current_list_items: Vec::new(),
            current_list_ordered: false,
            in_list: false,
        }
    }

    fn flush_paragraphs(&mut self) {
        if !self.current_paragraphs.is_empty() {
            let mut m = JsonMap::new();
            m.insert("type".into(), json!("text"));
            m.insert(
                "paragraphs".into(),
                json!(self.current_paragraphs.clone()),
            );
            self.result.push(Value::Object(m));
            self.current_paragraphs.clear();
        }
    }

    fn flush_list(&mut self) {
        if !self.current_list_items.is_empty() {
            let mut m = JsonMap::new();
            m.insert("type".into(), json!("list"));
            m.insert("items".into(), json!(self.current_list_items.clone()));
            m.insert("ordered".into(), json!(self.current_list_ordered));
            self.result.push(Value::Object(m));
            self.current_list_items.clear();
        }
        self.in_list = false;
    }

    fn add_block(&mut self, kind: &str, attrs: &[(&str, &str)]) {
        self.flush_paragraphs();
        self.flush_list();
        let mut m = JsonMap::new();
        m.insert("type".into(), json!(kind));
        for (k, v) in attrs {
            m.insert((*k).into(), json!(v));
        }
        self.result.push(Value::Object(m));
    }
}

fn extract_blocks(element: &Handle) -> Vec<Value> {
    extract_blocks_inner(element, &HashMap::new())
}

/// Dart falls back to a single text paragraph of `body.text` when block
/// extraction yields nothing (mirrors parseHtmlContentFullFromDoc).
fn extract_blocks_or_fallback(element: &Handle) -> Vec<Value> {
    let blocks = extract_blocks(element);
    if !blocks.is_empty() {
        return blocks;
    }
    let text = text_of(element);
    vec![json!({
        "type": "text",
        "paragraphs": [{"text": text, "bold": "false", "italic": "false"}],
    })]
}

fn extract_blocks_inner(element: &Handle, inherited: &HashMap<String, String>) -> Vec<Value> {
    let mut s = BlockStream::new();
    for node in children_of(element) {
        if let Some(text) = is_text_node(&node) {
            let normalized = collapse_ws(&text);
            if !normalized.trim().is_empty() {
                if s.in_list {
                    s.flush_list();
                }
                let mut run = make_run(&normalized, inherited, false);
                if s.current_paragraphs.is_empty() {
                    run.insert("paragraphStart".into(), json!("true"));
                }
                s.current_paragraphs.push(run);
            }
            continue;
        }
        let Some(tag) = local_tag(&node) else { continue };
        let style = merge_style(&node, inherited);

        if tag == "br" {
            let run = make_run("", inherited, true);
            if s.in_list {
                s.current_list_items.push(run);
            } else {
                if s.current_paragraphs.is_empty() {
                    let mut r = run.clone();
                    r.insert("paragraphStart".into(), json!("true"));
                    s.current_paragraphs.push(r);
                    continue;
                }
                s.current_paragraphs.push(run);
            }
            continue;
        }
        if tag == "img" {
            if let Some(src) = attr_str(&node, "src") {
                if !src.is_empty() {
                    s.add_block("image", &[("src", src.as_str())]);
                }
            }
            continue;
        }
        if tag == "video" && attr_bool(&node, "data-video") {
            let dv = attr_str(&node, "data-video").unwrap_or_default();
            let poster = attr_str(&node, "poster").unwrap_or_default();
            s.add_block(
                "video",
                &[("data-video", dv.as_str()), ("poster", poster.as_str())],
            );
            continue;
        }
        if tag == "span" && attr_bool(&node, "data-icon") {
            let icon = attr_str(&node, "data-icon").unwrap_or_default();
            s.add_block("icon", &[("data-icon", icon.as_str())]);
            continue;
        }

        // data-* element kinds (tag must be `div` in Dart's _extractBlocks).
        let data_blocks: &[(&str, &str)] = &[
            ("data-smartart", "smartart"),
            ("data-model3d", "model3d"),
            ("data-chart", "chart"),
            ("data-action", "action"),
            ("data-equation", "equation"),
            ("data-ole", "ole"),
            ("data-zoom", "zoom"),
            ("data-sectionzoom", "sectionzoom"),
            ("data-cameo", "cameo"),
        ];
        let mut matched = false;
        if tag == "div" {
            for (dattr, kind) in data_blocks {
                if attr_bool(&node, dattr) {
                    let val = attr_str(&node, dattr).unwrap_or_default();
                    s.add_block(kind, &[(dattr, val.as_str())]);
                    matched = true;
                    break;
                }
            }
        }
        if matched {
            continue;
        }

        if matches!(tag.as_str(), "p" | "div" | "h1" | "h2" | "h3" | "h4" | "h5" | "h6") {
            s.flush_list();
            let has_block_children = children_of(&node).iter().any(|c| {
                local_tag(c)
                    .map(|l| matches!(l.as_str(), "img" | "ul" | "ol" | "table" | "p" | "div"))
                    .unwrap_or(false)
            });
            if (tag == "div" || tag == "p") && has_block_children {
                s.flush_paragraphs();
                for b in extract_blocks_inner(&node, &style) {
                    s.result.push(b);
                }
                continue;
            }
            let mut sub_pars = extract_inline_paragraphs(&node, &style);
            if !sub_pars.is_empty() {
                if tag.starts_with('h') {
                    for p in sub_pars.iter_mut() {
                        p.insert("bold".into(), json!("true"));
                        p.entry("italic".to_owned()).or_insert(json!("false"));
                    }
                }
                sub_pars = prepare_run_group(&sub_pars, "paragraphStart");
                s.current_paragraphs.extend(sub_pars);
            }
            continue;
        }
        if tag == "ul" || tag == "ol" {
            s.flush_paragraphs();
            s.flush_list();
            s.in_list = true;
            s.current_list_ordered = tag == "ol";
            for child in children_of(&node) {
                if local_tag(&child).as_deref() == Some("li") {
                    let li_style = merge_style(&child, &style);
                    let items = prepare_run_group(
                        &extract_inline_paragraphs(&child, &li_style),
                        "itemStart",
                    );
                    for item in items {
                        s.current_list_items.push(item);
                    }
                }
            }
            continue;
        }
        if tag == "table" {
            s.flush_paragraphs();
            s.flush_list();
            let (rows, has_header_row) = extract_table(&node);
            if !rows.is_empty() {
                let mut m = JsonMap::new();
                m.insert("type".into(), json!("table"));
                let rows_json: Vec<Value> = rows
                    .into_iter()
                    .map(|r| Value::Array(r.into_iter().map(Value::Object).collect()))
                    .collect();
                m.insert("rows".into(), Value::Array(rows_json));
                m.insert("headerRow".into(), json!(has_header_row));
                s.result.push(Value::Object(m));
            }
            continue;
        }
        if tag == "strong" || tag == "b" {
            let mut style_c = style.clone();
            style_c.insert("bold".into(), "true".into());
            let mut children_runs = extract_inline_paragraphs(&node, &style_c);
            if s.in_list && s.current_list_items.is_empty() {
                children_runs = prepare_run_group(&children_runs, "itemStart");
            } else if !s.in_list && s.current_paragraphs.is_empty() {
                children_runs = prepare_run_group(&children_runs, "paragraphStart");
            }
            for child in children_runs {
                if s.in_list {
                    s.current_list_items.push(child);
                } else {
                    s.current_paragraphs.push(child);
                }
            }
            continue;
        }
        if tag == "em" || tag == "i" {
            let mut style_c = style.clone();
            style_c.insert("italic".into(), "true".into());
            let mut children_runs = extract_inline_paragraphs(&node, &style_c);
            if s.in_list && s.current_list_items.is_empty() {
                children_runs = prepare_run_group(&children_runs, "itemStart");
            } else if !s.in_list && s.current_paragraphs.is_empty() {
                children_runs = prepare_run_group(&children_runs, "paragraphStart");
            }
            for child in children_runs {
                if s.in_list {
                    s.current_list_items.push(child);
                } else {
                    s.current_paragraphs.push(child);
                }
            }
            continue;
        }
        // Unknown element: recurse into it.
        let sub_blocks = extract_blocks_inner(&node, &style);
        for block in sub_blocks {
            match block.get("type").and_then(Value::as_str) {
                Some("text") => {
                    if let Some(Value::Array(paras)) = block.get("paragraphs") {
                        for p in paras.iter() {
                            if let Value::Object(m) = p {
                                s.current_paragraphs
                                    .push(m.iter().map(|(k, v)| (k.clone(), v.clone())).collect());
                            }
                        }
                    }
                }
                Some("list") | Some("image") | Some("table") => {
                    s.flush_paragraphs();
                    s.result.push(block);
                }
                _ => {}
            }
        }
    }
    s.flush_paragraphs();
    s.flush_list();
    s.result
}

fn extract_inline_paragraphs(
    element: &Handle,
    inherited: &HashMap<String, String>,
) -> Vec<JsonMap<String, Value>> {
    let mut result = Vec::new();
    for node in children_of(element) {
        if let Some(text) = is_text_node(&node) {
            let normalized = collapse_ws(&text);
            if !normalized.trim().is_empty() {
                result.push(make_run(&normalized, inherited, false));
            }
            continue;
        }
        let Some(tag) = local_tag(&node) else { continue };
        let style = merge_style(&node, inherited);
        if tag == "br" {
            result.push(make_run("", inherited, true));
        } else if tag == "strong" || tag == "b" {
            let mut sc = style.clone();
            sc.insert("bold".into(), "true".into());
            result.extend(extract_inline_paragraphs(&node, &sc));
        } else if tag == "em" || tag == "i" {
            let mut sc = style.clone();
            sc.insert("italic".into(), "true".into());
            result.extend(extract_inline_paragraphs(&node, &sc));
        } else if tag == "u" || tag == "ins" {
            let mut sc = style.clone();
            sc.insert("underline".into(), "true".into());
            result.extend(extract_inline_paragraphs(&node, &sc));
        } else if tag == "s" || tag == "del" || tag == "strike" {
            let mut sc = style.clone();
            sc.insert("strike".into(), "true".into());
            result.extend(extract_inline_paragraphs(&node, &sc));
        } else if tag == "a" {
            let href = attr_str(&node, "href").unwrap_or_default();
            if href.is_empty() {
                result.extend(extract_inline_paragraphs(&node, &style));
            } else {
                let mut sc = style.clone();
                sc.insert("href".into(), href);
                result.extend(extract_inline_paragraphs(&node, &sc));
            }
        } else {
            result.extend(extract_inline_paragraphs(&node, &style));
        }
    }
    result
}

fn extract_table(table: &Handle) -> (Vec<Vec<JsonMap<String, Value>>>, bool) {
    let mut rows: Vec<Vec<JsonMap<String, Value>>> = Vec::new();
    let mut has_header_row = false;
    for child in children_of(table) {
        match local_tag(&child).as_deref() {
            Some("thead") | Some("tbody") => {
                for tr in children_of(&child) {
                    if local_tag(&tr).as_deref() == Some("tr") {
                        append_row(&tr, &mut rows, &mut has_header_row);
                    }
                }
            }
            Some("tr") => {
                append_row(&child, &mut rows, &mut has_header_row);
            }
            _ => {}
        }
    }
    (rows, has_header_row)
}

fn append_row(
    tr: &Handle,
    rows: &mut Vec<Vec<JsonMap<String, Value>>>,
    has_header_row: &mut bool,
) {
    let mut cells: Vec<JsonMap<String, Value>> = Vec::new();
    for child in children_of(tr) {
        let Some(tag) = local_tag(&child) else { continue };
        if tag == "th" || tag == "td" {
            let style = merge_style(&child, &HashMap::new());
            let text = text_of(&child).trim().to_string();
            let mut cell = make_run(&text, &style, false);
            if tag == "th" {
                cell.insert("bold".into(), json!("true"));
                *has_header_row = true;
            }
            cells.push(cell);
        }
    }
    rows.push(cells);
}
