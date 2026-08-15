import '../models/slide_layout.dart';

/// OOXML definitions for the generated slide layouts (Track 05).
///
/// Mirrors the 9 editor [SlideLayoutType]s with real PowerPoint placeholders:
/// each layout maps to the OOXML `p:ph` types (`ctrTitle`, `title`,
/// `subTitle`, `body`, `pic`) with explicit EMU geometry on the 16:9 canvas.
///
/// The part number of a layout inside `ppt/slideLayouts/` equals its index in
/// [layouts] + 1 (layout 1 = Blank — the v1.6.3 default), and the slide
/// master lists all of them in `p:sldLayoutIdLst` so PowerPoint's Slide
/// Layout gallery shows the full set.
class PptLayoutDef {
  const PptLayoutDef(this.type, this.placeholders, {this.schemaType});

  final SlideLayoutType type;

  /// Optional ST_SlideLayoutType hint (`blank`, `title`, `obj`, `twoObj`,
  /// `secHead`). Omitted where no well-known value exists — the attribute
  /// is optional and PowerPoint derives the gallery entry from the
  /// placeholders anyway.
  final String? schemaType;

  final List<PptPlaceholderDef> placeholders;
}

/// One placeholder: OOXML `p:ph` type/index plus EMU bounds.
class PptPlaceholderDef {
  const PptPlaceholderDef({
    required this.phType,
    this.idx,
    required this.x,
    required this.y,
    required this.cx,
    required this.cy,
    required this.name,
  });

  /// `ctrTitle` | `title` | `subTitle` | `body` | `pic`.
  final String phType;

  /// Placeholder index (required when more than one of the same type).
  final int? idx;

  final int x;
  final int y;
  final int cx;
  final int cy;

  /// Name attribute for `p:cNvPr` (cosmetic, e.g. "Title 1").
  final String name;
}

const int _contentX = 457200;
const int _contentW = 11289600;

/// The nine registered layouts in generation order (index 0 = layout part 1).
const List<PptLayoutDef> pptLayouts = [
  PptLayoutDef(SlideLayoutType.blank, [], schemaType: 'blank'),
  PptLayoutDef(
    SlideLayoutType.titleSlide,
    [
      PptPlaceholderDef(
        phType: 'ctrTitle',
        x: _contentX,
        y: 2300000,
        cx: _contentW,
        cy: 1100000,
        name: 'Title 1',
      ),
      PptPlaceholderDef(
        phType: 'subTitle',
        x: _contentX,
        y: 3600000,
        cx: _contentW,
        cy: 900000,
        name: 'Subtitle 2',
      ),
    ],
    schemaType: 'title',
  ),
  PptLayoutDef(
    SlideLayoutType.titleAndContent,
    [
      PptPlaceholderDef(
        phType: 'title',
        x: _contentX,
        y: 400000,
        cx: _contentW,
        cy: 1143000,
        name: 'Title 1',
      ),
      PptPlaceholderDef(
        phType: 'body',
        idx: 1,
        x: _contentX,
        y: 1600000,
        cx: _contentW,
        cy: 4850000,
        name: 'Content Placeholder 2',
      ),
    ],
    schemaType: 'obj',
  ),
  PptLayoutDef(
    SlideLayoutType.sectionHeader,
    [
      PptPlaceholderDef(
        phType: 'ctrTitle',
        x: _contentX,
        y: 2500000,
        cx: _contentW,
        cy: 1100000,
        name: 'Title 1',
      ),
      PptPlaceholderDef(
        phType: 'subTitle',
        x: _contentX,
        y: 3800000,
        cx: _contentW,
        cy: 800000,
        name: 'Subtitle 2',
      ),
    ],
    schemaType: 'secHead',
  ),
  PptLayoutDef(
    SlideLayoutType.twoContent,
    [
      PptPlaceholderDef(
        phType: 'title',
        x: _contentX,
        y: 400000,
        cx: _contentW,
        cy: 1143000,
        name: 'Title 1',
      ),
      PptPlaceholderDef(
        phType: 'body',
        idx: 1,
        x: _contentX,
        y: 1600000,
        cx: 5470500,
        cy: 4850000,
        name: 'Left Content Placeholder 2',
      ),
      PptPlaceholderDef(
        phType: 'body',
        idx: 2,
        x: 6019200,
        y: 1600000,
        cx: 5470500,
        cy: 4850000,
        name: 'Right Content Placeholder 3',
      ),
    ],
    schemaType: 'twoObj',
  ),
  PptLayoutDef(
    SlideLayoutType.comparison,
    [
      PptPlaceholderDef(
        phType: 'title',
        x: _contentX,
        y: 400000,
        cx: _contentW,
        cy: 1143000,
        name: 'Title 1',
      ),
      PptPlaceholderDef(
        phType: 'body',
        idx: 1,
        x: _contentX,
        y: 2000000,
        cx: 5470500,
        cy: 4450000,
        name: 'Left Content Placeholder 2',
      ),
      PptPlaceholderDef(
        phType: 'body',
        idx: 2,
        x: 6019200,
        y: 2000000,
        cx: 5470500,
        cy: 4450000,
        name: 'Right Content Placeholder 3',
      ),
    ],
    schemaType: 'twoObj',
  ),
  PptLayoutDef(
    SlideLayoutType.titleOnly,
    [
      PptPlaceholderDef(
        phType: 'title',
        x: _contentX,
        y: 400000,
        cx: _contentW,
        cy: 1143000,
        name: 'Title 1',
      ),
    ],
  ),
  PptLayoutDef(
    SlideLayoutType.contentAndCaption,
    [
      PptPlaceholderDef(
        phType: 'title',
        x: _contentX,
        y: 400000,
        cx: _contentW,
        cy: 1143000,
        name: 'Title 1',
      ),
      PptPlaceholderDef(
        phType: 'body',
        idx: 1,
        x: _contentX,
        y: 1600000,
        cx: 8180000,
        cy: 4850000,
        name: 'Content Placeholder 2',
      ),
      PptPlaceholderDef(
        phType: 'body',
        idx: 2,
        x: 8780000,
        y: 1600000,
        cx: 3000000,
        cy: 4850000,
        name: 'Caption 3',
      ),
    ],
  ),
  PptLayoutDef(
    SlideLayoutType.pictureAndCaption,
    [
      PptPlaceholderDef(
        phType: 'title',
        x: _contentX,
        y: 200000,
        cx: _contentW,
        cy: 900000,
        name: 'Title 1',
      ),
      PptPlaceholderDef(
        phType: 'pic',
        x: _contentX,
        y: 1300000,
        cx: _contentW,
        cy: 4300000,
        name: 'Picture 2',
      ),
      PptPlaceholderDef(
        phType: 'body',
        idx: 2,
        x: _contentX,
        y: 5800000,
        cx: _contentW,
        cy: 800000,
        name: 'Caption 3',
      ),
    ],
  ),
];

/// Resolve the layout a slide should use; unknown values fall back to Blank
/// (the v1.6.3 default) so legacy decks keep working.
SlideLayoutType layoutTypeOf(Map<String, dynamic> slide) {
  final raw = (slide['layoutType'] ?? '').toString().trim();
  if (raw.isEmpty || raw == 'standard' || raw == 'blank') {
    return SlideLayoutType.blank;
  }
  for (final type in SlideLayoutType.values) {
    if (type.name == raw) return type;
  }
  return SlideLayoutType.blank;
}

/// The part number of [type] inside `ppt/slideLayouts/` (1-based).
int layoutPartNumber(SlideLayoutType type) =>
    pptLayouts.indexWhere((l) => l.type == type) + 1;