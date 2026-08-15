/// Stock media library (Track 15, FEAT 12).
///
/// Bundled "Ảnh kho local": a set of CC0-style vector illustrations rendered
/// as inline SVGs (no binary assets, no network). Categories mirror common
/// presentation needs: Nature, Business, Technology, Education, Abstract,
/// People. Each illustration is a self-generated SVG document.
library;

import 'stock_media_variants.dart';

class StockMediaItem {
  const StockMediaItem({
    required this.name,
    required this.category,
    required this.svg,
  });

  final String name;
  final String category;

  /// Inline SVG markup (full `<svg>...</svg>` document).
  final String svg;

  /// Data-URI form used when the HTML deck wants a plain `<img src>`.
  String get dataUri => 'data:image/svg+xml;base64,'
      '${Uri.encodeComponent(svg)}';
}

class StockMediaService {
  StockMediaService._();

  static Map<String, List<StockMediaItem>> get byCategory {
    if (_cache != null) return _cache!;
    _cache = _buildIndex(_all);
    return _cache!;
  }

  static Map<String, List<StockMediaItem>>? _cache;

  static List<StockMediaItem> search(String query) {
    if (query.trim().isEmpty) return _all;
    final q = query.toLowerCase();
    return _all.where((m) =>
        m.name.toLowerCase().contains(q) ||
        m.category.toLowerCase().contains(q)).toList();
  }

  static Map<String, List<StockMediaItem>> _buildIndex(List<StockMediaItem> items) {
    final map = <String, List<StockMediaItem>>{};
    for (final item in items) {
      map.putIfAbsent(item.category, () => []).add(item);
    }
    return map;
  }

  // ---- Bundled CC0-style vector illustrations ---------------------------

  static String _svg(
      String title,
      String body,
      {String bg = '#eef2f7', String viewBox = '0 0 400 240'}) {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="$viewBox" '
        'width="400" height="240" role="img" aria-label="$title">'
        '<rect width="400" height="240" fill="$bg"/>$body</svg>';
  }

  static final List<StockMediaItem> _all = [
    // ---- Nature ----------------------------------------------------------
    StockMediaItem(name: 'Mountain sunset', category: 'Nature', svg: _svg('Mountain sunset',
        '<polygon points="0,240 120,60 240,240" fill="#8dbf6a"/>'
        '<polygon points="120,240 260,80 400,240" fill="#6a9a4f"/>'
        '<polygon points="60,240 140,140 220,240" fill="#4a7a36"/>'
        '<circle cx="300" cy="70" r="30" fill="#f7b733"/>'
        '<rect y="200" width="400" height="40" fill="#5a8f4a"/>'
        '<rect y="210" width="400" height="30" fill="#3f6f36"/>')),
    StockMediaItem(name: 'Ocean waves', category: 'Nature', svg: _svg('Ocean waves',
        '<rect width="400" height="240" fill="#bfe3f7"/>'
        '<path d="M0,180 Q50,150 100,180 T200,180 T300,180 T400,180 V240 H0 Z" fill="#3a8fd4"/>'
        '<path d="M0,200 Q50,180 100,200 T200,200 T300,200 T400,200 V240 H0 Z" fill="#2a70b4"/>'
        '<circle cx="80" cy="60" r="25" fill="#ffd93d"/>')),
    StockMediaItem(name: 'Forest path', category: 'Nature', svg: _svg('Forest path',
        '<rect width="400" height="240" fill="#dcefe0"/>'
        '<rect y="160" width="400" height="80" fill="#8dbf6a"/>'
        '<polygon points="80,0 120,160 40,160" fill="#4a7a36"/>'
        '<polygon points="200,0 240,160 160,160" fill="#3f6f36"/>'
        '<polygon points="320,0 360,160 280,160" fill="#4a7a36"/>'
        '<path d="M150,240 Q200,190 250,240" stroke="#c9a86a" stroke-width="20" fill="none"/>')),
    StockMediaItem(name: 'Rainbow sky', category: 'Nature', svg: _svg('Rainbow sky',
        '<rect width="400" height="240" fill="#cfe8ff"/>'
        '<path d="M50,240 A150,150 0 0 1 350,240" stroke="#ff5f6d" stroke-width="22" fill="none"/>'
        '<path d="M50,240 A150,150 0 0 1 350,240" stroke="#ffc93c" stroke-width="18" fill="none" transform="translate(0,20)"/>'
        '<path d="M50,240 A150,150 0 0 1 350,240" stroke="#6bcB77" stroke-width="18" fill="none" transform="translate(0,40)"/>'
        '<rect y="210" width="400" height="30" fill="#8dbf6a"/>')),

    // ---- Business ---------------------------------------------------------
    StockMediaItem(name: 'Growth chart', category: 'Business', svg: _svg('Growth chart',
        '<rect x="40" y="40" width="320" height="160" fill="#ffffff" stroke="#c9d4e4"/>'
        '<path d="M60,170 L110,140 L160,150 L210,100 L260,110 L310,60 L340,70" stroke="#3a8fd4" stroke-width="4" fill="none"/>'
        '<polygon points="310,60 320,80 300,80" fill="#3a8fd4"/>'
        '<rect x="60" y="170" width="18" height="30" fill="#6aa9e8"/>'
        '<rect x="110" y="140" width="18" height="60" fill="#8bc1f0"/>'
        '<rect x="160" y="150" width="18" height="50" fill="#a8d0f5"/>'
        '<rect x="210" y="100" width="18" height="100" fill="#6aa9e8"/>'
        '<rect x="260" y="110" width="18" height="90" fill="#8bc1f0"/>')),
    StockMediaItem(name: 'Team meeting', category: 'Business', svg: _svg('Team meeting',
        '<rect width="400" height="240" fill="#eef2f7"/>'
        '<rect x="140" y="100" width="120" height="90" rx="10" fill="#ffffff" stroke="#c9d4e4"/>'
        '<circle cx="170" cy="140" r="14" fill="#8bc1f0"/>'
        '<circle cx="200" cy="140" r="14" fill="#f7b733"/>'
        '<circle cx="230" cy="140" r="14" fill="#6bcB77"/>'
        '<rect x="160" y="165" width="80" height="8" rx="4" fill="#c9d4e4"/>')),
    StockMediaItem(name: 'Light bulb idea', category: 'Business', svg: _svg('Light bulb idea',
        '<rect width="400" height="240" fill="#fff8e1"/>'
        '<path d="M200,50 Q250,90 250,140 Q250,180 220,190 L180,190 Q150,180 150,140 Q150,90 200,50 Z" fill="#ffd93d" stroke="#e6a700" stroke-width="3"/>'
        '<rect x="180" y="195" width="40" height="12" rx="4" fill="#c9a86a"/>'
        '<rect x="190" y="207" width="20" height="12" rx="4" fill="#a08050"/>'
        '<path d="M120,60 L90,30 M280,60 L310,30" stroke="#e6a700" stroke-width="4"/>')),

    // ---- Technology --------------------------------------------------------
    StockMediaItem(name: 'Code window', category: 'Technology', svg: _svg('Code window',
        '<rect x="40" y="50" width="320" height="160" rx="8" fill="#1e2a3a"/>'
        '<circle cx="60" cy="70" r="6" fill="#ff5f6d"/>'
        '<circle cx="80" cy="70" r="6" fill="#ffc93c"/>'
        '<circle cx="100" cy="70" r="6" fill="#6bcB77"/>'
        '<text x="60" y="120" fill="#6bcB77" font-size="14" font-family="monospace">&lt;div&gt;</text>'
        '<text x="60" y="145" fill="#8bc1f0" font-size="14" font-family="monospace">&nbsp;&nbsp;class="slide"</text>'
        '<text x="60" y="170" fill="#ffc93c" font-size="14" font-family="monospace">&lt;/div&gt;</text>')),
    StockMediaItem(name: 'Cloud storage', category: 'Technology', svg: _svg('Cloud storage',
        '<rect width="400" height="240" fill="#e3f2fd"/>'
        '<path d="M120,180 Q100,180 95,160 Q90,135 120,130 Q130,100 165,105 Q200,80 230,110 Q265,100 275,135 Q300,135 300,160 Q300,180 275,180 Z" fill="#8bc1f0"/>'
        '<rect x="180" y="150" width="40" height="24" rx="4" fill="#ffffff"/>')),
    StockMediaItem(name: 'Circuit board', category: 'Technology', svg: _svg('Circuit board',
        '<rect width="400" height="240" fill="#123526"/>'
        '<path d="M40,120 L200,120 L200,60 L360,60" stroke="#2e8b57" stroke-width="3" fill="none"/>'
        '<path d="M80,200 L80,180 L320,180 L320,120" stroke="#2e8b57" stroke-width="3" fill="none"/>'
        '<rect x="40" y="112" width="16" height="16" fill="#4ade80"/>'
        '<rect x="192" y="52" width="16" height="16" fill="#4ade80"/>'
        '<rect x="312" y="112" width="16" height="16" fill="#4ade80"/>'
        '<circle cx="200" cy="120" r="10" fill="#ffd93d"/>')),

    // ---- Education ----------------------------------------------------------
    StockMediaItem(name: 'Books stack', category: 'Education', svg: _svg('Books stack',
        '<rect width="400" height="240" fill="#f3ecff"/>'
        '<rect x="100" y="150" width="200" height="30" rx="4" fill="#7a5cd0"/>'
        '<rect x="110" y="120" width="180" height="30" rx="4" fill="#9a7ce8"/>'
        '<rect x="120" y="90" width="160" height="30" rx="4" fill="#c3aef7"/>'
        '<rect x="90" y="180" width="220" height="10" rx="4" fill="#5a3ca0"/>')),
    StockMediaItem(name: 'Graduation cap', category: 'Education', svg: _svg('Graduation cap',
        '<rect width="400" height="240" fill="#eef2f7"/>'
        '<polygon points="200,60 320,120 200,180 80,120" fill="#4a4a68"/>'
        '<polygon points="200,60 320,120 200,180 80,120" fill="none" stroke="#7a7a9a" stroke-width="2"/>'
        '<path d="M200,60 L200,40 L320,100 L320,120" fill="#5a5a78"/>'
        '<rect x="40" y="180" width="320" height="20" fill="#6a6a8a"/>')),

    // ---- Abstract -----------------------------------------------------------
    StockMediaItem(name: 'Color gradient', category: 'Abstract', svg: _svg('Color gradient',
        '<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">'
        '<stop offset="0%" stop-color="#ff5f6d"/><stop offset="100%" stop-color="#3a8fd4"/>'
        '</linearGradient></defs><rect width="400" height="240" fill="url(#g)"/>')),
    StockMediaItem(name: 'Geometric shapes', category: 'Abstract', svg: _svg('Geometric shapes',
        '<rect width="400" height="240" fill="#f5f7fa"/>'
        '<circle cx="120" cy="100" r="50" fill="#ffd93d" opacity="0.8"/>'
        '<rect x="220" y="60" width="80" height="80" fill="#3a8fd4" opacity="0.8"/>'
        '<polygon points="320,120 380,60 380,180" fill="#6bcB77" opacity="0.8"/>'
        '<rect x="60" y="170" width="280" height="20" rx="10" fill="#8bc1f0"/>')),
    StockMediaItem(name: 'Abstract wave', category: 'Abstract', svg: _svg('Abstract wave',
        '<defs><linearGradient id="w" x1="0" y1="0" x2="1" y2="0">'
        '<stop offset="0%" stop-color="#3a8fd4"/><stop offset="100%" stop-color="#6bcB77"/>'
        '</linearGradient></defs>'
        '<path d="M0,160 Q50,120 100,160 T200,160 T300,160 T400,160 V240 H0 Z" fill="url(#w)"/>'
        '<path d="M0,190 Q50,150 100,190 T200,190 T300,190 T400,190 V240 H0 Z" fill="#2a70b4" opacity="0.7"/>')),

    // ---- People --------------------------------------------------------------
    StockMediaItem(name: 'User avatar', category: 'People', svg: _svg('User avatar',
        '<rect width="400" height="240" fill="#eef2f7"/>'
        '<circle cx="200" cy="100" r="50" fill="#8bc1f0"/>'
        '<path d="M100,220 Q100,160 200,160 Q300,160 300,220" fill="#6a9a4f"/>')),
    StockMediaItem(name: 'Handshake', category: 'People', svg: _svg('Handshake',
        '<rect width="400" height="240" fill="#fdf6ec"/>'
        '<circle cx="130" cy="140" r="14" fill="#e0ac69"/>'
        '<circle cx="270" cy="140" r="14" fill="#c98a4a"/>'
        '<path d="M120,155 Q200,170 280,155 L280,175 Q200,190 120,175 Z" fill="#e0ac69"/>'
        '<rect x="110" y="180" width="40" height="30" rx="6" fill="#3a8fd4"/>'
        '<rect x="250" y="180" width="40" height="30" rx="6" fill="#f7b733"/>')),
    StockMediaItem(name: 'Presentation speaker', category: 'People', svg: _svg('Presentation speaker',
        '<rect width="400" height="240" fill="#eef2f7"/>'
        '<rect x="40" y="40" width="220" height="120" rx="6" fill="#ffffff" stroke="#c9d4e4"/>'
        '<rect x="60" y="60" width="180" height="12" rx="4" fill="#3a8fd4"/>'
        '<rect x="60" y="85" width="140" height="8" rx="4" fill="#c9d4e4"/>'
        '<rect x="60" y="105" width="160" height="8" rx="4" fill="#c9d4e4"/>'
        '<rect x="60" y="125" width="120" height="8" rx="4" fill="#c9d4e4"/>'
        '<rect x="290" y="40" width="80" height="150" rx="6" fill="#f7b733"/>'
        '<circle cx="330" cy="80" r="16" fill="#c98a4a"/>'
        '<rect x="305" y="105" width="50" height="30" rx="8" fill="#4a4a68"/>'
        '<rect x="60" y="180" width="280" height="14" rx="6" fill="#c9d4e4"/>')),

    // ---- Generated variants (Track 15, P5): ~80 more CC0-style vector
    // illustrations from parameterized templates, so the local library
    // reaches ~100 items. See stock_media_variants.dart.
    ...stockMediaVariants(),
  ];
}
