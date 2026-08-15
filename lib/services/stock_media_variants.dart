/// Generated stock-media variants (Track 15, P5): ~80 additional CC0-style
/// vector illustrations produced from parameterized templates (palette +
/// composition), so the "Ảnh kho local" reaches ~100 items without binary
/// assets. Same rendering path as the hand-crafted ones (inline SVG).
library;

import 'stock_media_service.dart';

/// All generated variants, appended after the curated illustrations.
List<StockMediaItem> stockMediaVariants() => [
      // ---- Nature (12) -------------------------------------------------
      ..._nature(),
      // ---- Business (14) ------------------------------------------------
      ..._business(),
      // ---- Technology (12) ----------------------------------------------
      ..._technology(),
      // ---- Education (12) -----------------------------------------------
      ..._education(),
      // ---- Abstract (16) -------------------------------------------------
      ..._abstractItems(),
      // ---- People (10) ---------------------------------------------------
      ..._people(),
    ];

String _svg(String title, String body, {String bg = '#eef2f7'}) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 240" '
    'width="400" height="240" role="img" aria-label="$title">'
    '<rect width="400" height="240" fill="$bg"/>$body</svg>';

List<StockMediaItem> _nature() => [
      StockMediaItem(name: 'Alpine peaks', category: 'Nature',
        svg: _svg('Alpine peaks',
          '<polygon points="0,240 90,70 180,240" fill="#b9c8e8"/>'
          '<polygon points="110,240 200,90 300,240" fill="#9db4dd"/>'
          '<polygon points="230,240 320,60 400,240" fill="#8aa4cf"/>'
          '<polygon points="0,240 90,70 100,240" fill="#ffffff"/>'
          '<rect y="200" width="400" height="40" fill="#7d9cc9"/>')),
      StockMediaItem(name: 'Desert dunes', category: 'Nature',
        svg: _svg('Desert dunes',
          '<rect width="400" height="240" fill="#fdeec8"/>'
          '<path d="M0,240 Q80,150 180,210 T400,190 V240 Z" fill="#f0cf8a"/>'
          '<path d="M0,240 Q120,180 260,220 T400,210 V240 Z" fill="#e0b866"/>'
          '<circle cx="330" cy="70" r="32" fill="#ffd93d"/>')),
      StockMediaItem(name: 'Night sky stars', category: 'Nature',
        svg: _svg('Night sky stars',
          '<rect width="400" height="240" fill="#1c2440"/>'
          '<circle cx="60" cy="50" r="3" fill="#fff"/>'
          '<circle cx="120" cy="90" r="2" fill="#fff"/>'
          '<circle cx="220" cy="40" r="3" fill="#fff"/>'
          '<circle cx="300" cy="100" r="2" fill="#fff"/>'
          '<circle cx="350" cy="40" r="3" fill="#fff"/>'
          '<circle cx="80" cy="140" r="2" fill="#fff"/>'
          '<circle cx="190" cy="120" r="2" fill="#fff"/>'
          '<circle cx="270" cy="150" r="3" fill="#fff"/>'
          '<path d="M0,200 Q100,170 200,200 T400,190 V240 H0 Z" fill="#2c3a60"/>'
          '<path d="M0,215 Q150,195 400,215 V240 H0 Z" fill="#3a4a78"/>')),
      StockMediaItem(name: 'Autumn trees', category: 'Nature',
        svg: _svg('Autumn trees',
          '<rect width="400" height="240" fill="#fdf3dc"/>'
          '<rect y="180" width="400" height="60" fill="#c98a4a"/>'
          '<rect x="80" y="120" width="12" height="70" fill="#8a5a30"/>'
          '<circle cx="86" cy="90" r="40" fill="#f7b733"/>'
          '<rect x="220" y="110" width="14" height="80" fill="#8a5a30"/>'
          '<circle cx="227" cy="80" r="46" fill="#e07b39"/>'
          '<rect x="340" y="130" width="10" height="60" fill="#8a5a30"/>'
          '<circle cx="345" cy="105" r="30" fill="#f0cf8a"/>')),
      StockMediaItem(name: 'Lake reflection', category: 'Nature',
        svg: _svg('Lake reflection',
          '<rect width="400" height="130" fill="#cfe8ff"/>'
          '<polygon points="0,130 120,50 240,130" fill="#8dbf6a"/>'
          '<polygon points="160,130 320,60 400,130" fill="#6a9a4f"/>'
          '<rect y="130" width="400" height="110" fill="#3a8fd4"/>'
          '<polygon points="120,130 220,130 260,80 200,80" fill="#ffffff" opacity="0.35"/>')),
      StockMediaItem(name: 'Palm beach', category: 'Nature',
        svg: _svg('Palm beach',
          '<rect width="400" height="150" fill="#bfe3f7"/>'
          '<rect y="150" width="400" height="90" fill="#f7e3b0"/>'
          '<rect x="60" y="90" width="10" height="90" fill="#8a5a30"/>'
          '<path d="M65,90 Q40,60 15,70" stroke="#4a7a36" stroke-width="6" fill="none"/>'
          '<path d="M65,90 Q95,60 120,70" stroke="#4a7a36" stroke-width="6" fill="none"/>'
          '<path d="M65,90 Q65,55 70,40" stroke="#4a7a36" stroke-width="6" fill="none"/>'
          '<circle cx="320" cy="70" r="26" fill="#ffd93d"/>')),
      StockMediaItem(name: 'Volcano', category: 'Nature',
        svg: _svg('Volcano',
          '<rect width="400" height="240" fill="#fdeee0"/>'
          '<polygon points="0,240 130,110 260,240" fill="#b0653a"/>'
          '<polygon points="160,240 280,120 400,240" fill="#8a4a2a"/>'
          '<path d="M185,120 Q195,90 205,120" fill="#ff7a45"/>'
          '<rect y="210" width="400" height="30" fill="#6a3a22"/>')),
      StockMediaItem(name: 'Canyon', category: 'Nature',
        svg: _svg('Canyon',
          '<rect width="400" height="240" fill="#fbe8d0"/>'
          '<polygon points="0,0 90,240 0,240" fill="#d9a066"/>'
          '<polygon points="130,0 190,240 90,240" fill="#c98a4a"/>'
          '<polygon points="230,0 300,240 190,240" fill="#b97a3a"/>'
          '<polygon points="320,0 400,240 300,240" fill="#d9a066"/>'
          '<path d="M190,240 Q200,180 210,240" fill="#8a5a30"/>')),
      StockMediaItem(name: 'Meadow flowers', category: 'Nature',
        svg: _svg('Meadow flowers',
          '<rect width="400" height="240" fill="#d8f0d8"/>'
          '<circle cx="60" cy="80" r="12" fill="#ff7a9c"/>'
          '<rect x="59" y="92" width="3" height="40" fill="#4a7a36"/>'
          '<circle cx="160" cy="60" r="12" fill="#ffd93d"/>'
          '<rect x="159" y="72" width="3" height="50" fill="#4a7a36"/>'
          '<circle cx="270" cy="90" r="12" fill="#c98ae8"/>'
          '<rect x="269" y="102" width="3" height="40" fill="#4a7a36"/>'
          '<circle cx="350" cy="70" r="12" fill="#ff7a9c"/>'
          '<rect x="349" y="82" width="3" height="45" fill="#4a7a36"/>'
          '<rect y="170" width="400" height="70" fill="#8dbf6a"/>')),
      StockMediaItem(name: 'Waterfall', category: 'Nature',
        svg: _svg('Waterfall',
          '<rect width="400" height="240" fill="#e4f2fb"/>'
          '<rect x="60" y="0" width="60" height="160" fill="#5a7a3a"/>'
          '<path d="M75,150 Q60,190 80,240" stroke="#8bc1f0" stroke-width="14" fill="none"/>'
          '<rect x="250" y="0" width="60" height="180" fill="#5a7a3a"/>'
          '<path d="M265,170 Q250,210 270,240" stroke="#8bc1f0" stroke-width="14" fill="none"/>'
          '<rect y="205" width="400" height="35" fill="#3a8fd4"/>')),
      StockMediaItem(name: 'Iceberg', category: 'Nature',
        svg: _svg('Iceberg',
          '<rect width="400" height="240" fill="#d6ecf8"/>'
          '<rect y="170" width="400" height="70" fill="#3a8fd4"/>'
          '<polygon points="90,170 180,40 260,170" fill="#ffffff"/>'
          '<polygon points="120,170 180,70 230,170" fill="#bfe3f7"/>'
          '<polygon points="260,170 320,90 400,170" fill="#eef7fc"/>'
          '<polygon points="290,170 320,110 360,170" fill="#bfe3f7"/>')),
      StockMediaItem(name: 'Forest mist', category: 'Nature',
        svg: _svg('Forest mist',
          '<rect width="400" height="240" fill="#e6efe4"/>'
          '<polygon points="30,180 80,80 130,180" fill="#5a7a3a"/>'
          '<polygon points="100,180 160,60 220,180" fill="#4a6a30"/>'
          '<polygon points="190,180 250,90 310,180" fill="#5a7a3a"/>'
          '<polygon points="280,180 340,70 400,180" fill="#4a6a30"/>'
          '<rect y="160" width="400" height="18" fill="#ffffff" opacity="0.55"/>'
          '<rect y="185" width="400" height="14" fill="#ffffff" opacity="0.4"/>'
          '<rect y="210" width="400" height="30" fill="#6a8a4a"/>')),
    ];

List<StockMediaItem> _business() => [
      StockMediaItem(name: 'Bar chart teal', category: 'Business',
        svg: _svg('Bar chart teal',
          '<rect x="40" y="40" width="320" height="160" fill="#ffffff" stroke="#c9d4e4"/>'
          '<rect x="70" y="150" width="26" height="50" fill="#2a9d8f"/>'
          '<rect x="120" y="110" width="26" height="90" fill="#43b0a3"/>'
          '<rect x="170" y="130" width="26" height="70" fill="#5fc3b7"/>'
          '<rect x="220" y="80" width="26" height="120" fill="#2a9d8f"/>'
          '<rect x="270" y="100" width="26" height="100" fill="#43b0a3"/>')),
      StockMediaItem(name: 'Bar chart purple', category: 'Business',
        svg: _svg('Bar chart purple',
          '<rect x="40" y="40" width="320" height="160" fill="#ffffff" stroke="#c9d4e4"/>'
          '<rect x="70" y="120" width="26" height="80" fill="#7a4ab4"/>'
          '<rect x="120" y="90" width="26" height="110" fill="#9463cf"/>'
          '<rect x="170" y="140" width="26" height="60" fill="#b18ae0"/>'
          '<rect x="220" y="70" width="26" height="130" fill="#7a4ab4"/>'
          '<rect x="270" y="100" width="26" height="100" fill="#9463cf"/>')),
      StockMediaItem(name: 'Line chart green', category: 'Business',
        svg: _svg('Line chart green',
          '<rect x="40" y="40" width="320" height="160" fill="#ffffff" stroke="#c9d4e4"/>'
          '<path d="M60,160 L100,130 L140,145 L190,100 L240,115 L290,70 L340,85" stroke="#4a9d5f" stroke-width="4" fill="none"/>'
          '<circle cx="60" cy="160" r="5" fill="#4a9d5f"/>'
          '<circle cx="190" cy="100" r="5" fill="#4a9d5f"/>'
          '<circle cx="290" cy="70" r="5" fill="#4a9d5f"/>')),
      StockMediaItem(name: 'Donut chart', category: 'Business',
        svg: _svg('Donut chart',
          '<rect x="100" y="40" width="200" height="160" fill="#ffffff" stroke="#c9d4e4"/>'
          '<circle cx="200" cy="120" r="60" fill="none" stroke="#e8eef5" stroke-width="34"/>'
          '<path d="M200,60 A60,60 0 0 1 260,120" stroke="#3a8fd4" stroke-width="34" fill="none"/>'
          '<path d="M260,120 A60,60 0 0 1 190,175" stroke="#f7b733" stroke-width="34" fill="none"/>'
          '<path d="M190,175 A60,60 0 0 1 140,120" stroke="#6bcb77" stroke-width="34" fill="none"/>')),
      StockMediaItem(name: 'Pie chart', category: 'Business',
        svg: _svg('Pie chart',
          '<rect x="100" y="40" width="200" height="160" fill="#ffffff" stroke="#c9d4e4"/>'
          '<circle cx="200" cy="120" r="64" fill="#e8eef5"/>'
          '<path d="M200,120 L200,56 A64,64 0 0 1 262,150 Z" fill="#3a8fd4"/>'
          '<path d="M200,120 L262,150 A64,64 0 0 1 160,170 Z" fill="#f7b733"/>'
          '<path d="M200,120 L160,170 A64,64 0 0 1 200,56 Z" fill="#6bcb77"/>')),
      StockMediaItem(name: 'Kanban board', category: 'Business',
        svg: _svg('Kanban board',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<rect x="30" y="40" width="100" height="150" rx="6" fill="#ffffff" stroke="#c9d4e4"/>'
          '<rect x="40" y="52" width="80" height="16" rx="4" fill="#3a8fd4"/>'
          '<rect x="40" y="80" width="70" height="10" rx="4" fill="#e8eef5"/>'
          '<rect x="40" y="100" width="80" height="10" rx="4" fill="#e8eef5"/>'
          '<rect x="150" y="40" width="100" height="150" rx="6" fill="#ffffff" stroke="#c9d4e4"/>'
          '<rect x="160" y="52" width="80" height="16" rx="4" fill="#f7b733"/>'
          '<rect x="160" y="80" width="80" height="10" rx="4" fill="#e8eef5"/>'
          '<rect x="270" y="40" width="100" height="150" rx="6" fill="#ffffff" stroke="#c9d4e4"/>'
          '<rect x="280" y="52" width="80" height="16" rx="4" fill="#6bcb77"/>'
          '<rect x="280" y="80" width="60" height="10" rx="4" fill="#e8eef5"/>')),
      StockMediaItem(name: 'Dashboard metrics', category: 'Business',
        svg: _svg('Dashboard metrics',
          '<rect width="400" height="240" fill="#1c2440"/>'
          '<rect x="30" y="30" width="160" height="80" rx="8" fill="#2c3a60"/>'
          '<rect x="38" y="42" width="50" height="8" rx="4" fill="#6aa9e8"/>'
          '<circle cx="70" cy="80" r="16" fill="none" stroke="#3a8fd4" stroke-width="6"/>'
          '<path d="M70,80 L70,64 A16,16 0 0 1 86,80" stroke="#8bc1f0" stroke-width="6" fill="none"/>'
          '<rect x="210" y="30" width="160" height="80" rx="8" fill="#2c3a60"/>'
          '<rect x="218" y="42" width="50" height="8" rx="4" fill="#f7b733"/>'
          '<rect x="218" y="70" width="90" height="16" rx="4" fill="#f7b733"/>'
          '<rect x="30" y="130" width="160" height="80" rx="8" fill="#2c3a60"/>'
          '<rect x="38" y="142" width="50" height="8" rx="4" fill="#6bcb77"/>'
          '<path d="M40,200 L90,170 L130,185 L190,150" stroke="#6bcb77" stroke-width="4" fill="none"/>'
          '<rect x="210" y="130" width="160" height="80" rx="8" fill="#2c3a60"/>'
          '<rect x="218" y="142" width="50" height="8" rx="4" fill="#c98ae8"/>'
          '<rect x="218" y="170" width="70" height="10" rx="4" fill="#8bc1f0"/>'
          '<rect x="218" y="186" width="100" height="10" rx="4" fill="#8bc1f0"/>')),
      StockMediaItem(name: 'Target focus', category: 'Business',
        svg: _svg('Target focus',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<circle cx="200" cy="120" r="70" fill="none" stroke="#c9d4e4" stroke-width="8"/>'
          '<circle cx="200" cy="120" r="44" fill="none" stroke="#3a8fd4" stroke-width="8"/>'
          '<circle cx="200" cy="120" r="20" fill="#f7b733"/>'
          '<path d="M200,40 L200,20 M200,200 L200,220 M60,120 L40,120 M340,120 L360,120" stroke="#6aa9e8" stroke-width="4"/>')),
      StockMediaItem(name: 'Growth arrow', category: 'Business',
        svg: _svg('Growth arrow',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<path d="M60,180 L120,140 L170,160 L230,110 L290,130 L340,80" stroke="#c9d4e4" stroke-width="4" fill="none"/>'
          '<path d="M60,190 L120,150 L170,170 L230,120 L290,140 L340,90" stroke="#4a9d5f" stroke-width="5" fill="none"/>'
          '<polygon points="340,90 320,95 330,110" fill="#4a9d5f"/>')),
      StockMediaItem(name: 'Money stack', category: 'Business',
        svg: _svg('Money stack',
          '<rect width="400" height="240" fill="#fdf6ec"/>'
          '<rect x="140" y="100" width="120" height="80" rx="8" fill="#8fbf6a"/>'
          '<rect x="130" y="86" width="120" height="80" rx="8" fill="#a9d08a"/>'
          '<rect x="150" y="72" width="120" height="80" rx="8" fill="#c9e3b0"/>'
          '<circle cx="210" cy="112" r="20" fill="#fdf6ec"/>'
          '<path d="M210,100 A12,12 0 0 1 210,124" stroke="#8a6a2a" stroke-width="3" fill="none"/>')),
      StockMediaItem(name: 'Bank building', category: 'Business',
        svg: _svg('Bank building',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<polygon points="200,50 60,120 340,120" fill="#8aa4cf"/>'
          '<rect x="80" y="120" width="240" height="90" fill="#ffffff" stroke="#c9d4e4"/>'
          '<rect x="120" y="150" width="30" height="60" fill="#3a8fd4"/>'
          '<rect x="185" y="150" width="30" height="60" fill="#3a8fd4"/>'
          '<rect x="250" y="150" width="30" height="60" fill="#3a8fd4"/>')),
      StockMediaItem(name: 'Wallet', category: 'Business',
        svg: _svg('Wallet',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<rect x="70" y="80" width="260" height="120" rx="12" fill="#7a4ab4"/>'
          '<rect x="70" y="80" width="260" height="50" rx="12" fill="#9463cf"/>'
          '<rect x="240" y="130" width="70" height="40" rx="6" fill="#c98ae8"/>'
          '<circle cx="290" cy="150" r="8" fill="#eef2f7"/>')),
      StockMediaItem(name: 'Invoice document', category: 'Business',
        svg: _svg('Invoice document',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<rect x="120" y="40" width="160" height="180" rx="6" fill="#ffffff" stroke="#c9d4e4"/>'
          '<rect x="135" y="60" width="90" height="12" rx="4" fill="#3a8fd4"/>'
          '<rect x="135" y="85" width="130" height="8" rx="4" fill="#e8eef5"/>'
          '<rect x="135" y="103" width="130" height="8" rx="4" fill="#e8eef5"/>'
          '<rect x="135" y="121" width="100" height="8" rx="4" fill="#e8eef5"/>'
          '<rect x="135" y="160" width="60" height="24" rx="4" fill="#6bcb77"/>')),
      StockMediaItem(name: 'Milestone flag', category: 'Business',
        svg: _svg('Milestone flag',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<rect x="120" y="40" width="12" height="180" fill="#8a5a30"/>'
          '<polygon points="132,44 260,70 132,96" fill="#f7b733"/>'
          '<polygon points="132,106 240,132 132,158" fill="#3a8fd4"/>'
          '<circle cx="126" cy="220" r="10" fill="#6bcb77"/>')),
    ];

List<StockMediaItem> _technology() => [
      StockMediaItem(name: 'Code window dark', category: 'Technology',
        svg: _svg('Code window dark',
          '<rect width="400" height="240" fill="#1c2440"/>'
          '<rect x="60" y="50" width="280" height="150" rx="6" fill="#2c3a60"/>'
          '<circle cx="80" cy="70" r="6" fill="#ff7a9c"/>'
          '<circle cx="100" cy="70" r="6" fill="#ffd93d"/>'
          '<circle cx="120" cy="70" r="6" fill="#6bcb77"/>'
          '<text x="80" y="110" font-family="monospace" font-size="14" fill="#8bc1f0">&lt;code&gt;</text>'
          '<text x="80" y="135" font-family="monospace" font-size="14" fill="#c98ae8">fn main() {</text>'
          '<text x="100" y="160" font-family="monospace" font-size="14" fill="#f7b733">return 0;</text>'
          '<text x="80" y="185" font-family="monospace" font-size="14" fill="#c98ae8">}</text>')),
      StockMediaItem(name: 'Cloud sync', category: 'Technology',
        svg: _svg('Cloud sync',
          '<rect width="400" height="240" fill="#e4f2fb"/>'
          '<path d="M100,180 Q60,180 70,140 Q80,100 130,100 Q140,60 190,60 Q240,60 250,100 Q300,110 295,150 Q290,180 250,180 Z" fill="#ffffff" stroke="#c9d4e4"/>'
          '<path d="M200,130 L220,110 L240,130" stroke="#3a8fd4" stroke-width="4" fill="none"/>'
          '<path d="M220,110 L220,170" stroke="#3a8fd4" stroke-width="4" fill="none"/>'
          '<circle cx="260" cy="170" r="12" fill="#3a8fd4"/>'
          '<path d="M252,178 L248,166 M268,178 L272,166" stroke="#3a8fd4" stroke-width="3"/>')),
      StockMediaItem(name: 'Server rack', category: 'Technology',
        svg: _svg('Server rack',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<rect x="120" y="40" width="160" height="170" rx="8" fill="#2c3a60"/>'
          '<rect x="135" y="55" width="130" height="22" rx="4" fill="#3a4a78"/>'
          '<circle cx="245" cy="66" r="5" fill="#6bcb77"/>'
          '<rect x="135" y="90" width="130" height="22" rx="4" fill="#3a4a78"/>'
          '<circle cx="245" cy="101" r="5" fill="#f7b733"/>'
          '<rect x="135" y="125" width="130" height="22" rx="4" fill="#3a4a78"/>'
          '<circle cx="245" cy="136" r="5" fill="#6bcb77"/>'
          '<rect x="135" y="160" width="130" height="22" rx="4" fill="#3a4a78"/>'
          '<circle cx="245" cy="171" r="5" fill="#6bcb77"/>')),
      StockMediaItem(name: 'Database', category: 'Technology',
        svg: _svg('Database',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<ellipse cx="200" cy="80" rx="90" ry="34" fill="#6aa9e8"/>'
          '<path d="M110,80 L110,160 A90,34 0 0 0 290,160 L290,80" fill="#3a8fd4"/>'
          '<ellipse cx="200" cy="160" rx="90" ry="34" fill="#8bc1f0"/>'
          '<path d="M110,120 L110,160 A90,34 0 0 0 290,160 L290,120" fill="#5a9ad8"/>')),
      StockMediaItem(name: 'Circuit chip', category: 'Technology',
        svg: _svg('Circuit chip',
          '<rect width="400" height="240" fill="#1c2440"/>'
          '<rect x="140" y="70" width="120" height="100" rx="10" fill="#2c3a60" stroke="#3a8fd4" stroke-width="3"/>'
          '<rect x="170" y="100" width="60" height="40" rx="4" fill="#6aa9e8"/>'
          '<rect x="140" y="85" width="10" height="20" fill="#f7b733"/>'
          '<rect x="250" y="85" width="10" height="20" fill="#f7b733"/>'
          '<rect x="140" y="135" width="10" height="20" fill="#f7b733"/>'
          '<rect x="250" y="135" width="10" height="20" fill="#f7b733"/>'
          '<rect x="155" y="70" width="20" height="10" fill="#f7b733"/>'
          '<rect x="225" y="70" width="20" height="10" fill="#f7b733"/>'
          '<rect x="155" y="160" width="20" height="10" fill="#f7b733"/>'
          '<rect x="225" y="160" width="20" height="10" fill="#f7b733"/>')),
      StockMediaItem(name: 'Robot assistant', category: 'Technology',
        svg: _svg('Robot assistant',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<rect x="140" y="70" width="120" height="100" rx="16" fill="#8bc1f0"/>'
          '<rect x="150" y="100" width="30" height="16" rx="6" fill="#1c2440"/>'
          '<rect x="220" y="100" width="30" height="16" rx="6" fill="#1c2440"/>'
          '<rect x="190" y="130" width="20" height="10" rx="4" fill="#1c2440"/>'
          '<rect x="160" y="55" width="12" height="30" rx="6" fill="#6aa9e8"/>'
          '<rect x="228" y="55" width="12" height="30" rx="6" fill="#6aa9e8"/>')),
      StockMediaItem(name: 'Drone', category: 'Technology',
        svg: _svg('Drone',
          '<rect width="400" height="240" fill="#e4f2fb"/>'
          '<circle cx="200" cy="130" r="26" fill="#3a8fd4"/>'
          '<circle cx="200" cy="130" r="10" fill="#ffffff"/>'
          '<rect x="100" y="127" width="90" height="6" fill="#2a70b4"/>'
          '<rect x="210" y="127" width="90" height="6" fill="#2a70b4"/>'
          '<rect x="197" y="40" width="6" height="80" fill="#2a70b4"/>'
          '<rect x="197" y="140" width="6" height="80" fill="#2a70b4"/>'
          '<circle cx="110" cy="40" r="10" fill="#f7b733"/>'
          '<circle cx="290" cy="40" r="10" fill="#f7b733"/>'
          '<circle cx="110" cy="220" r="10" fill="#f7b733"/>'
          '<circle cx="290" cy="220" r="10" fill="#f7b733"/>')),
      StockMediaItem(name: 'Satellite dish', category: 'Technology',
        svg: _svg('Satellite dish',
          '<rect width="400" height="240" fill="#1c2440"/>'
          '<circle cx="200" cy="140" r="70" fill="none" stroke="#3a8fd4" stroke-width="6"/>'
          '<path d="M200,140 L260,60" stroke="#6aa9e8" stroke-width="5"/>'
          '<circle cx="260" cy="60" r="8" fill="#f7b733"/>'
          '<rect x="185" y="210" width="30" height="20" rx="4" fill="#2c3a60"/>')),
      StockMediaItem(name: 'WiFi signal', category: 'Technology',
        svg: _svg('WiFi signal',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<path d="M120,110 Q200,50 280,110" stroke="#3a8fd4" stroke-width="8" fill="none"/>'
          '<path d="M150,145 Q200,100 250,145" stroke="#5a9ad8" stroke-width="8" fill="none"/>'
          '<path d="M180,180 Q200,160 220,180" stroke="#8bc1f0" stroke-width="8" fill="none"/>'
          '<circle cx="200" cy="200" r="9" fill="#3a8fd4"/>')),
      StockMediaItem(name: 'Smart home', category: 'Technology',
        svg: _svg('Smart home',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<polygon points="200,60 110,130 290,130" fill="#6aa9e8"/>'
          '<rect x="130" y="130" width="140" height="90" fill="#ffffff" stroke="#c9d4e4"/>'
          '<rect x="180" y="160" width="40" height="60" fill="#3a8fd4"/>'
          '<circle cx="200" cy="100" r="10" fill="#f7b733"/>')),
      StockMediaItem(name: 'Battery charge', category: 'Technology',
        svg: _svg('Battery charge',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<rect x="80" y="90" width="230" height="70" rx="10" fill="none" stroke="#2c3a60" stroke-width="5"/>'
          '<rect x="315" y="105" width="20" height="40" rx="4" fill="#2c3a60"/>'
          '<rect x="86" y="96" width="150" height="58" rx="5" fill="#6bcb77"/>'
          '<polygon points="200,110 170,130 190,130 170,150 210,125 190,125" fill="#ffffff"/>')),
      StockMediaItem(name: 'Fingerprint scan', category: 'Technology',
        svg: _svg('Fingerprint scan',
          '<rect width="400" height="240" fill="#1c2440"/>'
          '<path d="M150,90 A60,60 0 0 1 250,90" stroke="#6aa9e8" stroke-width="6" fill="none"/>'
          '<path d="M140,100 A75,75 0 0 1 260,100" stroke="#8bc1f0" stroke-width="5" fill="none"/>'
          '<path d="M155,115 A55,55 0 0 1 245,115" stroke="#6aa9e8" stroke-width="5" fill="none"/>'
          '<path d="M170,130 A40,40 0 0 1 230,130" stroke="#8bc1f0" stroke-width="5" fill="none"/>'
          '<path d="M180,145 A25,25 0 0 1 220,145" stroke="#6aa9e8" stroke-width="5" fill="none"/>')),
    ];

List<StockMediaItem> _education() => [
      StockMediaItem(name: 'Books stack open', category: 'Education',
        svg: _svg('Books stack open',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<rect x="120" y="120" width="160" height="20" rx="4" fill="#3a8fd4"/>'
          '<rect x="110" y="90" width="180" height="22" rx="4" fill="#f7b733"/>'
          '<rect x="130" y="56" width="140" height="26" rx="4" fill="#c98ae8"/>'
          '<path d="M200,56 L210,40 L220,56" fill="#c98ae8"/>')),
      StockMediaItem(name: 'Graduation cap alt', category: 'Education',
        svg: _svg('Graduation cap alt',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<polygon points="200,60 60,130 200,200 340,130" fill="#7a4ab4"/>'
          '<polygon points="200,60 60,130 200,130 340,130" fill="#9463cf"/>'
          '<rect x="190" y="170" width="20" height="40" rx="6" fill="#7a4ab4"/>'
          '<circle cx="200" cy="60" r="8" fill="#f7b733"/>')),
      StockMediaItem(name: 'Lab flask', category: 'Education',
        svg: _svg('Lab flask',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<path d="M170,60 L230,60 L250,110 L290,190 Q290,210 260,210 L140,210 Q110,210 110,190 L150,110 Z" fill="none" stroke="#3a8fd4" stroke-width="6"/>'
          '<path d="M160,140 L240,140" stroke="#8bc1f0" stroke-width="8" fill="none"/>'
          '<path d="M150,170 L250,170" stroke="#8bc1f0" stroke-width="6" fill="none"/>'
          '<path d="M170,200 L240,200" stroke="#8bc1f0" stroke-width="5" fill="none"/>')),
      StockMediaItem(name: 'Globe', category: 'Education',
        svg: _svg('Globe',
          '<rect width="400" height="240" fill="#e4f2fb"/>'
          '<circle cx="200" cy="120" r="70" fill="#8bc1f0"/>'
          '<ellipse cx="200" cy="120" rx="28" ry="70" fill="none" stroke="#2a70b4" stroke-width="3"/>'
          '<path d="M130,120 L270,120" stroke="#2a70b4" stroke-width="3"/>'
          '<path d="M140,90 L260,150 M140,150 L260,90" stroke="#2a70b4" stroke-width="3"/>'
          '<path d="M60,190 Q130,230 340,190" stroke="#6a9a4f" stroke-width="10" fill="none"/>')),
      StockMediaItem(name: 'Pencil ruler', category: 'Education',
        svg: _svg('Pencil ruler',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<rect x="150" y="60" width="30" height="120" rx="4" fill="#f7b733" transform="rotate(20 165 120)"/>'
          '<polygon points="180,150 200,190 160,170" fill="#8a5a30" transform="rotate(20 180 170)"/>'
          '<rect x="120" y="120" width="140" height="26" rx="4" fill="#ffffff" stroke="#c9d4e4"/>'
          '<rect x="130" y="128" width="4" height="10" fill="#3a8fd4"/>'
          '<rect x="160" y="128" width="4" height="10" fill="#3a8fd4"/>'
          '<rect x="190" y="128" width="4" height="10" fill="#3a8fd4"/>'
          '<rect x="220" y="128" width="4" height="10" fill="#3a8fd4"/>')),
      StockMediaItem(name: 'Abacus', category: 'Education',
        svg: _svg('Abacus',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<rect x="110" y="90" width="180" height="12" fill="#c98a4a"/>'
          '<rect x="110" y="130" width="180" height="12" fill="#c98a4a"/>'
          '<rect x="110" y="170" width="180" height="12" fill="#c98a4a"/>'
          '<rect x="140" y="70" width="10" height="130" fill="#c98a4a"/>'
          '<rect x="200" y="70" width="10" height="130" fill="#c98a4a"/>'
          '<rect x="260" y="70" width="10" height="130" fill="#c98a4a"/>'
          '<circle cx="170" cy="100" r="8" fill="#3a8fd4"/>'
          '<circle cx="230" cy="100" r="8" fill="#f7b733"/>'
          '<circle cx="170" cy="140" r="8" fill="#6bcb77"/>'
          '<circle cx="230" cy="180" r="8" fill="#c98ae8"/>')),
      StockMediaItem(name: 'School building', category: 'Education',
        svg: _svg('School building',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<polygon points="200,50 90,110 310,110" fill="#8aa4cf"/>'
          '<rect x="110" y="110" width="180" height="100" fill="#ffffff" stroke="#c9d4e4"/>'
          '<rect x="140" y="140" width="40" height="70" fill="#3a8fd4"/>'
          '<rect x="220" y="140" width="40" height="70" fill="#3a8fd4"/>'
          '<rect x="185" y="130" width="30" height="30" fill="#f7b733"/>'
          '<rect x="60" y="210" width="280" height="12" fill="#c9d4e4"/>')),
      StockMediaItem(name: 'Award medal', category: 'Education',
        svg: _svg('Award medal',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<circle cx="200" cy="110" r="46" fill="#f7b733"/>'
          '<circle cx="200" cy="110" r="30" fill="#ffd93d"/>'
          '<circle cx="200" cy="110" r="12" fill="#ffffff"/>'
          '<path d="M165,150 L150,210 L185,195 L200,215 L215,195 L250,210 L235,150" fill="#c98a4a"/>')),
      StockMediaItem(name: 'Brain science', category: 'Education',
        svg: _svg('Brain science',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<path d="M200,80 Q140,60 130,100 Q120,140 160,150 L160,190 L200,200 L240,190 L240,150 Q280,140 270,100 Q260,60 200,80 Z" fill="#c98ae8"/>'
          '<path d="M200,80 L200,200" stroke="#9463cf" stroke-width="4" fill="none"/>'
          '<circle cx="160" cy="120" r="8" fill="#ffffff"/>'
          '<circle cx="240" cy="120" r="8" fill="#ffffff"/>')),
      StockMediaItem(name: 'Open book', category: 'Education',
        svg: _svg('Open book',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<path d="M200,180 Q140,150 80,160 L80,80 Q140,70 200,100 Z" fill="#6aa9e8"/>'
          '<path d="M200,180 Q260,150 320,160 L320,80 Q260,70 200,100 Z" fill="#3a8fd4"/>'
          '<path d="M200,100 L200,180" stroke="#2a70b4" stroke-width="3"/>')),
      StockMediaItem(name: 'Online class', category: 'Education',
        svg: _svg('Online class',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<rect x="90" y="60" width="220" height="130" rx="8" fill="#1c2440"/>'
          '<circle cx="150" cy="110" r="16" fill="#8bc1f0"/>'
          '<rect x="130" y="135" width="40" height="20" rx="8" fill="#8bc1f0"/>'
          '<rect x="230" y="95" width="50" height="8" rx="4" fill="#f7b733"/>'
          '<rect x="230" y="115" width="60" height="8" rx="4" fill="#6bcb77"/>'
          '<polygon points="310,120 350,100 350,140" fill="#f7b733"/>')),
    ];

List<StockMediaItem> _abstractItems() => [
      StockMediaItem(name: 'Gradient sunrise', category: 'Abstract',
        svg: _svg('Gradient sunrise',
          '<rect width="400" height="240" fill="#ff9a9e"/>'
          '<rect y="60" width="400" height="60" fill="#fad0c4"/>'
          '<rect y="120" width="400" height="60" fill="#fbc2eb"/>'
          '<rect y="180" width="400" height="60" fill="#a18cd1"/>'
          '<circle cx="200" cy="180" r="40" fill="#ffffff" opacity="0.85"/>')),
      StockMediaItem(name: 'Gradient ocean', category: 'Abstract',
        svg: _svg('Gradient ocean',
          '<rect width="400" height="240" fill="#a1c4fd"/>'
          '<rect y="60" width="400" height="60" fill="#c2e9fb"/>'
          '<rect y="120" width="400" height="60" fill="#84fab0"/>'
          '<rect y="180" width="400" height="60" fill="#8fd3f4"/>'
          '<path d="M0,180 Q100,150 200,180 T400,180 L400,240 L0,240 Z" fill="#ffffff" opacity="0.5"/>')),
      StockMediaItem(name: 'Geometric neon', category: 'Abstract',
        svg: _svg('Geometric neon',
          '<rect width="400" height="240" fill="#1c2440"/>'
          '<polygon points="200,40 340,130 260,220 140,220 60,130" fill="#3a8fd4" opacity="0.85"/>'
          '<polygon points="200,80 300,140 240,200 160,200 100,140" fill="#8bc1f0"/>'
          '<polygon points="200,115 260,150 225,180 175,180 140,150" fill="#f7b733"/>')),
      StockMediaItem(name: 'Geometric pastel', category: 'Abstract',
        svg: _svg('Geometric pastel',
          '<rect width="400" height="240" fill="#fdf6ec"/>'
          '<circle cx="110" cy="90" r="60" fill="#ffd9e2"/>'
          '<circle cx="230" cy="130" r="70" fill="#d9e8ff"/>'
          '<circle cx="310" cy="90" r="45" fill="#d9f2e0"/>'
          '<rect x="80" y="160" width="240" height="40" rx="20" fill="#f3e6ff"/>')),
      StockMediaItem(name: 'Abstract waves dark', category: 'Abstract',
        svg: _svg('Abstract waves dark',
          '<rect width="400" height="240" fill="#1c2440"/>'
          '<path d="M0,80 Q50,40 100,80 T200,80 T300,80 T400,80" stroke="#3a8fd4" stroke-width="8" fill="none"/>'
          '<path d="M0,130 Q50,90 100,130 T200,130 T300,130 T400,130" stroke="#5a9ad8" stroke-width="8" fill="none"/>'
          '<path d="M0,180 Q50,140 100,180 T200,180 T300,180 T400,180" stroke="#8bc1f0" stroke-width="8" fill="none"/>')),
      StockMediaItem(name: 'Spiral motion', category: 'Abstract',
        svg: _svg('Spiral motion',
          '<rect width="400" height="240" fill="#fdf6ec"/>'
          '<path d="M200,120 A20,20 0 0 1 220,120 A40,40 0 0 1 180,120 A60,60 0 0 1 240,120 A80,80 0 0 1 160,120" stroke="#f7b733" stroke-width="6" fill="none"/>')),
      StockMediaItem(name: 'Particles', category: 'Abstract',
        svg: _svg('Particles',
          '<rect width="400" height="240" fill="#1c2440"/>'
          '<circle cx="80" cy="60" r="5" fill="#8bc1f0"/>'
          '<circle cx="150" cy="120" r="8" fill="#f7b733"/>'
          '<circle cx="240" cy="70" r="4" fill="#6bcb77"/>'
          '<circle cx="300" cy="150" r="10" fill="#c98ae8"/>'
          '<circle cx="90" cy="190" r="6" fill="#ff7a9c"/>'
          '<circle cx="220" cy="190" r="5" fill="#8bc1f0"/>'
          '<circle cx="340" cy="60" r="7" fill="#ffd93d"/>'
          '<circle cx="180" cy="40" r="3" fill="#ffffff"/>')),
      StockMediaItem(name: 'Cube isometric', category: 'Abstract',
        svg: _svg('Cube isometric',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<polygon points="200,60 300,110 200,160 100,110" fill="#6aa9e8"/>'
          '<polygon points="200,60 100,110 100,160 200,210 300,160 300,110" fill="none"/>'
          '<polygon points="100,110 100,160 200,210 200,160" fill="#3a8fd4"/>'
          '<polygon points="300,110 300,160 200,210 200,160" fill="#8bc1f0"/>')),
      StockMediaItem(name: 'Rings', category: 'Abstract',
        svg: _svg('Rings',
          '<rect width="400" height="240" fill="#1c2440"/>'
          '<circle cx="140" cy="120" r="50" fill="none" stroke="#3a8fd4" stroke-width="8"/>'
          '<circle cx="210" cy="120" r="50" fill="none" stroke="#f7b733" stroke-width="8"/>'
          '<circle cx="175" cy="100" r="50" fill="none" stroke="#6bcb77" stroke-width="8"/>')),
      StockMediaItem(name: 'Dots grid', category: 'Abstract',
        svg: _svg('Dots grid',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<g fill="#3a8fd4">'
          '<circle cx="80" cy="60" r="8"/><circle cx="140" cy="60" r="8"/><circle cx="200" cy="60" r="8"/><circle cx="260" cy="60" r="8"/><circle cx="320" cy="60" r="8"/>'
          '<circle cx="80" cy="120" r="8"/><circle cx="140" cy="120" r="8"/><circle cx="200" cy="120" r="8"/><circle cx="260" cy="120" r="8"/><circle cx="320" cy="120" r="8"/>'
          '<circle cx="80" cy="180" r="8"/><circle cx="140" cy="180" r="8"/><circle cx="200" cy="180" r="8"/><circle cx="260" cy="180" r="8"/><circle cx="320" cy="180" r="8"/>'
          '</g>')),
      StockMediaItem(name: 'Confetti', category: 'Abstract',
        svg: _svg('Confetti',
          '<rect width="400" height="240" fill="#fdf6ec"/>'
          '<rect x="60" y="50" width="12" height="12" fill="#ff7a9c" transform="rotate(20 66 56)"/>'
          '<rect x="130" y="90" width="14" height="14" fill="#f7b733" transform="rotate(45 137 97)"/>'
          '<rect x="210" y="50" width="12" height="12" fill="#6bcb77" transform="rotate(-15 216 56)"/>'
          '<rect x="280" y="100" width="14" height="14" fill="#3a8fd4" transform="rotate(30 287 107)"/>'
          '<rect x="340" y="60" width="10" height="10" fill="#c98ae8" transform="rotate(-40 345 65)"/>'
          '<rect x="100" y="150" width="12" height="12" fill="#3a8fd4" transform="rotate(60 106 156)"/>'
          '<rect x="180" y="170" width="12" height="12" fill="#ff7a9c" transform="rotate(-25 186 176)"/>'
          '<rect x="260" y="150" width="12" height="12" fill="#f7b733" transform="rotate(50 266 156)"/>')),
      StockMediaItem(name: 'Bokeh lights', category: 'Abstract',
        svg: _svg('Bokeh lights',
          '<rect width="400" height="240" fill="#2c1a4a"/>'
          '<circle cx="90" cy="80" r="26" fill="#f7b733" opacity="0.7"/>'
          '<circle cx="170" cy="140" r="18" fill="#ff9a9e" opacity="0.6"/>'
          '<circle cx="260" cy="70" r="30" fill="#3a8fd4" opacity="0.6"/>'
          '<circle cx="320" cy="150" r="14" fill="#6bcb77" opacity="0.7"/>'
          '<circle cx="140" cy="200" r="10" fill="#c98ae8" opacity="0.6"/>'
          '<circle cx="230" cy="190" r="22" fill="#8bc1f0" opacity="0.5"/>')),
      StockMediaItem(name: 'Gradient purple', category: 'Abstract',
        svg: _svg('Gradient purple',
          '<rect width="400" height="240" fill="#8a2be2"/>'
          '<rect y="60" width="400" height="60" fill="#b066e8"/>'
          '<rect y="120" width="400" height="60" fill="#d9a5f2"/>'
          '<rect y="180" width="400" height="60" fill="#f3d5fb"/>'
          '<circle cx="200" cy="120" r="36" fill="#ffffff" opacity="0.5"/>')),
      StockMediaItem(name: 'Gradient fire', category: 'Abstract',
        svg: _svg('Gradient fire',
          '<rect width="400" height="240" fill="#f12711"/>'
          '<rect y="60" width="400" height="60" fill="#f5af19"/>'
          '<rect y="120" width="400" height="60" fill="#f7971e"/>'
          '<rect y="180" width="400" height="60" fill="#ffd200"/>'
          '<path d="M200,80 Q220,120 200,150 Q180,120 200,80 Z" fill="#ffffff" opacity="0.6"/>')),
      StockMediaItem(name: 'Triangles pattern', category: 'Abstract',
        svg: _svg('Triangles pattern',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<polygon points="60,40 120,100 0,100" fill="#3a8fd4" opacity="0.7"/>'
          '<polygon points="140,20 200,80 80,80" fill="#6bcb77" opacity="0.7"/>'
          '<polygon points="220,60 300,130 160,130" fill="#f7b733" opacity="0.7"/>'
          '<polygon points="300,20 380,90 240,90" fill="#c98ae8" opacity="0.7"/>'
          '<polygon points="60,140 140,210 0,210" fill="#ff7a9c" opacity="0.6"/>'
          '<polygon points="200,150 280,220 140,220" fill="#5a9ad8" opacity="0.6"/>')),
      StockMediaItem(name: 'Abstract flow', category: 'Abstract',
        svg: _svg('Abstract flow',
          '<rect width="400" height="240" fill="#f0f8ff"/>'
          '<path d="M0,140 Q80,80 160,140 T320,140 T400,120" stroke="#3a8fd4" stroke-width="10" fill="none" opacity="0.8"/>'
          '<path d="M0,180 Q80,120 160,180 T320,180 T400,160" stroke="#6bcb77" stroke-width="10" fill="none" opacity="0.8"/>'
          '<path d="M0,220 Q80,160 160,220 T320,220 T400,200" stroke="#c98ae8" stroke-width="10" fill="none" opacity="0.7"/>')),
      StockMediaItem(name: 'Gradient sunset', category: 'Abstract',
        svg: _svg('Gradient sunset',
          '<defs><linearGradient id="gs" x1="0" y1="0" x2="0" y2="1">'
          '<stop offset="0%" stop-color="#3a2a60"/><stop offset="50%" stop-color="#ff7a9c"/>'
          '<stop offset="100%" stop-color="#ffd93d"/>'
          '</linearGradient></defs><rect width="400" height="240" fill="url(#gs)"/>'
          '<circle cx="300" cy="160" r="26" fill="#ffffff" opacity="0.85"/>')),
      StockMediaItem(name: 'Molecule', category: 'Abstract',
        svg: _svg('Molecule',
          '<rect width="400" height="240" fill="#f5f7fa"/>'
          '<circle cx="200" cy="120" r="14" fill="#ff7a9c"/>'
          '<circle cx="130" cy="70" r="10" fill="#3a8fd4"/>'
          '<circle cx="280" cy="70" r="10" fill="#6bcb77"/>'
          '<circle cx="130" cy="180" r="10" fill="#f7b733"/>'
          '<circle cx="280" cy="180" r="10" fill="#c98ae8"/>'
          '<path d="M188,112 L138,78 M212,112 L272,78 M188,128 L138,172 M212,128 L272,172" stroke="#c9d4e4" stroke-width="5"/>')),
    ];

List<StockMediaItem> _people() => [
      StockMediaItem(name: 'Avatar teal', category: 'People',
        svg: _svg('Avatar teal',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<circle cx="200" cy="100" r="52" fill="#5fc3b7"/>'
          '<circle cx="200" cy="92" r="20" fill="#ffffff" opacity="0.9"/>'
          '<path d="M96,230 Q96,160 200,160 Q304,160 304,230" fill="#3a9d8f"/>')),
      StockMediaItem(name: 'Avatar indigo', category: 'People',
        svg: _svg('Avatar indigo',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<circle cx="200" cy="100" r="52" fill="#7a4ab4"/>'
          '<rect x="178" y="80" width="22" height="8" rx="4" fill="#ffffff" opacity="0.9"/>'
          '<rect x="200" y="80" width="22" height="8" rx="4" fill="#ffffff" opacity="0.9"/>'
          '<circle cx="188" cy="96" r="6" fill="#ffffff"/>'
          '<circle cx="212" cy="96" r="6" fill="#ffffff"/>'
          '<path d="M96,230 Q96,160 200,160 Q304,160 304,230" fill="#5a3090"/>')),
      StockMediaItem(name: 'Avatar rose', category: 'People',
        svg: _svg('Avatar rose',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<circle cx="200" cy="100" r="52" fill="#ff9a9e"/>'
          '<path d="M180,80 Q188,60 196,80" fill="#ffffff" opacity="0.9"/>'
          '<path d="M204,80 Q212,60 220,80" fill="#ffffff" opacity="0.9"/>'
          '<circle cx="188" cy="96" r="6" fill="#ffffff"/>'
          '<circle cx="212" cy="96" r="6" fill="#ffffff"/>'
          '<path d="M96,230 Q96,160 200,160 Q304,160 304,230" fill="#e06070"/>')),
      StockMediaItem(name: 'Team circle', category: 'People',
        svg: _svg('Team circle',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<circle cx="150" cy="100" r="30" fill="#8bc1f0"/>'
          '<circle cx="250" cy="100" r="30" fill="#f7b733"/>'
          '<circle cx="200" cy="130" r="26" fill="#6bcb77"/>'
          '<path d="M100,220 Q100,150 150,150 Q200,150 200,220" fill="#8bc1f0"/>'
          '<path d="M200,220 Q200,160 250,160 Q300,160 300,220" fill="#f7b733"/>'
          '<path d="M160,220 Q160,170 200,170 Q240,170 240,220" fill="#6bcb77"/>')),
      StockMediaItem(name: 'Office desk', category: 'People',
        svg: _svg('Office desk',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<rect x="60" y="120" width="280" height="14" rx="4" fill="#c98a4a"/>'
          '<rect x="80" y="134" width="14" height="70" fill="#8a5a30"/>'
          '<rect x="306" y="134" width="14" height="70" fill="#8a5a30"/>'
          '<rect x="90" y="70" width="60" height="44" rx="4" fill="#3a8fd4"/>'
          '<rect x="170" y="80" width="90" height="8" rx="4" fill="#c9d4e4"/>'
          '<rect x="170" y="98" width="70" height="8" rx="4" fill="#c9d4e4"/>'
          '<rect x="280" y="90" width="40" height="24" rx="4" fill="#f7b733"/>')),
      StockMediaItem(name: 'Video call', category: 'People',
        svg: _svg('Video call',
          '<rect width="400" height="240" fill="#1c2440"/>'
          '<rect x="60" y="60" width="220" height="130" rx="8" fill="#2c3a60"/>'
          '<circle cx="130" cy="110" r="18" fill="#8bc1f0"/>'
          '<rect x="105" y="135" width="50" height="24" rx="10" fill="#8bc1f0"/>'
          '<polygon points="280,90 340,70 340,180 280,160" fill="#3a8fd4"/>'
          '<rect x="150" y="20" width="100" height="16" rx="8" fill="#6bcb77"/>')),
      StockMediaItem(name: 'Interview', category: 'People',
        svg: _svg('Interview',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<circle cx="120" cy="100" r="34" fill="#8bc1f0"/>'
          '<path d="M70,220 Q70,160 120,160 Q170,160 170,220" fill="#6aa9e8"/>'
          '<circle cx="280" cy="100" r="34" fill="#f7b733"/>'
          '<path d="M230,220 Q230,160 280,160 Q330,160 330,220" fill="#e0a830"/>'
          '<rect x="200" y="120" width="80" height="40" rx="8" fill="#ffffff" stroke="#c9d4e4"/>'
          '<rect x="215" y="132" width="50" height="8" rx="4" fill="#c9d4e4"/>'
          '<rect x="215" y="146" width="35" height="6" rx="3" fill="#c9d4e4"/>')),
      StockMediaItem(name: 'Applause', category: 'People',
        svg: _svg('Applause',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<circle cx="130" cy="90" r="30" fill="#8bc1f0"/>'
          '<path d="M85,220 Q85,160 130,160 Q175,160 175,220" fill="#6aa9e8"/>'
          '<circle cx="270" cy="90" r="30" fill="#f7b733"/>'
          '<path d="M225,220 Q225,160 270,160 Q315,160 315,220" fill="#e0a830"/>'
          '<rect x="185" y="90" width="30" height="14" rx="6" fill="#ff7a9c"/>'
          '<rect x="165" y="110" width="70" height="14" rx="6" fill="#ff9a9e"/>')),
      StockMediaItem(name: 'Phone conversation', category: 'People',
        svg: _svg('Phone conversation',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<path d="M150,80 Q150,50 180,50 L210,50 Q240,50 240,80 L240,170 Q240,200 210,200 L180,200 Q150,200 150,170 Z" fill="#3a8fd4"/>'
          '<path d="M175,70 L215,70 M175,180 L215,180" stroke="#ffffff" stroke-width="4"/>'
          '<path d="M255,90 Q290,120 290,120 Q290,120 255,150" stroke="#6bcb77" stroke-width="5" fill="none"/>')),
      StockMediaItem(name: 'Onboarding', category: 'People',
        svg: _svg('Onboarding',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<circle cx="160" cy="100" r="40" fill="#8bc1f0"/>'
          '<path d="M100,230 Q100,170 160,170 Q220,170 220,230" fill="#6aa9e8"/>'
          '<rect x="250" y="80" width="80" height="90" rx="8" fill="#ffffff" stroke="#c9d4e4"/>'
          '<rect x="262" y="94" width="56" height="10" rx="4" fill="#3a8fd4"/>'
          '<rect x="262" y="114" width="56" height="8" rx="4" fill="#e8eef5"/>'
          '<rect x="262" y="130" width="40" height="8" rx="4" fill="#e8eef5"/>'
          '<circle cx="290" cy="160" r="8" fill="#6bcb77"/>')),
      StockMediaItem(name: 'Two users', category: 'People',
        svg: _svg('Two users',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<circle cx="140" cy="95" r="38" fill="#8bc1f0"/>'
          '<path d="M85,225 Q85,160 140,160 Q195,160 195,225" fill="#6aa9e8"/>'
          '<circle cx="270" cy="95" r="38" fill="#c98ae8"/>'
          '<path d="M215,225 Q215,160 270,160 Q325,160 325,225" fill="#b18ae0"/>')),
      StockMediaItem(name: 'Celebration', category: 'People',
        svg: _svg('Celebration',
          '<rect width="400" height="240" fill="#fdf6ec"/>'
          '<circle cx="170" cy="140" r="16" fill="#8bc1f0"/>'
          '<circle cx="230" cy="140" r="16" fill="#f7b733"/>'
          '<circle cx="200" cy="115" r="14" fill="#6bcb77"/>'
          '<rect x="160" y="170" width="80" height="10" rx="4" fill="#c9d4e4"/>'
          '<path d="M40,80 L60,60 M120,50 L130,30 M340,80 L360,60 M290,40 L300,25" stroke="#f7b733" stroke-width="4"/>'
          '<circle cx="80" cy="50" r="5" fill="#ff7a9c"/>'
          '<circle cx="310" cy="40" r="5" fill="#3a8fd4"/>')),
      StockMediaItem(name: 'Family together', category: 'People',
        svg: _svg('Family together',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<circle cx="120" cy="90" r="28" fill="#8bc1f0"/>'
          '<path d="M75,220 Q75,160 120,160 Q165,160 165,220" fill="#6aa9e8"/>'
          '<circle cx="280" cy="90" r="28" fill="#f7b733"/>'
          '<path d="M235,220 Q235,160 280,160 Q325,160 325,220" fill="#e0a830"/>'
          '<circle cx="200" cy="110" r="22" fill="#c98ae8"/>'
          '<path d="M170,220 Q170,175 200,175 Q230,175 230,220" fill="#b18ae0"/>')),
      StockMediaItem(name: 'Avatar gold', category: 'People',
        svg: _svg('Avatar gold',
          '<rect width="400" height="240" fill="#fdf6ec"/>'
          '<circle cx="200" cy="100" r="52" fill="#f7b733"/>'
          '<path d="M96,230 Q96,160 200,160 Q304,160 304,230" fill="#e0a830"/>')),
      StockMediaItem(name: 'Interview desk', category: 'People',
        svg: _svg('Interview desk',
          '<rect width="400" height="240" fill="#eef2f7"/>'
          '<rect x="40" y="60" width="140" height="120" rx="8" fill="#ffffff" stroke="#c9d4e4"/>'
          '<circle cx="110" cy="100" r="20" fill="#8bc1f0"/>'
          '<path d="M80,180 Q80,140 110,140 Q140,140 140,180" fill="#6aa9e8"/>'
          '<rect x="220" y="60" width="140" height="120" rx="8" fill="#fdf6ec"/>'
          '<circle cx="290" cy="100" r="20" fill="#f7b733"/>'
          '<path d="M260,180 Q260,140 290,140 Q320,140 320,180" fill="#e0a830"/>'
          '<path d="M150,110 L220,110 M150,130 L220,130" stroke="#c9d4e4" stroke-width="3"/>')),
    ];
