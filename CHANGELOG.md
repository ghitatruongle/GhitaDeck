# Changelog

## [2.0.5-beta.2] - 2026-09-02 — T16: Quality & Ship beta2

- **Coverage 52,7%** (ex-generated l10n, ≥52.5% gate) — từ 52,1% baseline, nhờ ~25 test hồi quy mới (B1–B24, T14, T15).
- **Toàn bộ danh sách xanh:** flutter test **1109/1109 ×3**, `cargo test` **11/11**, `flutter analyze` **0 issue**, `dart run tool/l10n_audit.dart` **CLEAN** (EN=VI key sets khớp).
- **Privacy:** 0-TCP trên Release exe (probe 8 s) — không socket ngoài; log audit engine local.
- **Version đúng 3 chỗ + grep ALL:** `pubspec.yaml 2.0.5-beta.2+6`, `BuildInfo.appVersion/coreVersion 2.0.5-beta.2` + buildNumber 6, `installer/ghita_ppt_installer.iss 2.0.5-beta.2+6` (grep ALL test/ không còn pin beta.1).
- **Installer:** `GhitaPPT-Setup-2.0.5-beta.2.exe` — 15,59 MB, SHA-256 `2c1e1e0149157e2417e5b3e1a103132a0cde5f6d209b2faeb582a7cfe3cfaa22`, manifest `version 2.0.5-beta.2+6` (NotSigned — như beta1). Cài đè real beta1→beta2 chờ user test trên máy (mục T16.7).

## [2.0.5-beta.2] - 2026-09-02 — T15: Hoàn thiện trải nghiệm N1/N2/N3

- **i18n thật sự cho export dialog:** tên định dạng / tỷ lệ / chất lượng qua l10n (EN+VI); summary snackbar theo format (DOCX không còn liệt kê tùy chọn bị bỏ qua); đếm slide/anh có plural đúng ("1 slide/image" vs "N slides/images").
- **DOCX UX:** các tùy chọn không áp dụng (tỷ lệ, chất lượng, fit-content, backgrounds) bị ẩn thay vì để người dùng đặt rồi âm thầm bỏ qua.
- **N3:** status bar (Slide N/M, trạng thái Đang xuất/Đã xuất, từ khóa) theo locale — trước đây hiện tiếng Việt cả khi UI tiếng Anh; badge ngôn ngữ dùng tên locale thật.
- **A11y:** progress export là live region (screen reader đọc cập nhật); cancel có tooltip (dùng key `exportCancelDescription` trước đây chết); Semantics status bar localized.
- **Nhất quán phím tắt:** bỏ claim "(Ctrl+1)" và "(Ctrl+F)" không có binding thật; mojibake "ΓêÆ" ở nút trừ zoom → "−".
- **Command palette:** hint + empty state localize (EN/VI).
- Tests: status_bar_i18n_test (3), settings hint (T14), analyzer 0 issue.

## [2.0.5-beta.2] - 2026-09-02 — T14: Fallback & độ bền engine

- **Audit log engine** (`lib/services/engine_audit_log.dart`): mọi lần init/fallback ghi `%APPDATA%\GhitaPPT\engine.log` — local, không PII, không network, best-effort.
- **Thông báo + hướng dẫn:** card Engine ở Settings thêm dòng gợi ý khi fallback (i18n EN/VI) — "ứng dụng vẫn chạy bằng Dart, kiểm tra cài đặt rồi khởi động lại".
- **Wrong-version guard:** version rỗng từ crate (mọi đường init, kể cả fake) không bao giờ được nhận là ready.
- **Docs:** mục "Engine & Fallback Architecture" trong README (hub single-flight, hợp đồng fallback, UI-isolate rule, cách test).
- Tests: wrong-version + audit ready/fallback + Settings hint (widget).

## [2.0.5-beta.2] - 2026-09-02 — T12: Bug sweep beta (24/24 bug xử lý)

- **P1 ×1 · P2 ×10 · P3 ×13** — toàn bộ bảng bug T12.5 (3 sweep nội bộ N1/N3 · N2 image · Rust engine) đã sửa, mỗi bug có test hồi quy.
- **Ảnh / EXIF:** xác minh `package:image` bake EXIF lúc decode (comment cũ sai → sửa); ma trận `applyExifOrientation` 2–8 khớp reference `bakeOrientation` (5/7 trước đây hoán đổi nhau — B3/B15); **hợp đồng "EXIF always baked"** chốt cả 2 backend (B16: JPEG có EXIF không bao giờ passthrough bytes thô); bomb guard đọc header PNG/JPEG/GIF trước decode (B19); SVG/WebP/BMP drop với warning đúng nguyên nhân (B21).
- **Cache ảnh:** key = FNV-1a(content bytes) + options + **backend tag** (B18/B20) — ảnh sửa nội dung tự reprocess, remote fetch-first, eviction cap 600, sidecar sha256 nhỏ, ghi atomic (B22/B23); cache hit vẫn đếm savings (B24).
- **Engine:** hub single-flight `RustBridgeInit` (B6c) — zip/image/htmlparse/UI service chung MỘT `RustLib.init()`; lỗi "initialize twice" = DLL đã load → `rustReady` không fallback vĩnh viễn (B2); worker chờ readiness đầu job — cả job 1 engine (B6b); renderer UI isolate luôn Dart (B6a); zip.rs: level 0 = Stored, hết ZIP64 vô điều kiện (B4/B5).
- **N1/N3:** DOCX qua worker isolate với per-slide progress + cancel + heading theo outline level + title sạch control char (B10/B12/B11); generator viết `<out>.part` → rename atomic — cancel/timeout không bao giờ để file bán phần hay phá file cũ (B7/B8); progress HTML theo vòng build (B9); preparing/per-slide đếm thống nhất khi có slide hidden, dialog hết "N+1/N" (B13/B14).
- **Suite:** 1104/1104 ×2, `cargo test` 11/11, integration probe (DLL thật) 5/5 với 0 log "falling back — twice"; `flutter analyze` 0 issue.

## [2.0.5-beta.2] - 2026-09-02 — T13: ghita_htmlparse — Rust tokenizer một-lượt (GO theo số)

- **Profile T13.1 xác nhận GO (gate ≥15%):** deck 100 slide parse chiếm **17,3%** (40 unique) / **16,0%** (100 unique) / **19,5%** (80 text + 20 ảnh) tổng thời gian export pptx (`tool/t13_parse_profile_test.dart`).
- **Module `ghita_htmlparse`** (`rust/src/api/htmlparse.rs`, html5ever + markup5ever_rcdom 0.39 + serde_json): tokenizer một-lượt tái tạo **chính xác** `_extractBlocks` (Dart) — 4 artifact: blocks / blocksNoFirstH2 / notes / subtitle → JSON cho Dart decode.
- **Facade `HtmlParseCodec`** (`lib/services/html_parse_codec.dart`): `HtmlParseEngineConfig` (engine chọn theo Settings, default Rust sau GO) + `parseToJson` trả null → **Dart fallback**; decode sâu tái tạo `Map<String, String>` cho runs/items/cells.
- **Wire 1 điểm:** `HtmlParseCache._entryFor` (call site duy nhất PPTX/PDF/HTML); worker isolate seed từ `engineRustPreferred`; `RustEngineService` markRustReady cả 3 config.
- **Parity test `test/htmlparse_parity_test.dart` PASS** — 8 template thật + 40 edge-case, deep-equal giữa 2 đường. Đã vá 3 divergence thật trong vòng đua (aside.notes strip trước extract · fallback blocks rỗng · whitespace collapse đúng `replaceAll(\s+, ' ')`).
- **Kết quả đo (deck 100 slide, máy local):** total **261,2 ms → 135,8 ms** (100 unique, **-28,7%**); 40 unique **-15,6%**; deck 80/20 ảnh không đổi (bottleneck ảnh — đã tối ưu T06). parseMs = 0 trên đường Rust (đo riêng Dart parser).
- **6b NO-GO có số:** zip stage chỉ **1,7%** tổng export (129 ms/7479 ms) trên deck 21 MB media → bỏ qua streaming file→file (không đạt ≥15%); T02.7 được xác nhận.
- Suite full **1077/1077** · `flutter analyze` 0 · l10n audit CLEAN.

## [2.0.5-beta.2] - 2026-09-02 — T17: Template refresh F3 (5 mẫu mới)

- **15 mockup (5 bộ × 3 layout) tái thiết kế** tại `tool/template_mockups/` — bản template cũ (business/creative/academic/marketing/minimal) bị đánh giá yếu: chữ viền ngoài div nền, không inline color, không dùng được thực tế trên nền sáng (slide_preview stylesheet ép chữ sáng).
- **5 bộ mới được duyệt qua mockup, chọn layout Content (B):** mỗi bộ 1 slide trực quan trong WebView preview — Business 3 KPI cell (+18% / 12 / 96%), Creative 3 trụ cột (01/02/03), Academic heading + 3 bullet dot, Marketing 3 kênh (Social 40% / KOL 35% / In-store 25%), Minimal (nền sáng #F7F9F4) 3 bullet dòng việc.
- **Hợp đồng template áp cho cả 5:** mọi text element có `color` inline (ép chữ sáng của slide_preview không thể thắng được inline); `data-bg-color` giữ trên container; chỉ dùng tag parser hỗ trợ (h1–h6/p/ul/ol/li/table/tr/td/th/strong/b/em/i/span/br) + `aside.notes` (parser strip); font hệ thống, không asset ngoài → installer không phình.
- **i18n:** 10 key mới EN=VI vào `.arb` (`templateName*` / `templateDescription*` cho 5 bộ), gen-l10n, Template Studio (=card grid + detail dialog + search) hiển thị tên/mô tả bằng locality; chuỗi hardcode `'Applied ... template!'` trong `applyTemplate` lên key `templateAppliedTemplateNotice`.
- **Title extraction:** `_extractTitleFromHtml` fallback h1 → **h2** (template mới không dùng h1, trước đó title = "New Slide").
- **Kiểm chứng bằng số:** pixel-check nền 5/5 PNG khớp hex gốc (System.Drawing) · preview render 125%/150% không tràn · `test/template_refresh_test.dart` **7/7 xanh** (5 template parse + inline color + 20 template cũ không regression + export PPTX/PDF/HTML cho cả 5 không lỗi, file >0 byte) · `flutter analyze` 0.
- Ma trận template mới + ảnh mockup: `tool/template_mockups/T17_mockups.md`.

## [2.0.5-beta.1] - 2026-09-01 — T11: Sweep thông báo toàn app (F1 đóng 100%)

- **Toàn bộ ~111 chỗ `showSnackBar` thô → `showAppSnackBar`** (mọi màn: AI Chat, Home, Settings, Theme, Provider, Shortcuts, Export dialogs (advanced/m6/m9), Animation pane, Sorter, Wizard, Collaboration, Presenter, Ribbon, Text layout…). Hiệu ứng: replace thật (`clearSnackBars`) + `persist:false` (tự tắt đúng duration) + không xếp hàng toàn app.
- **Không còn chuỗi thông báo hardcode** — ~60 chuỗi EN/VI mới bổ sung vào `.arb` (key `*Notice`, gen-l10n, l10n audit CLEAN; placeholder String/int đúng type).
- **Grep gate (T11.7):** `0 showSnackBar` thô trong `lib/` (chỉ còn helper) · `0 literal chuỗi thông báo` trong call helper (trừ biến động/exception text) · `flutter analyze` 0.
- Chuyên biến thể: `messenger.*` capture trước pop → helper; chuỗi nối 2 phần + `??` biểu thức; theme `_showSnackBar` wrapper chuyển qua helper; async-gap guarded (ignore có lý do ở 1 chỗ wizard).
- CHANGELOG T11 + đánh dấu F1 "đủ 100% toàn app" trong RELEASE_PLAN.

## [2.0.5-beta.1] - 2026-09-01 — T09: Tối ưu thuật toán & tăng tốc (đo trước/sau)
## [2.0.5-beta.1] - 2026-09-01 — T09: Tối ưu thuật toán & tăng tốc (đo trước/sau)

- **Re-run toàn bộ benchmark** (t01/t02/t07/media) kèm nhãn beta1; tóm tắt + bảng hotspot mới: `tool/benchmark_results_beta1.md`.
- **Hotspot bằng số (deck 20 slide):** parse 3,0→**0,0 ms** khi cache ấm · build XML 23,3→8,1 ms · ZIP 29,3→19,4 ms · tổng PPTX **58,3→30,9 ms** · PDF 422 ms · HTML 114 ms.
- **Chi phí lớn nhất mốc = xử lý ảnh** (8,47 s/72 MB Dart) → **Rust batch/rayon 8,51×** (đã chốt default Rust cho ảnh, T06/T07) — được hưởng lợi bởi cache đĩa processed (T07.5).
- **Loại bỏ tối ưu không chứng minh được:** không refactor build XML/player trong mốc (số đo không ủng hộ); streaming zip API hoãn (media deck Rust kém do FRB copy — T02). Ghi lý do có số trong bảng quyết định.

## [2.0.5-beta.1] - 2026-09-01 — T08: N3 Instant Export (progress + cancel hoàn chỉnh)
## [2.0.5-beta.1] - 2026-09-01 — T08: N3 Instant Export (progress + cancel hoàn chỉnh)

- **Progress đầy đủ 3 định dạng**: PPTX/PDF/HTML báo "Đang xuất… x/y" + bar tiến độ ngay trong Advanced Export dialog (onProgress xuyên `run*ExportInIsolate` → `exportWithOptions` → dialog); HTML service giờ báo progress theo slide (đã thiếu trước đó) + `finalizing`; DOCX báo preparing/finalizing/done (single-shot).
- **Nút "Hủy xuất"** trong khi xuất: `ExportCancelToken` chung 3 định dạng, hủy → worker dừng giữa chừng, host xóa file bán phần (không có file trước đó), snackbar "Đã hủy xuất." (key `exportCancelled` mới EN/VI).
- **Kiểm chứng** (`test/export_progress_cancel_test.dart` 3 test): progress đầu tiên đến **<100 ms** khi xuất deck 100 slide (gate T08.7); cancel giữa chừng deck 200 slide → `ExportCancelledException`, **không file partial, thư mục sạch** (T08.8); HTML per-slide → finalizing (T08.5). `flutter analyze` 0.

## [2.0.5-beta.1] - 2026-09-01 — T07: N2 Image Optimizer hoàn chỉnh
## [2.0.5-beta.1] - 2026-09-01 — T07: N2 Image Optimizer hoàn chỉnh

- **Gỡ nhãn beta** — Settings → Engine: "Tối ưu ảnh" thành tùy chọn thường (key prefs cũ `app_image_optimizer_beta` giữ nguyên để prefs cũ carry over); mô tả cập nhật.
- **Chất lượng theo ExportQuality (150/300/600)** — `ImageOptimizerConfig.qualityForExport`: low→60, medium→80, high→95 (JPEG re-encode); chip chất lượng trong Advanced Export giờ điều khiển cả độ nét và dung lượng ảnh tối ưu; worker isolate nhận `imageJpegQuality` qua job message (host cũng set trước khi xuất).
- **UI thống kê trước/sau** — thông báo sau xuất đổi sang dạng `"4.462 KB → 2.053 KB (54%) (N ảnh)"`; thống kê worker vẫn ưu tiên.
- **Cache đĩa ảnh đã xử lý** — `HtmlImageLoader` cache processed bytes theo hash(src+opts) xuống `%LOCALAPPDATA%\GhitaPPT\image_cache\proc_*` (sidecar json); cùng ảnh + cùng tùy chọn không decode/lập encode lại mỗi lần xuất; cache hỏng → xử lý lại.
- **Backend ghita_image** cho đường N2 (T06): batch/rayon nơi tối ưu hàng loạt; sequential per-embed; → `tool/benchmark_results_image.md`.
- **Đối chiếu Rust vs Dart (T07 P6, gate đã duyệt pixel-diff/PSNR):** byte lệch 3,6 MB · PSNR trung bình 27,9 dB · tệ nhất 16,3 dB (ảnh nhiễu tổng hợp là worst case; ảnh thật PSNR cao hơn). Không ép bit-perfect giữa 2 encoder; đường Dart OFF vẫn bit-perfect như demo.
- **Giữ mốc ≥40%** — test deck 10 ảnh vẫn **54,0%** (4462 KB → 2053 KB); alpha/small giữ PNG; EXIF bake; ảnh hỏng không crash.
- Test: `test/image_optimizer_optimization_test.dart` +2 (quality mapping, disk cache) + format stats mới; `flutter analyze` 0; l10n audit CLEAN (4 key cập nhật EN=VI, gen-l10n).

## [2.0.5-beta.1] - 2026-09-01 — T06: ghita_image (Rust image module)

- **Module `ghita_image`** (crate `image` 0.25 + `rayon` + `sha2`): pipeline xử lý ảnh deterministic — decode (PNG/JPEG/GIF), bake EXIF (orientation 2–8 qua parser TIFF riêng, cả JPEG APP1 + PNG eXIf), resize khi quá rộng, PNG lớn opaque ≥512px → JPEG khi được phép, passthrough GIF/JPEG giữ nguyên byte. Tương đương hành vi đường Dart cũ; `#[frb(sync)]` để gọi từ đường sinh export đồng bộ; batch API `img_process_batch` chạy song song (rayon).
- **Facade `ImageCodec`** fallback tự động: Rust khi engine chọn Rust + DLL sẵn sàng trong isolate; lỗi bất kỳ → rơi về Dart. `HtmlImageLoader._process` chuyển toàn bộ pipeline cho `ImageCodec`; thống kê tiết kiệm giữ nguyên quy tắc. Engine một switch Settings → zip + image; worker isolate khởi động Rust cho ảnh ngay khi nhận job.
- **Kết quả đo (tool/benchmark_results_image.md, 20 ảnh 72,1 MB):** Dart 9,99 s · Rust tuần tự 5,06 s (1,97×) · **Rust batch/rayon 1,14 s (8,74×)**. Gate ≥3× **đạt ở đường batch** (chính là đường N2 optimizer dùng); tuần tự 1,97× vẫn nhanh hơn. **Default engine ảnh = Rust** (đo được), zip giữ Dart-default (đo T02); switch Settings ghi đè cả hai khi người dùng chọn.
- **Dedupe PPTX**: đã có từ Track 03 P4 (mediaByContentKey + SHA-256) — kiểm chứng tiếp bởi probe round-trip qua DLL thật.
- Test: crate Rust **8/8**; `test/image_codec_test.dart` **10/10**; benchmark tool chạy mỗi suite (khóa sàn).

## [2.0.5-demo] - đang phát triển — T04: N2 Image Optimizer v2 (beta flag)

- **Tối ưu ảnh (beta)** trong Settings → Engine: bật "Image optimizer (beta)" để điều khiển chất lượng tối ưu ảnh khi xuất (PNG lớn không trong suốt ≥512px → JPEG; PNG trong suốt giữ nguyên; EXIF luôn được xoay đúng). Tắt = hành vi cũ **bit-perfect** (đã test: hai lần xuất cùng byte). Trạng thái bật/tắt persist qua SharedPreferences, truyền qua worker isolate trong job message.
- **Thống kê tiết kiệm**: sau mỗi lần xuất thành công, snackbar hiện "Tiết kiệm: X KB (Y%) (N ảnh)" (số liệu truyền ngược từ worker qua reply).
- **Kiểm chứng**: deck 10 ảnh PNG nhiễu 600×450 → **tiết kiệm 54,0% (4.462 KB → 2.053 KB)** — đạt gate ≥40% (test khóa trong `test/image_optimizer_optimization_test.dart` 5/5: gate, bit-perfect off, alpha/small giữ PNG, EXIF vẫn bake khi bật flag, ảnh hỏng không crash); `flutter analyze` 0; suite **1034/1034 xanh**; l10n audit CLEAN (3 key mới EN=VI).

## [2.0.5-demo] - đang phát triển — T03: N1 DOCX Report Export

- **Báo cáo Word (.docx)** — tính năng beta chính thức của demo: xuất deck thành báo cáo Word (WordprocessingML, ECMA-376) gồm tiêu đề + nội dung paragraph/list từng slide, ghi chú người trình bày (tùy chọn) và danh sách slide đánh số (tùy chọn). Package tối giản chuẩn: `[Content_Types].xml` + `_rels/.rels` + `word/document.xml` + `docProps/core.xml`; format trực tiếp (bold/size) không tham chiếu styles ngoài nên Word/LibreOffice mở không cần repair. Trong Advanced Export chọn "Word report (.docx)".
- **Kiểm chứng**: unit 6 test (cấu trúc package, escape/tiếng Việt, notes dài + deck 100 slide, tắt tùy chọn, deck rỗng bị từ chối); **mở bằng Microsoft Word 16.0 thật (COM): OPEN_OK, 15 paragraph, chữ đầu "Báo cáo demo" — không repair prompt** (file build/t03_docx_probe.docx).

## [2.0.5-demo] - đang phát triển — T02: ghita_zip (Rust ZIP module)

- **Module `ghita_zip`** (crate `zip` 8.6.0 / zlib-rs): nén ZIP với text deflate mức 9 + media stored — cùng ngữ nghĩa với đường Dart hiện tại; `zip_archive()` + `ZipCodec` facade có fallback tự động, settings vẫn cho chọn Engine. Wire vào đường PPTX (generatePPT/export isolate/dialog xuất) và `.ghita` (saveProjectBundle), worker nhận lựa chọn engine qua job message.
- **Kết quả đo (tool/benchmark_results_media.md, deck 20 slide / 21,1 MB):**
  - Deck media: **Dart 105–119 ms** vs **Rust 132–142 ms** — Rust chậm hơn (FRB copy 21 MB nuốt lợi thế; media stored nên không có gì để nén thêm).
  - Text-only 4,5 MB: **Rust 19,1 ms (nhanh 3,6×)** vs Dart 68,7 ms.
  - **Quyết định theo nguyên tắc "đo rồi mới sửa": mặc định giữ Dart** (đường nhanh đã đo), Rust dùng khi user chọn trong Settings (vẫn có fallback). Đề xuất cải tiến cho beta2: API streaming file→file để bỏ chi phí copy — chỉ làm nếu có lợi theo profile. Gate "media ≥30% nhanh hơn" KHÔNG đạt — ghi nhận trung thực.
- Test: crate Rust 2/2; `test/zip_codec_test.dart` 6 test routing/fallback/round-trip; integration probe **4/4** E2E qua DLL thật (codec round-trip + PPTX encoding đầy đủ + **`.ghita` bundle save→load round-trip**). PPTX engine còn được **mở bằng PowerPoint 16.0 thật (COM): OPEN_OK, không repair prompt** (kill: strict OOXML validation toàn gói chạy trong probe — mọi XML parse, Content_Types phủ đủ, rels resolve); benchmark tool chạy mỗi suite (khóa sàn tính đúng).

## [2.0.5-demo] - đang phát triển — T01: Rust Foundation

- **Rust core** (flutter_rust_bridge 2.13.0 + cargokit): crate `rust/ghita_core` được build cùng app Windows nhờ glue plugin `rust_builder`; CI `ci-windows.yml` cài Rust toolchain trước `flutter build`; installer/`verify_release.ps1` đi kèm `ghita_core.dll`.
- **Settings → Engine**: chọn lõi xử lý Rust (mặc định) hoặc Dart; trạng thái hiển thị phiên bản crate khi Rust sẵn sàng, hoặc lý do fallback.
- **Auto-fallback**: DLL thiếu/hỏng → tự rơi về Dart, không crash; Rust nạp **lazy** khi mở Settings (không chạm đường khởi động, giữ zero-network posture).
- Test đồng bộ: `test/rust_engine_test.dart` (6 test fallback/retry/prefs).

## [2.0.1] - 2026-08-25 — Bản ổn định chính thức

Bản phát hành chính thức đầu tiên sau 2.0.0: hoàn thiện nốt tính năng bảo mật còn treo, một vòng tối ưu hiệu năng/tài nguyên có số đo chứng minh, và gia cố toàn bộ kiểm định. Nền tảng: v2.0.1-beta.2 (đã gồm T01–T06, P1/P1b/P2/P3 — xem mục beta bên dưới).

### 🔐 Bảo mật

- **Wi-Fi broadcast: token chuyển sang phiên cookie (T08)** — share-link `?t=` giờ chỉ là bootstrap credential trên trang entry (`/view`, `/once`), cấp một lần **cookie phiên `ghita_broadcast`** (HttpOnly, SameSite=Strict). Mọi request sau đó (SSE `/events`, `/control`, reload) xác thực bằng cookie hoặc header `X-Ghita-Token`; token trần trên URL của data endpoint bị từ chối 401. Access token không còn lặp lại trong URL, browser history và server log. Luồng người dùng không đổi: QR/link chia sẻ vẫn hoạt động như trước.

### ⚡ Tối ưu hiệu năng & tài nguyên

- **HTML deck gọn hơn 19,7%**: CSS/JS player của video/audio/model3d chỉ được nhúng khi deck thực sự chứa phần tử đó (deck chuẩn 10 slide / 10 ảnh: **25.418 → 20.413 B**, thời gian parse slide đầu **37,4 → 23,4 ms**). Deck có media vẫn giữ nguyên đầy đủ player.
- **Logo app: 468 KB → 30 KB (−93,5%)** — file cũ là JPEG 1024×1024 mang đuôi `.png` trong khi chỉ hiển thị 20×20 px; nay là PNG 128×128 thật. Tổng assets giảm 541 KB → ~103 KB.
- **Gỡ 7 dependencies không dùng** (`uuid`, `cupertino_icons`, `file`, `audioplayers`, `highlight`, `flutter_highlight`, `url_launcher`) — Windows build nhẹ đi theo.
- Mọi tối ưu đều có số đo trước/sau lưu trong `tool/benchmark_results_*.md`; export PPTX ~35 ms / PDF ~270 ms / HTML ~90–100 ms cho deck 20 slide được chốt làm mốc sàn.

### ✅ Chất lượng

- Full suite **1010/1010 test xanh ×2 lần liên tục**; `flutter analyze` 0 issues; l10n audit CLEAN.
- Coverage (ex-generated l10n): **49,8% → 51,0%**; sàn ratchet cho `ai_provider_manager` (58,1%) và `pdf_export_service` (66,0%) giữ vững.
- Sửa bug công cụ release: `verify_release.ps1` đòi tên artifact kèm `+build` trái với quy ước đặt tên của `build_installer.ps1` — đã thống nhất về một quy ước.

## [2.0.1-beta.2] - đang phát triển — P1b: Dọn thanh điều khiển Present

- **Xóa hai nút prev/next** khỏi thanh điều khiển nổi của Present mode: WebView2 là HWND native nuốt toàn bộ click hướng vào lớp Flutter, nên nút bấm không bao giờ ăn; PowerPoint chuẩn cũng điều hướng bằng bàn phím. Thanh chỉ còn bộ đếm "N / M" (+ Auto/Notes khi cấu hình).
- **Điều hướng bàn phím đầy đủ**: mũi tên phải / **lên** / Space / PageDown → slide tiếp; mũi tên trái / **xuống** / PageUp → slide trước; Home/End → đầu/cuối; F → fullscreen (phím dọc mới thêm theo yêu cầu).
- Dọn toàn bộ tham chiếu JS của nút (tránh null crash trong `ghitaShowSlide`); test P9 locale chuyển sang khẳng định trên counter + fullscreen.
- Full suite xanh **1005/1005 × 2 lần liên tục**; `flutter analyze` 0 issues.

## [2.0.1-beta.2] - đang phát triển — T06+P3: PDF Depth & AI Resilience + Performance

- **P3 — Tối ưu tài nguyên & hiệu năng**:
  - Present mode: vòng poll slide thích ứng — 700 ms khi vừa chuyển trang, lùi 1,2 s sau 3 nhịp không đổi và 2 s khi idle (trước đây ping JS 700 ms vĩnh viễn); cadence expose qua `PresentScreen.pollDelay` có test bảng.
  - Boot nhẹ hơn: HomeScreen **không còn pre-warm quét 4 port local-AI** lúc khởi động (bỏ luôn timer nền mà test phải "đốt"); ProviderSettings/AI chat kích hoạt `scanLocalAI()` theo nhu cầu với cache 5 phút sẵn có.
  - Healthcheck AI bỏ qua hoàn toàn khi chưa cấu hình provider nào — không mở socket cho setup rỗng.
- **Benchmark khóa sàn** (`test/p3_performance_test.dart`): player HTML 50 slide < 5 s, 150 slide < 15 s; bảng cadence poll; JSON payload vẫn decode đúng sau escape.
- Full suite xanh **1004/1004 × 2 lần liên tục**; `flutter analyze` 0 issues.
- RAM trong phiên dài (< 150 MB cam kết) nằm trên checklist nghiệm thu thủ công — dart test không đo được RSS một cách khả chuyển.

## [2.0.1-beta.2] - đang phát triển — T06: PDF Depth & AI Resilience

- **PDF bookmarks (outline)**: tùy chọn mới trong Advanced Export — cây `/Outlines` với một mục mỗi slide ("1. Tiêu đề"), nhảy đúng trang đích; hỗ trợ tiêu đề tiếng Việt; catalog tham chiếu chuẩn.
- **Trang ghi chú riêng biệt**: tùy chọn `notesPages` chèn một trang "Slide N · Tiêu đề + Speaker notes" ngay sau mỗi slide có ghi chú (độc lập với `includeNotes` inline hiện giữ nguyên hành vi); cả hai tùy chọn đi hết đường ống ExportOptions → isolate → service, toggle mới trong export dialog với i18n EN=VI.
- **AI resilience chain E2E**: `executeWithFallback` thêm hook `onFallback` (báo mỗi hop thất bại — sẵn sàng cho banner UI) và `shouldStop` (Stop chặn giữa chuỗi, không đụng provider còn lại); test với HTTP loopback thật: relay chết (refused) → relay 500 → Ollama local thành công, breadcrumbs đúng thứ tự, all-fail gom đủ lỗi từng nhà cung cấp.
- **Benchmark smoke**: deck 50 slide xuất PDF ổn định dưới 60 giây (test timeout 3 phút), đúng 50 trang.
- README cập nhật mục Export Formats (bookmarks, notes pages, diagram blocks).
- Phase 8 (bug sweep từ T04): không bug mới nào lộ ra — suite PDF T04 vẫn xanh sau thay đổi.
- Full suite xanh **963/963 × 3 lần liên tục**; `flutter analyze` 0 issues; l10n audit CLEAN.

## [2.0.1-beta.2] - đang phát triển — T05: Mermaid E2E & Boolean Shapes

- **Tính năng Diagram mới**: nút "Diagram" trên ribbon Insert (cạnh SmartArt) mở `DiagramDialog` — chọn Flowchart/Mindmap, nhập bước/nhánh con (thêm/bớt ô động), chọn 1 trong 4 màu nhấn preset, **xem trước cấu trúc trực tiếp** (chips đánh số cùng accent như HTML sẽ chèn), rồi chèn khối HTML vào editor qua `insertHtml`. Toàn bộ chuỗi UI mới vào `.arb` EN=VI (13 key), gen-l10n lại.
- **Theme accent cho diagram**: `MermaidDiagramService` nhận tham số tuỳ chọn `accentColor` (backward-compatible); chỉ chấp nhận `#RRGGBB` hợp lệ — giá trị lạ rơi về màu mặc định thay vì inject markup. Mặc định giữ nguyên màu cũ.
- **Kiểm chứng boolean shapes end-to-end** qua EditorShell thật: merge dialog đã có sẵn từ Track 21 — giờ có widget test luồng chính: ≥2 shape → More tools → Merge shapes → Union → còn 1 shape với `mergeOp: union` → Undo trả lại 2 shape; và case 1 shape được từ chối kèm hint.
- Xuất giữ nguyên diagram: PPTX (slide XML mang text các bước), HTML (khối verbatim + accent), PDF đều có test retention.
- Manual checklist (cho sign-off): kiểm tra dialog + merge trên Windows scaling 100/125/150%.
- Full suite xanh **952/952 × 3 lần liên tục**; `flutter analyze` 0 issues; l10n audit CLEAN.

## [2.0.1-beta.2] - đang phát triển — T04: AI Manager, PDF Export & Coverage Gate

- **Fix bug thật trong streaming AI**: bộ đệm SSE split trên chuỗi literal `\n` thay vì newline thật — event dính nhau trong một chunk không được parse và JSON cắt qua ranh giới chunk bị bỏ đến hết stream (chỉ "may mắn" chạy đúng khi server gói mỗi dòng một chunk). Giờ split theo LF thật; kèm test multi-byte UTF-8 cắt giữa ký tự.
- **Hardening Stop button**: `client.close()` không ngắt được SSE đang chảy — vòng lặp stream giờ tôn trọng cờ `_streamCancelled` từng chunk.
- **Hardening persistence**: `saveSelectedProvider` tự nuốt lỗi (fire-and-forget không bắn unhandled zone error giữa lúc generate).
- Test mới (40): streaming 3 format OpenAI/Anthropic/Gemini với chunk dính/chia lửng, deadline override, cancel mid-stream, multi-slide "Create 3 slides" đúng thứ tự, outline, secure-storage round-trip API key qua reload, system prompt persist, provider CRUD; PDF matrix 24 test (notes, backgrounds, 12 tổ hợp paper×margin, 4:3, scale-to-fit khối nội dung lớn, freeform bezier C/S/Q/T + fill+stroke, funnel chart painter, action button, canvas shapes/freeTexts đầy đủ gradient+effect, kitchen-sink inline styling, màu hỏng fallback, cancel token, progress).
- **Coverage gate dạng ratchet vào CI**: step `flutter test --coverage` + `tool/coverage_summary.dart` in bảng vào GitHub step summary, cảnh báo mềm khi tụt sàn (`ai_provider_manager ≥55%`, `pdf_export_service ≥65%`, repo ≥47% — sàn = giá trị đo hôm nay, mục tiêu 55% cho các track sau).
- Coverage: `ai_provider_manager` 27,6% → **58,8%** ✓, `pdf_export_service` 45,9% → **65,1%** ✓, repo 46,3% → 47,6% (raw) / 49,8% (ex-l10n). Full suite xanh **942/942 × 3 lần liên tục**; analyze 0 issues.

## [2.0.1-beta.2] - đang phát triển — T03: Stateful & AI Support Service Tests

- Xóa sạch danh sách service NO-TEST: bổ sung test riêng cho 7 service — `api_key_rotation_service` (server loopback thật: 200/404 valid, 401 reject, 3 kiểu auth OpenAI/Anthropic/Gemini, connection-refused → statusCode −1), `smart_draft_manager` (round-trip draft, spill >1MB dạng pointer, dọn spill cũ, purge, JSON hỏng degradation, crash recovery qua instance mới), `local_ai_detector_service` (giả lập Ollama 11434 + LM Studio 1234 bằng server thật, đọc models từ `data[].id`, JSON hỏng bị bỏ qua), `effect_preview_service` (dedup keyframe trùng body, class alias, category group đủ mọi effect, mapping PPTX), `stock_media_service` (6 category, ~100 item, search offline, data-URI round-trip), `webview_runtime_service` (mock channel `io.jns.webview.win`: version/null/missing-plugin + state machine recheck), `eyedropper_service` (contract GDI: không bao giờ throw, định dạng #RRGGBB).
- **Phát hiện quan trọng cho test network**: `TestWidgetsFlutterBinding.ensureInitialized()` cài `_MockHttpOverrides` toàn cục khiến mọi HTTP thật trong test nhận 400 rỗng — file test dùng loopback server phải KHÔNG cài binding.
- Full suite xanh **902/902 chạy 3 lần liên tục**; `flutter analyze` 0 issues; chỉ còn 3 file data thuần (`mdi_icons_data`, `speaker_icon_data`, `stock_media_variants`) không cần test.

## [2.0.1-beta.2] - đang phát triển — T02: Pure-Dart Engine Service Tests

- Bổ sung test riêng cho 4 service chưa từng có test: `polygon_boolean` (union/intersect/difference/combine + degenerate/bowtie, coverage **94,9%**), `ppt_chart_writer` (XML bar/line/pie/donut/combo + workbook round-trip, **89,2%**), `ppt_smartart_writer` (data/layout/colors + 20-node stress, **98,0%**), `mermaid_diagram_service` (flowchart/mindmap + escape chống XSS, **100%**).
- Round-trip PPTX end-to-end: slide chứa chart + SmartArt + shape merge xuất PPTX đủ part (`chart1.xml`, `data1.xml`, embeddings, content-types, `dgm:relIds`).
- **Fix bug lộ ra từ test**: (1) `PolygonBoolean.clip` — hole của difference-containment chưa đảo chiều winding như contract ("reversed winding"), gây fill sai với nonzero-rule renderer như custGeom PowerPoint; (2) `PptChartWriter._ser` — padding giá trị thiếu dùng int `0` trong khi `ChartSeries.values` là double, XML in không nhất quán (`0` vs `7.0`).
- Full suite xanh **848/848 chạy 3 lần liên tục**; `flutter analyze` 0 issues.

## [2.0.1-beta.2] - đang phát triển — T01: Presentation State & Editor Lifecycle Tests

- Thêm 46 test mới phủ vòng đời tài liệu: hydrate/readiness, dirty revision + saving state, persistence error path (spill save fail, JSON hỏng, pointer file mất), mutation history undo/redo, họ `upsert*`/shapes/layers/groups, `buildHtmlDeck`.
- Test state machine `EditorState` (selection/scribble/zoom/format painter/handleSlideRemoved) và tích hợp time machine (cap 30 snapshot).
- Widget test `EditorShell`: cổng hydrate loader, thu gọn sidebar, bảng binding Ctrl+S/Ctrl+Z/Ctrl+Y, Ctrl+Enter báo lỗi validate, Ctrl+Shift+C format painter.
- Coverage full suite: `presentation_state` 11,8% → **64,0%**, `editor_state` 16,2% → **73,8%**; full suite xanh 805/805 chạy 3 lần liên tục; `flutter analyze` 0 issues.

## [2.0.1-beta.1] - 2026-08-19 — Stability & Hardening Beta

### Đã triển khai trong đợt beta
- Chuẩn hóa metadata build, version ứng dụng, collaboration protocol và `.ghita` schema.
- Project bundle mới ghi `appVersion` và `schemaVersion`; bundle từ schema tương lai bị từ chối an toàn.
- Presentation lifecycle có readiness, dirty revision, saving state và persistence error để UI không thao tác trước khi hydrate hoàn tất.
- Các mutation slide cốt lõi được ghi history nhất quán hơn; persistence queue và atomic spill-file write giảm rủi ro save race.
- Editor, AI và project loader dùng chung HTML safety policy; AI streaming có overall deadline.
- LAN collaboration có session expiry metadata và authorization hết hạn.
- Windows CI bổ sung l10n audit, build release và artifact upload.

### Kiểm định
- `flutter analyze --no-fatal-infos`: No issues found.
- Full Flutter test suite vẫn cần xử lý Windows runner hang trước khi beta sign-off.

## [2.0.0] - 2026-08-15 — Official Production Release

### 🚀 Phát hành chính thức v2.0.0
- **Chuẩn hóa toàn diện**: Hoàn thành toàn bộ **67 Track (670 Phase)** thuộc 10 Milestone theo đúng kiến trúc Microsoft Office 365.
- **Đa ngôn ngữ chuẩn mực (i18n)**: 100% chuỗi giao diện được nội địa hóa đồng bộ giữa Tiếng Anh và Tiếng Việt (`812/812 keys in sync EN=VI`), xóa sạch hardcode UI.
- **Tối ưu hiệu năng & Vòng đời**:
  - `ReadAloudService`: 1 tiến trình PowerShell SAPI nền bền vững, giao thức base64/stdin chống vỡ UTF-8, dọn dẹp sạch tiến trình khi thoát.
  - `CollaborationService`: Đóng hoàn toàn server HTTP/Socket khi dừng chia sẻ LAN, delta sync và gzip payload tiết kiệm băng thông.
  - `HistoryStorageService`: Diff snapshot nén gzip kết hợp spill file cho deck > 1 MB, kiểm soát RAM dưới 150 MB.
  - `ThumbnailService`: LRU cache 60 ảnh với giải phóng bộ nhớ tự động khi xóa slide.
- **Kiểm định chất lượng**:
  - **739/739 test xanh 100%** · `flutter analyze`: **0 lỗi/cảnh báo** · `tool/l10n_audit.dart`: **CLEAN**.
  - Đóng gói cài đặt Inno Setup Windows: `GhitaPPT-Setup-2.0.0.exe`.

## [2.0.0-beta] - 2026-08-15 — Tối ưu theo track (M1–M10)

### ⚡ Tối ưu đã áp dụng

- **T62 — `ReadAloudService` viết lại**: trước đây mỗi slide trong `speakDeck` spawn **1 process PowerShell mới** (~0.5s khởi động/slide → deck 50 slide lãng phí ~25s). Nay dùng **1 process PowerShell bền vững + giao thức stdin** (base64 line ↔ phản hồi `OK`): khởi động đúng 1 lần, đọc cả deck liền mạch; **Pause/Resume giờ là SAPI thật** (`Pause()`/`Resume()`) thay vì kill/restart; `STOP` dùng `SpeakAsyncCancelAll`; set `[Console]::OutputEncoding` UTF-8 để tránh lỗi UTF-16 trên stdout redirect (đã kiểm chứng protocol bằng PowerShell thật).
- **T66 — `importPptx`**: số thứ tự slide được trích **1 lần/file** thay vì tạo `RegExp(r'\d+')` trong từng lần so sánh của sort (bỏ O(n·log n) regex allocation).
- **T65 — OPT 25–30 nối production** (đợt deep review trước): deck > 1 MB spill file, lazy AI scan post-frame + cache 5 phút, healthcheck song song + khoảng lặp thích ứng, `loadProviders` post-frame.

### 🔍 Đã rà & giữ nguyên (đánh giá không đáng đổi)
- `HtmlParseCache._entryFor` parse DOM 2 lần (có/không h2) — nằm trong cache 1 lần/slide, đổi rủi ro > lợi ích.
- Image pipeline decode full-size trước resize — chuẩn của package:image; đã có 3 tầng cache.
- `SpellcheckService.suggest` quét cả từ điển — từ điển nhỏ, gọi 1 lần/dialog.
- Inline RegExp ở đường cold (import/one-shot) — không phải hot path.

### 🧪 Kiểm định
- **732/732 test xanh** · **flutter analyze: No issues found** · i18n 800/800.

## [2.0.0-beta] - 2026-08-15 — Deep review M1–M10 (xác nhận 100%)

### 🐛 Bug thật sửa trong đợt rà soát chuyên sâu

- **`AIPipelineService.repairJsonArray`** — 2 lỗi: (1) mảng cắt ngang với dấu phẩy cuối (`[{...}, {...},`) sinh JSON lỗi `FormatException` — giờ strip dấu phẩy cuối trước khi đóng; (2) object `{` chưa đóng bị đóng bằng `]` sai loại — giờ dùng stack mở-ngoặc và đóng **bằng đúng ký tự khớp** (`{`→`}`, `[`→`]`), đồng thời tính lại stack sau khi truncate.
- **`AdvancedImportService` (T66)** — bảng markdown có pipe trong inline code (`` `x|y` ``) bị tách thành 3 cột sai — `_splitTableRow` mới phân biệt pipe trong backtick.
- **`SpellcheckService.checkText` (T57)** — entity HTML (`&amp;` → từ "amp") bị tokenize thành từ sai — entity được che bằng khoảng trắng cùng độ dài (offset giữ nguyên cho UI highlight).

### 🚀 T65 — các phase OPT 25–30 chưa nối production giờ đã nối đầy đủ

- **OPT 27 — deck lớn**: `ConfigService.saveSlides` trước đây luôn ghi toàn bộ slides JSON vào SharedPreferences; nay payload > 1 MB được **spill ra file** `<docs>/GhitaPPT/decks/presentation_slides.json`, SharedPreferences chỉ giữ con trỏ (backward compatible với deck cũ). `SmartDraftManager` cũng spill draft > 1 MB sang `*.slides.json` + purge cả 2 file.
- **OPT 28 — lazy AI scan**: `scanLocalAI` cache kết quả 5 phút; Home kick scan **sau post-frame** — không bao giờ chặn màn hình đầu.
- **OPT 29 — healthcheck song song + thích ứng**: `_performHealthChecks` chạy **song song** (`Future.wait`) thay vì tuần tự N×timeout; khoảng lặp tự động 10 phút khi ≥ 4 provider, 5 phút khi ít hơn.
- **OPT 30 — lazy provider**: `AIProviderManager.loadProviders()` (đọc secure storage) chuyển sang post-frame — không chạy trong build đầu.

### 🧹 Chất lượng
- `dart fix --apply` + sửa tay: **flutter analyze giờ "No issues found"** — 0 error/warning/info (trước: 25 info).
- `xml` chuyển từ dev_dependencies → dependencies (dùng trong lib/, hết `depend_on_referenced_packages`).
- Regression tests mới: `test/deep_review_regression_test.dart` (10 test) chốt các bug trên + test spill ConfigService.

### 🧪 Kiểm định cuối
- **732/732 test xanh** · **flutter analyze 0 lỗi** (No issues found) · **i18n 800/800** EN = VI · `tool/l10n_audit.dart` CLEAN.
- Xác minh 67/67 track: mọi `File chính` trong ROADMAP tồn tại (7 mục rename/wildcard đã đối chiếu thủ công).

## [2.0.0-beta] - 2026-08-15 — Milestone 10: Release — Editor UX & Tối ưu (T63–T67)

### ✨ Tính năng mới

**T63 — Editor UX nâng cấp (OPT 13–19, 24)**
- **`WysiwygService`** (`lib/services/wysiwyg_service.dart`): `wrapSelection`/`toggleWrap`/`colorSelection` — bọc `<b>/<i>/<u>/<ol>/<blockquote>` và **span màu quanh đúng text đang chọn** (không đụng tag), trả lại selection mới; `classify` phân loại block cho highlight.
- **Live preview debounce 500ms** khi gõ (đã có sẵn, giữ nút Update cho trường hợp tắt) + **Status bar mở rộng (OPT 24)**: số từ slide hiện tại + dung lượng deck (KB) cạnh slide x/y, zoom %, trạng thái lưu.
- **WYSIWYG toolbar nâng cấp**: thêm nút Màu chữ (palette → span color), Danh sách đánh số, Trích dẫn — hoạt động trên selection qua `WysiwygService`.

**T64 — Preview & Thumbnail thật (OPT 20)**
- **`ThumbnailService`** (`lib/services/thumbnail_service.dart`): `renderThumbnail` render slide thật qua `SlideFrameRenderer` → PNG (160×90), `renderBatch` hàng đợi **4 slide/lần** giới hạn RAM, `placeholderB64` theo layoutType khi render lỗi.
- **Slide list render thumbnail thật**: cache LRU 60 ảnh, decode nền (không giật khi cuộn), fallback layout placeholder — không bao giờ treo.

**T65 — Lưu trữ & Khởi động (OPT 25–30)**
- **`HistoryStorageService`** (`lib/services/history_storage_service.dart`): snapshot nén **gzip** (`archive`), **diff** chỉ slide thay đổi, `CoalescingRecorder` gộp 5s gõ liên tục thành 1 snapshot — undo 30 snapshot không rớt RAM.

**T66 — Import nâng cao (OPT 44, 45)**
- **`AdvancedImportService`** (`lib/services/advanced_import_service.dart`): Markdown đầy đủ — **bảng `| cột |`**, danh sách lồng, khối code giữ dạng, ảnh, phân slide bằng `---`; **.docx** heading → slide; **.pptx** shape text/bullet/ảnh → HTML (chart/smartart → placeholder); **PDF** trang = slide (tối đa 30); **web giàu** — title + H1–H3 + đoạn + list + ảnh (tối đa 5).
- **`ImportDialog` nâng cấp**: 3 nguồn Markdown/File/Web URL + preview trước khi áp + nút Import trên toolbar editor.

**T67 — Dọn code chết & l10n hoàn chỉnh (OPT 48, 49)**
- **`tool/l10n_audit.dart`**: script kiểm tra `.arb` EN/VI đồng bộ (hard gate) + quét chuỗi tiếng Việt lẫn trong UI (bỏ qua file locale-aware) — **800/800 key khớp, CLEAN**.
- Gỡ import rác, dọn dead code dọc theo quá trình rà soát; `flutter analyze` 0 lỗi.

### 🧪 Kiểm định
- **722/722 test xanh** (701 + **21 test mới** M10) · **flutter analyze 0 lỗi** · **i18n 800/800** EN = VI.
- Tool: `dart run tool/l10n_audit.dart` (điểm cổng chất lượng l10n cho release).

## [2.0.0-beta] - 2026-08-15 — Milestone 9: Năng suất & Trợ năng (T57–T62)

### ✨ Tính năng mới

**T57 — Chính tả, Thesaurus, Tìm/Thay thế (FEAT 92, 93, 94)**
- **`SpellcheckService`** (`lib/services/spellcheck_service.dart`): từ điển EN + VI nhúng (tĩnh, offline), tokenize có vị trí để highlight, gợi ý sửa bằng **Levenshtein** (≤2, tối đa 8) — "recieve" → "receive"; grammar cục bộ (viết hoa đầu câu, khoảng trắng kép, khoảng trắng trước dấu câu) + `fixGrammar`; thesaurus EN mini (~45 từ, mở rộng AI tùy chọn ở UI).
- **`SearchService`** (`lib/services/search_service.dart`): tìm theo title + text mọi slide (option case-sensitive/whole-word, trả vị trí), **Replace chỉ trong text node** — không đụng tag/attribute, đếm số chỗ đã thay.
- **UI**: `SpellcheckDialog` (quét slide hiện tại, gợi ý từng lỗi + Ignore + Apply fixes) + `FindReplaceDialog` (Ctrl+F, Replace all, nhảy tới slide kết quả); 2 nút toolbar.

**T58 — Accessibility Checker (FEAT 95)**
- **`AccessibilityService`** (`lib/services/accessibility_service.dart`): 3 kiểm tự động — **thiếu alt text** cho ảnh, **tương phản WCAG AA** (4.5:1, đề xuất màu tối hơn đạt chuẩn), **thứ tự đọc** (thiếu h1 / nội dung trước tiêu đề); `applyFix` 1 chạm (alt từ title slide, contrast theo màu gợi ý); xuất báo cáo dạng text.
- **`AccessibilityPanel`** (`lib/screens/widgets/m9_productivity_dialogs.dart`): bảng lỗi theo slide + nút Fix + Export report.

**T59 — Template online & Studio hoàn thiện (FEAT 96 + OPT 46, 47)**
- **Tham số hóa template** (`template_service.dart`): `applyTheme` thay `{primary}`/`{accent}`/`{font}` — đổi theme → template tự biến đổi; `templateFromDeck` tạo template từ slide 1 + mã hóa màu deck thành placeholder.
- **Yêu thích + user templates**: `loadFavorites`/`toggleFavorite` (SharedPreferences), `saveUserTemplate`/`deleteUserTemplate` lưu template tự tạo.
- **Kho template online (FEAT 96)**: URL cấu hình JSON (mặc định tắt), `fetchOnlineTemplates` có timeout; đăng tải server riêng để sau.

**T60 — Ribbon/QAT tùy biến & Chế độ xem (FEAT 97, 99)**
- **`RibbonConfigService`** (`lib/services/ribbon_config_service.dart`): model tab→group→command (id chuẩn hóa theo `ShortcutAction` + lệnh thêm), default 6 tab khớp ribbon hiện tại; lưu SharedPreferences; export/import JSON (lọc command lạ); QAT riêng (`defaultQat`: save/undo/redo/export/print).
- **`RibbonCustomizeDialog`** (`lib/screens/widgets/ribbon_customize_dialog.dart`): 2 cột Available ↔ QAT, thêm/xóa tab riêng, Reset; nút toolbar.
- **Views (FEAT 99)**: menu 4 chế độ — Normal / Slide Sorter / Notes (dialog sửa ghi chú slide hiện tại, sync `slide.notes`) / Reading (PresentScreen trong cửa sổ app).

**T61 — Add-ins & VBA (FEAT 98)**
- **`AddinService`** (`lib/services/addin_service.dart`): add-in JSON trong thư mục `addins/` (bên cạnh app, override cho test); **chặn add-in remote** (`source: http…` bị bỏ); bật/tắt + uninstall qua SharedPreferences; 3 handler mẫu (`transform`, `kpi` — thêm slide tóm tắt KPI từ số liệu, `append_title`); lỗi add-in bị nuốt — không crash app.
- **`VbaService`** (`lib/services/vba_service.dart`): không chạy VBA — phát hiện `.pptm`/`vbaProject` + cảnh báo macro; **JSON macro script** record/playback (add_slide, update_slide, remove_slide, set_bg) — tương đương VBA di động.
- **`AddinManagerDialog`**: danh sách add-in, switch bật/tắt, Run, install từ JSON, uninstall.

**T62 — Đọc to & Điều hướng bàn phím (FEAT 100)**
- **`ReadAloudService`** (`lib/services/read_aloud_service.dart`): Windows TTS (System.Speech qua PowerShell, base64 tránh vỡ tiếng Việt, chọn giọng theo locale vi-VN/en-US), rate chậm/vừa/nhanh, pause/resume/stop, đọc toàn deck từ slide hiện tại.
- **`ReadAloudBar`**: thanh dock dưới toolbar — trạng thái "Reading slide N/total", pause/resume/stop, tốc độ.

### 🧪 Kiểm định M9
- **701/701 test xanh** (+34 test mới cho M9), **analyze 0 lỗi**, i18n **791/791** EN=VI (+12 key).

## [2.0.0-beta] - 2026-08-15 — Milestone 8: AI hiểu ngữ cảnh, Designer & Copilot (T51–T56)

### ✨ Tính năng mới

**T51 — Reuse Slides & Compare/Merge (FEAT 85, 86)**
- **`ReuseSlideService`** (`lib/services/reuse_slide_service.dart`): parse `.ghita` bundle (chuẩn hóa `html`→`htmlContent`), tách slide từ text/HTML (`---`, `h1`/`h2`); `useCurrentTheme` viết lại HTML về baseline `<h1>/<p>/<ul>` theo đúng theme (đi bộ text nodes theo thứ tự, giữ ngữ cảnh tag — li giữ list, h1 đầu thành tiêu đề, heading sau hạ cấp thành đoạn).
- **`CompareMergeService`** (`lib/services/compare_merge_service.dart`): diff từng vị trí slide (added/removed/changed/same + đếm từ thêm/xóa multi-set), merge theo lựa chọn A/B/both mỗi vị trí, báo cáo dạng văn bản.
- **`ReuseCompareDialog`** (`lib/screens/widgets/reuse_compare_dialog.dart`): 2 tab — chèn slide (giữ định dạng gốc / dùng theme hiện tại) và so sánh/trộn 2 phiên bản; nút toolbar "Tái sử dụng slide".

**T52 — AI hiểu ngữ cảnh & validate đầu ra (OPT 37, 38)**
- **Deck context vào system prompt** (`ai_provider_manager.dart`): `buildDeckContextPrompt` (layout hiện tại, theme primary/accent/font, ngôn ngữ UI, tóm tắt slide đang chọn, outline deck) — bật/tắt qua checkbox "AI dùng ngữ cảnh deck" (riêng tư theo lựa chọn).
- **`AIHtmlGuard`** (`lib/services/ai_html_guard.dart`): strip `script/iframe/object/embed/link/meta/base/form/input/button/select/textarea`, event handler, `javascript:` URL, `@import`; giới hạn 100KB với tự-rút-gọn (bỏ class trùng) + truncate đóng tag; cân bằng tag + sửa tag đóng lạc; `generateSlideContent` luôn chạy qua guard.

**T53 — AI pipeline bền vững & tiết kiệm (OPT 39–43)**
- **`AIPipelineService`** (`lib/services/ai_pipeline_service.dart`): `repairJsonArray` (cân bằng ngoặc/quote, xử lý code fence, cắt tại điểm đóng hợp lệ — checkpoint giữ slide đã xong khi cắt mạng giữa chừng), `parseIncremental` (stream render slide 1 sớm — OPT 40), `estimateTokens` (đếm token ước tính phiên, CJK riêng), `trimHistoryByTokens` (giới hạn chat history theo token, giữ bản mới nhất, báo dropped).

**T54 — Designer / Design Ideas (FEAT 87)**
- **`DesignerService`** (`lib/services/designer_service.dart`): phát hiện nội dung (title, list dài, KPI numbers, bảng, ảnh, quote) + 6+ quy tắc layout local — 2 cột, KPI cards, hero image, table focus, quote, accent band + clean baseline (max 5 gợi ý); `applyAccentVariant` (đổi màu accent không đụng grayscale), `applyDarkVariant` (dark mode — thứ tự thay màu đúng: text trước, nền trắng sau).
- **`DesignerPanel`** (`lib/screens/widgets/designer_panel.dart`): dock phải, thumbnail gợi ý, chọn accent/dark, áp 1 chạm + nút "Hoàn tác thiết kế"; nút toolbar "Designer".

**T55 — Copilot Creator (FEAT 88, 89)**
- **`CopilotService`** (`lib/services/copilot_service.dart`): `slidesFromDocument` (chia slide theo heading hoặc chunk ~80 từ, giữ ý chính, cap maxSlides — nền tảng Word/PDF/Markdown), `fetchUrlText` (scrape URL), `buildDeckIndex` + `searchDeckIndex` (Q&A theo deck — index title+text, tìm theo token overlap), `buildDeckSummaryPrompt` (tóm tắt 5 dòng), `buildExpandPrompt` (soạn thảo tiếp).
- **Chat UI** (`ai_chat_screen.dart`): 4 chip nhanh — Tạo presentation / Tóm tắt deck (chèn slide "Summary" cuối) / Hỏi về deck (kèm link slide) / Dịch toàn deck; toggle ngữ cảnh deck.

**T56 — Dictation & Dịch toàn deck (FEAT 90, 91)**
- **`DictationService`** (`lib/services/dictation_service.dart`): bọc SubtitleService (SAPI Windows) + auto-stop sau 2s im lặng, probe locale EN/VI (fallback EN kèm cảnh báo khi máy thiếu tiếng Việt), `pushManualPhrase` cho test/recognizer ngoài.
- **`DeckTranslationService`** (`lib/services/deck_translation_service.dart`): `textNodes`/`applyTranslations` — dịch CHỈ text node, giữ nguyên tag/class/attribute; 8 ngôn ngữ; `buildTranslationPrompt` hướng dẫn model giữ cấu trúc.
- **Toolbar**: nút mic "Đọc chính tả" (pulse đỏ khi nghe) — text vào slide hiện tại; dịch từng slide qua AI với progress + áp hàng loạt/cancel.

### 🧪 Kiểm định M8
- **667/667 test xanh** (+36 test mới cho M8), **analyze 0 lỗi**, i18n **779/779** EN=VI (+26 key).

## [2.0.0-beta] - 2026-08-15 — Milestone 7: Cộng tác & Cloud (T46–T50)

### ✨ Tính năng mới

**T46 — Hạ tầng cộng tác LAN nâng cấp (OPT 32, 34, 35, 36)**
- **Delta sync thay full snapshot** (`collaboration_service.dart`): client chỉ gửi các slide đã thay đổi (`{index, slide}`) kèm `baseRevision`; server merge theo từng slide và giữ `_slideRevisions` per-slide — 2 editor sửa 2 slide khác nhau không xung đột, slide không đụng giữ nguyên. Legacy full-snapshot vẫn được chấp nhận (regression).
- **Gzip payload**: middleware nén mọi JSON response khi client gửi `Accept-Encoding: gzip` + sửa đúng `Content-Length` (dart:io client tắt `autoUncompress` để tránh giải nén 2 lần); deck lặp text 80 đoạn >20KB → stream <2KB (test đo ratio).
- **View token ngắn (8 char)** tách khỏi edit token (32 char) — nền tảng cho link xem chỉ-đọc T49.
- **Auto re-connect backoff 1→2→4→8s** khi poll thất bại; `_pollFailures` reset khi nối lại; adaptive poll: fast 250ms sau edit + heartbeat 900ms; emit `connectionLost`/`reconnected`.
- **Cấu hình động** (`updateSessionConfig`): max collaborators (1–100) & max slides (1–1000) chỉnh được.
- **Conflict UI data**: 409 kèm `conflicts: [{index, name, color, at}]` (ai đổi slide nào lúc nào).

**T47 — Co-authoring thời gian thực (FEAT 80)**
- **Presence + cursor**: POST `/presence` (throttle 100ms client) + GET `/presence` (danh sách collaborator + slideIndex + x/y); badge "đang sửa slide N" trong CollaborationPanel.
- **Soft lock**: POST `/lock` acquire/release per-slide; sync trùng slide bị lock → 409 `slide_locked` kèm owner; client hiện "đang được {name} sửa".
- **Merge theo slide**: `_lastWriters` map (index → name/color/at) + `_syncLog` (cap 200) qua GET `/history`; `fetchHistory()` public.
- **Moderation**: host `kickCollaborator` (xóa token + presence + locks, emit userLeft), `setSessionLocked` từ chối join mới; 403 `session_locked`.
- **Viewer bị server chặn**: sync từ viewer → 403 `read_only` → client emit `readOnlyRejected` (UI "Chế độ xem").

**T48 — Comments & Mentions (FEAT 81)**
- **`Comment` model** (`lib/models/comment.dart`): id/slideIndex/text/author/createdAt/resolved/replyTo/anchor, JSON round-trip + malformed-safe.
- **`CommentService`** (`lib/services/comment_service.dart`): CRUD trên slide map (key `comments`) — tự chảy qua collaboration delta + .ghita bundle; `mentionsIn` @-mention regex (hỗ trợ tiếng Việt `\p{L}`); `filterMentionsToKnown`; **OOXML xuất** `<p:cmLst>` + `<p:cmAuthorLst>` chuẩn PowerPoint.
- **`CommentsPanel`** (`lib/screens/widgets/comments_panel.dart`): pane phải editor — thêm/trả lời thread/resolve/delete, highlight @mention, menu gợi ý collaborator khi gõ @ (từ session hoặc profile).
- **Toolbar**: nút "Bình luận" bật/tắt pane.

**T49 — Tài khoản người dùng & Phân quyền (FEAT 84)**
- **`UserProfile`** (`lib/models/user_profile.dart`): tên + avatar emoji + màu, lưu SharedPreferences (offline-first, không yêu cầu tài khoản).
- **`AuthService`** (`lib/services/auth_service.dart`): vai trò host/editor/viewer, `canEdit`/`isViewer`, mint token theo vai trò (`e_`/`v_`), màu profile chuẩn hóa.
- **Vai trò trong session**: host (toàn quyền + moderation) / editor / viewer (join qua view link → server từ chối mọi sync).
- **`ProfileDialog`** (`lib/screens/widgets/profile_cloud_dialogs.dart`): sửa tên/avatar/màu; dùng làm tác giả comments.

**T50 — Cloud sync & Version history (FEAT 82, 83)**
- **`CloudSyncService`** (`lib/services/cloud_sync_service.dart`): WebDAV thuần (Nextcloud/ownCloud) qua `http` — MKCOL/PROPFIND/PUT/GET/DELETE, credentials trong `flutter_secure_storage`, parse PROPFIND XML → danh sách version, upload tự tăng `v{N}.ghita` + con trỏ `latest.ghita`.
- **`VersionHistoryService`** (`lib/services/version_history_service.dart`): giữ tối đa 20 version/project (trim bản cũ), `localIsNewer` cho merge conflict → lưu bản cũ thành `.conflict`.
- **`CloudSyncDialog`** (`lib/screens/widgets/profile_cloud_dialogs.dart`): cấu hình URL/user/pass, Sync now (upload deck hiện tại), danh sách phiên bản + Restore (tải về máy) + Delete.
- **Toolbar**: nút "Hồ sơ" + "Đồng bộ đám mây".

### 🐛 Bug sửa trong quá trình làm M7
- **`Response.change` giữ Content-Length cũ khi nén gzip** — compressed body khác kích thước → client đọc thiếu stream; phải thay header `Content-Length` cùng body.
- **dart:io `HttpClient` autoUncompress mặc định true** — body đã giải nén sẵn nhưng header `Content-Encoding: gzip` còn lại → decode 2 lần → `Filter error, bad data`; tắt autoUncompress và tự decode.
- **JSON không chấp nhận Map key int** — `_slideRevisions` (Map<int,int>) làm `jsonEncode` ném "Converting object to an encodable object failed"; chuyển sang string keys qua `_slideRevisionsStringKeys()`.

### 🧪 Test mới (28)
- `test/collaboration_delta_test.dart` (+8): merge per-slide 2 editor, stale per-slide conflict kèm ai đổi, view-only join read-only, soft lock chặn + owner, presence/cursor + history, kick, session lock, gzip ratio.
- `test/comments_auth_test.dart` (+11): Comment round-trip + malformed, CRUD/resolve/reply, @mention, filter dangling, OOXML cmLst/cmAuthorLst, profile persist, role helpers + tokens.
- `test/cloud_sync_test.dart` (+9): upload bump version từ PROPFIND, download latest/specific/404, list sort, delete, URL normalize, trim cap, localIsNewer.

### ✅ Kiểm định
- Full suite **631/631 test xanh** (603 + 28) · `flutter analyze` **0 lỗi/warning** · i18n **753/753 key EN = VI** (+52 key M7).
- **5/5 track T46–T50 hoàn thiện** (service/model thuần test được + UI + i18n EN/VI + test tự động).

---

## [2.0.0-beta] - 2026-08-15 — Deep review M1–M6: rà soát M6 + tối ưu & sửa bug

### 🐛 Bug thật tìm được khi rà soát M6

- **`_probeAudioDuration` (MP4/m4a) — probe thời lượng narration trả sai/0** (`video_export_service.dart`, T41): hai lỗi chồng nhau — (1) quét box từ `i = 4` trong khi box MP4 bắt đầu ở offset 0, nên với file m4a thật (bắt đầu `00 00 00 20 66 74 79 70…`) đọc `size = 0x66747970` (khổng lồ) rồi nhảy ra ngoài file, không bao giờ gặp `mdhd`; (2) offset trường `mdhd` sai 8 byte (đọc `creation_time`/`modification_time` thay vì `timescale`/`duration`). Xác minh bằng file m4a thật (FFmpeg 2.5s): trước fix → `timescale=0` (0s), sau fix → `44100/111274` (2.523s). Ngoài ra mdhd nằm lồng trong `moov→trak→mdia` nên quét phẳng không bao giờ thấy — đã thêm **đệ quy container box**. Hệ quả nếu không sửa: narration m4a (đúng định dạng recorder T39 tạo ra) không bao giờ được dùng làm thời lượng slide trong video/GIF export.
- **`DocSecurityService._rewriteParts` làm hỏng mọi ký tự non-ASCII trong PPTX** (`doc_security_service.dart`, T45): mỗi XML part được decode Latin-1 (`String.fromCharCodes`) rồi re-encode UTF-8 → round-trip không byte-exact; chứng minh bằng probe: "Xin chào, hôm nay là ngày ế ộ" → "Xin chÃ o…Ã¡ …Ã£â€šÃ¡". Áp mật khẩu / Mark-as-Final / restrict note lên deck có tiếng Việt sẽ làm mojibake **toàn bộ slide text** trong file xuất ra. Fix: decode UTF-8 (`utf8.decode` + `allowMalformed`), round-trip byte-exact — có regression test so sánh byte trước/sau.

### 🔧 Tối ưu thuật toán (M6)

- **`SlideFrameRenderer`** (`slide_frame_renderer.dart`, T41/T42): hoist `RegExp(data-bg-color…)` (chạy mỗi slide) và `RegExp(\s+)` (chạy mỗi paragraph); `_fillOval` outline chia cho `rx-1`/`ry-1` có thể = 0 (ellipse 1–2px) → clamp `math.max(1.0, …)` chống divide-by-zero + bỏ tính lại 2 phép chia lặp.
- **`PackageService`** (`package_service.dart`, T45): hoist `_mediaRe` (quét base64 trong toàn deck, gọi mỗi slide) và `_extCleanRe` (chạy mỗi media).
- **`VideoExportService.estimate`** (T41): GIF trước đây ước lượng `frameCount = fps × seconds` trong khi encoder thực tế ra 1 frame/slide (delay đóng vào frame) → thời lượng ước lượng cao gấp ~10 lần; giờ trả `shots.length` cho GIF, giữ `fps × giây` cho MP4.
- **`PrintService.buildHandoutPdf`** (T43): deck rỗng làm `clamp(0, -1)` ném `ArgumentError` khó hiểu → guard sớm "Nothing to print".
- **`PackageFormatService`** (T44): `_findSoffice()` dùng `Process.runSync` chạy `soffice --version` trên UI thread → chuyển async `Process.run` + timeout 5s (test hook `binaryProbe` giữ nguyên).

### 🧪 Test mới (4)
- M4A probe đọc `mdhd` lồng `moov/trak/mdia` với file m4a tổng hợp (timescale 44100/duration 111274 → 2.523s).
- GIF estimate: 2 slide × 1s → `frameCount == 2` (không phải 20); MP4 vẫn 60.
- Password rewrite giữ nguyên UTF-8 slide text byte-exact (regression mojibake).
- Handouts PDF deck rỗng → `ArgumentError` sạch.

### ✅ Kiểm định
- **603/603 test xanh** (599 + 4 mới) · `flutter analyze` **0 lỗi/warning** · i18n **701/701 EN = VI**.
- **6/6 milestone (M1–M6) · 45/45 track · 450/450 phase hoàn thành 100%** — đối chiếu phase-by-phase từ code + test.

---

## [2.0.0-beta] - 2026-08-15 — Milestone 6: Xuất & Phân phối nâng cao (T41–T45)

### ✨ Tính năng mới

**T41 — Video/GIF từ slide & in (FEAT 69, 70)**
- `SlideFrameRenderer` (`lib/services/slide_frame_renderer.dart`): renderer thuần Dart — vẽ slide (nền, text, hình, video poster, hình dạng) thành ảnh qua `package:image`, không phụ thuộc GPU/WebView; dùng làm nền tảng cho video/GIF/handouts.
- `VideoExportService` (`lib/services/video_export_service.dart`): xuất **video MP4 mô phỏng trình chiếu** (mỗi slide một khoảng thời gian, keyframe cảnh) hoặc **GIF animation** (encoder của `package:image`, tối ưu 256 màu); kèm **WAV timeline** (giọng nói/nhạc nền theo slide — PCM 16-bit chuẩn).
- i18n EN/VI +28 key; **11 test mới** (`test/slide_frame_video_test.dart`): renderer vẽ text/hình/video poster, GIF magic bytes + frameCount + duration, WAV RIFF header + sample rate + duration, MP4 container đúng (ftyp/moov), progress callback.

**T42 — Xuất ảnh hàng loạt & contact sheet**
- `SlideImageExportService` (`lib/services/slide_image_export_service.dart`): xuất toàn bộ slide thành **PNG/JPEG** (batch), tùy chọn kích thước, **contact sheet** (tất cả slide trên 1 ảnh dạng lưới, số thứ tự slide), progress callback 0–1.
- i18n EN/VI (dùng chung key M6); test trong `test/slide_frame_video_test.dart`.

**T43 — Outline RTF & Handouts in**
- `OutlineExportService` (`lib/services/outline_export_service.dart`): xuất **Outline (.rtf)** — tiêu đề/bullet mỗi slide, ký tự non-ASCII encode `\uN` chuẩn RTF (ế = `\u7871`), giữ ghi chú speaker tùy chọn.
- `PrintService` (`lib/services/print_service.dart`): **handouts PDF** (2/3/4/6/9 slide mỗi trang) tái dùng `SlideFrameRenderer` render từng slide → ghép layout `Row/Column/Expanded` của `package:pdf`.

**T44 — Định dạng gói: POTX/PPSX/PPTX + ODP**
- `PackageFormatService` (`lib/services/package_format_service.dart`): xuất **POTX** (đổi content type template + `presProps` isKiosk) và **PPSX** (đổi content type slideshow + isKiosk + `p:show` custom show) từ PPTX có sẵn qua Zip post-process; gọi LibreOffice (nếu có) cho `.ppt` legacy.
- `OdpExportService` (`lib/services/odp_export_service.dart`): gói **OpenDocument Presentation (.odp)** độc lập — content.xml với slide/placeholder, styles.xml, manifest, meta.xml; mở được bởi LibreOffice/Impress.

**T45 — Đóng gói & bảo mật tài liệu**
- `PackageService` (`lib/services/package_service.dart`): đóng gói deck + tài nguyên thành **.ghita bundle** (zip) và **thư mục HTML standalone** (index.html + assets) để chia sẻ.
- `DocSecurityService` (`lib/services/doc_security_service.dart`): **bảo vệ mật khẩu PPTX** — đặt mật khẩu mở file qua `<fileSharing>` + `p:modifyVerifier`/`p:extLst` đúng schema OOXML (PowerPoint yêu cầu mật khẩu khi mở), gỡ mật khẩu.
- i18n EN/VI (dùng chung key M6); **25 test mới** (`test/print_package_security_test.dart`): RTF encode ế/cấu trúc, handouts PDF số trang + widget tree, POTX content type `template`, PPSX content type `slideshow` + `isKiosk`, ODP content.xml + manifest, zip bundle tròn vẹn, password-protected PPTX có `fileSharing` + mở lại gỡ mật khẩu được.

**UI — M6 Export Dialog**
- `M6ExportDialog` (`lib/screens/widgets/m6_export_dialog.dart`): một dialog tổng hợp — Video/GIF · Ảnh (batch + contact sheet) · Outline/Handouts in · Định dạng gói (POTX/PPSX/ODP) · Bảo mật (đặt/gỡ mật khẩu); nối từ nút "Xuất nâng cao" của `AdvancedExportDialog`.

### ✅ Kiểm định
- Full suite **599/599 test xanh** · `flutter analyze` **0 lỗi/warning** · i18n **701/701 key EN = VI**.
- Cả 5 track T41–T45 hoàn thiện (service/model thuần test được + UI + i18n EN/VI + test tự động).

---

## [2.0.0-beta] - 2026-08-15 — Deep review M1–M5: tối ưu thuật toán & sửa bug

### 🔧 Tối ưu thuật toán (rà soát toàn diện T01–T40)

- **TextMetricsService** (`text_metrics_service.dart`): vòng lặp ước lượng độ rộng chạy từng ký tự mỗi run — trước đây `_punctChars.codeUnits.contains()` cấp phát một `List<int>` mới **mỗi ký tự** (và quét tuyến tính). Thay bằng `Set<int>` tĩnh precompute — hot path của layout pass PPTX (T02).
- **TextLayoutService** (`text_layout_service.dart`): title-case dựng `RegExp(r'^\s+$')` **mỗi từ** trong map; sentence-case dựng regex mỗi lần gọi — hoisted thành `static final` (T28).
- **PPTGenerator** (`ppt_generator.dart`): 11 pattern slide-pass (`data-smartart`/`data-chart`/`data-video`/`data-model3d`/`data-action`/`data-equation`/`data-ole`/`data-zoom`/`data-sectionzoom`/`data-cameo`/`data-bg-color` + `<p:timing>` wrapper) được biên dịch lại **mỗi slide** — hoisted thành `static final` (T08–T20).
- **ShapeEngine** (`shape_engine.dart`): `cmdRe`/`numRe` của path parser được tạo lại mỗi lần parse (freeform/merged shape) — hoisted; đồng thời đơn giản hóa biểu thức identity `p.dx / s.w * s.w` (no-op) trong `_polygonOf` (T21).
- **PdfExportService** (`pdf_export_service.dart`): `cmdRe`/`numRe` path parser hoisted (T06).
- **IconLibraryService** (`icon_library_service.dart`): `_samplePath` tạo `RegExp(r'[A-Za-z]')` **mỗi token mỗi vòng lặp** và token regex mỗi lần gọi — hoisted; icon rasterization chạy cho từng icon mỗi lần export (T15).
- **AnimationEngine** (`animation_engine.dart`): regex `cssClass`/`_sec` hoisted (T29).
- **ImageEditorService** (`image_editor_service.dart`): `_oilPaint` reset toàn bộ 4 mảng 256 phần tử (`fillRange`) **mỗi pixel** (~10⁹ store thừa trên ảnh 1MP, bán kính 8) — giờ chỉ reset các bucket luminance mà cửa sổ thực sự chạm tới (T23).

### 🐛 Bug sửa

- **`cropImage`** (`image_editor_service.dart`): rect crop sát mép phải/dưới (x + w ≈ 1) làm `clamp(1, 0)` ném `ArgumentError` (lower > upper) → crop âm thầm fail. Guard `math.max(1, image.width - px)` trước khi clamp (T22).
- **`RemoteControlService.start`** (`remote_control_service.dart`): tham số `requireToken` bị bỏ qua — `_requireToken` là `final bool = true` nên `start(requireToken: false)` vẫn đòi token. Tham số giờ được gán (T37).

### 🧪 Test mới (4)
- `cropImage` sát mép không crash (regression clamp guard).
- Oil paint giữ nguyên màu đồng nhất (regression tối ưu bucket).
- WS remote `requireToken: false` cho client không token kết nối được (nhận state).
- WS remote `requireToken: true` từ chối client không token (`bad_token`).

### ✅ Kiểm định
- **574/574 test xanh** · **flutter analyze: 0 lỗi** · **i18n: 673/673 EN = VI**.

## [2.0.0-beta] - 2026-08-15 — Milestone 5: Trình chiếu Pro (T35–T40)

### ✨ Tính năng mới

**T35 — Trình chiếu Pro (FEAT 59, 60, 61)**
- `PresentToolsService` (`lib/services/present_tools_service.dart`): trạng thái tool pen/laser/magnifier, màu + độ dày pen, B/W screen (black/white), grid overlay, tự động tắt pen sau 3s không vẽ, slide jump G, lưu cấu hình tool trong session (lưu/khôi phục).
- `PresentDeckCommands` (`lib/services/present_deck_commands.dart`): sinh JS thuần cho deck HTML — `installProKeys` (keydown G/B/W/P/L/M/`?`/số+Enter hoạt động ngay trong WebView2 kể cả khi nó nuốt phím), `overlayScript` (SVG ink pen/laser/lúp + grid vẽ ngay trong deck), `presenterScript` (sync slide hiện tại + kế tiếp cho Presenter View), `showBlack/white`, `zoom` (scale transform).
- `WebViewRuntimeService` (`lib/services/webview_runtime_service.dart`): kiểm tra WebView2 runtime (trả về null nếu chưa cài → hướng dẫn cài).
- `PresentScreen` nâng cấp: toolbar tool (pen/laser/lúp/B/W/grid), phím tắt trùng JS (F5/G/B/W/P/L/M), `executeScript` đồng bộ deck ↔ Flutter, cảnh báo thiếu WebView2 runtime.
- `PresenterViewScreen` nâng cấp: 1 WebView2 duy nhất chạy deck đầy đủ (HTML/CSS/JS), JS presenter script đồng bộ slide hiện tại + kế tiếp, đồng hồ + ghi chú speaker.
- i18n EN/VI +10 key; **20 test mới** (`test/present_pro_test.dart`).

**T36 — Setup Show & Custom Shows (FEAT 62, 63)**
- `CustomShow` (`lib/models/custom_show.dart`): danh sách slide tùy chọn (custom show) + serialize/deserialize.
- `SetupShowService` (`lib/services/setup_show_service.dart`): cấu hình trình chiếu (loop liên tục, không narration, không animation, tự động advance, thời gian mỗi slide, lặp ảnh nền, show speaker notes) + sinh danh sách slide theo custom show.
- `SetupShowDialog` (`lib/screens/widgets/setup_show_dialog.dart`): UI cấu hình + chọn/soạn custom show; tích hợp vào `PresentationState` (lưu qua SharedPreferences, `buildHtmlDeck` theo custom show, chỉ bật advanced effects khi bật animation).
- `HomeScreen._present` mở dialog nếu chưa cấu hình; `PresentScreen` nhận `setupShow` + `customShowOrder` (loop, jump theo danh sách custom).
- **PPTX**: `p:custShowLst` ghi custom show trong `presentation.xml` (danh sách `p:sldIdLst` trỏ đúng slide).
- i18n EN/VI +12 key; **13 test mới** (`test/custom_show_setup_test.dart`).

**T37 — Remote điện thoại & phụ đề trực tiếp (FEAT 65)**
- `RemoteControlService` (`lib/services/remote_control_service.dart`): WebSocket server local điều khiển từ điện thoại — QR + link, ping/status, command next/prev/black/resume, yêu cầu token (mặc định) + verify.
- `SubtitleService` (`lib/services/subtitle_service.dart`): phụ đề trực tiếp từ giọng nói — speech recognition Windows qua PowerShell (`System.Speech`) nếu có, fallback phân tích transcript AI; `subtitlesChanged` stream.
- i18n EN/VI +4 key; **7 test mới** (`test/remote_subtitle_test.dart`).

**T38 — Rehearse timings & Coach AI (FEAT 66, 67)**
- `RehearseService` (`lib/services/rehearse_service.dart`): bấm giờ buổi tập, thời gian từng slide (list `slideChangeSeconds`), pause/resume/stop, báo cáo (tổng thời gian, slide chậm nhất, nhịp độ) + auto-stop theo giới hạn.
- `CoachService` (`lib/services/coach_service.dart`): phân tích transcript — đếm từ dè dặt EN/VI (um/uh/ừm/à…), từ lặp, nhịp độ từ/phút, gợi ý cải thiện (local heuristic + tích hợp AI provider sẵn có khi có transcript dài).
- i18n EN/VI +4 key; **12 test mới** (`test/rehearse_coach_test.dart`).

**T39 — Ghi hình phiên trình bày (FEAT 68)**
- `PresentationRecorderService` (`lib/services/presentation_recorder_service.dart`): ghi hình phiên trình bày tái dùng `ScreenRecorderService` — mode timings+narration, pause/resume, theo dõi slide change (seconds), auto-stop theo giới hạn, xuất báo cáo timings JSON, ghi chú slide cuối.
- i18n EN/VI +3 key; **7 test mới** (`test/presentation_recorder_test.dart`).

**T40 — Broadcast SSE thay reload (FEAT 64, OPT 33)**
- `WifiBroadcasterService` nâng cấp: trang xem dùng **EventSource** (SSE) thay vì poll 3s — server push slide ngay khi đổi (không giật reload), endpoint `/events` (text/event-stream), `/control` next/prev khi host bật, `/once` link dùng 1 lần + hết hạn, đếm viewer real-time, payload JSON `{currentSlide, totalSlides, allowControl, includeNotes, notes?}`.
- i18n EN/VI +4 key; **9 test mới** (`test/broadcast_sse_test.dart`) — chạy server thật trong test, client HTTP + socket thô.

### 🐛 Bug SDK tìm được khi làm T40
- **Dart 3.12.2 (Windows): `Socket.flush()` (và `HttpResponse.flush()`) không đẩy body ra socket** — chỉ `close()` mới gửi. Debug bằng bisect probe: mọi `flush()` chỉ gửi headers; body chỉ tới khi đóng kết nối → SSE ban đầu đứng yên. Ngoài ra `flush()` ném `StateError("StreamSink is bound to a stream")` nếu gọi khi một `flush()` trước chưa xong (implementation `_StreamSinkImpl` đặt `_isBound = true` và `close()` controller nội bộ).
- **Sửa**: `/events` dùng `response.detachSocket()` lấy raw socket, ghi frame chunked thủ công (`{len}\r\n{data}\r\n`) qua **chuỗi write tuần tự await từng `flush()`** — vừa né bug flush vừa né race "bound to a stream". Verified: client nhận từng frame ngay lập tức, giữ kết nối mở.

### ✅ Kết quả M5
- Full suite **570/570 test xanh**, `flutter analyze` **0 lỗi/warning**, i18n **673/673 key EN = VI**.
- Tất cả 6 track T35–T40 hoàn thiện (mỗi track có service/model thuần test được + UI tích hợp + i18n EN/VI + test tự động).

---

## [2.0.0-beta] - 2026-08-15 — Deep review M1–M4 (T01–T34) + test bổ sung

### 🐛 Sửa lỗi
- **`SectionZoomData.fromMap`** (`lib/services/zoom_feature_service.dart`): ép kiểu `map['entries'] as List` + `.map<SectionZoomEntry>` — trước đây lỗi runtime "`List<dynamic>` is not a subtype of `List<SectionZoomEntry>`" bị `fromJson` nuốt trong try/catch, nên mọi Section Zoom load lại đều mất hết tile (entries rỗng). Giờ round-trip JSON giữ đủ entries.

### 🧪 Test bổ sung (T20 – Section Zoom P6)
- `test/zoom_cameo_test.dart` +6 test: `SectionZoomData` round-trip JSON, `htmlMarkup` tile grid + goToSlide, service `sectionZoomsIn`/`sectionZoomMarkup`/`replaceSectionZoomAt`, PPTX p:sp grid + `ppaction://hlinksldjump`, HTML tile grid, PDF không crash.

### ✅ Kết quả rà soát M1–M4 (34/34 track)
- Full suite **502/502 test xanh**, `flutter analyze` **0 lỗi/warning**, i18n **629/629 key EN = VI**.
- Mỗi track T01–T34 có file test riêng + CHANGELOG + i18n EN/VI (đối chiếu phase-by-phase 2026-08-15).
- Xác minh lại các điểm từng bị ghi "dở": **T15** có 1000 icon MDI + 98 curated (~1098, đạt roadmap ~1000); **T17** `updateFreeTexts` có `record` undo + engine đọc thật `visualElements`; **T20** Section Zoom đầy đủ 3 định dạng; **T21** polygon boolean Greiner–Hormann thật (L-shaped union), scribble, gradient, edit points, undo.

---

## [2.0.0-beta] - 2026-08-15 — Dev (2.0.0-beta M1/M2) — Track 21: Shape engine: Merge, Freeform, Edit Points (FEAT 25, 26)

### ✨ Tính năng mới
- **Model `DrawnShape`** (`lib/models/drawn_shape.dart`): type (rect/oval/line/arrow/freeform/merged), x/y/w/h %, rotation, z-order, fillColor, fillTransparency, strokeColor, strokeWidth, freeformPath, mergeOp, mergedIds — serialize/deserialize, `svgMarkup` (SVG `<rect>`/`<ellipse>`/`<line>`/`<polygon>`/`<path>`), `htmlMarkup` (absolute div), `pptxPresetGeom` (rect/ellipse/line/rightArrow).
- **ShapeEngine** (`lib/services/shape_engine.dart`): `renderPptxShape` (OOXML p:sp + prstGeom + solidFill + ln), `mergeUnion` (bounding box union), `mergeIntersect` (overlap), `mergeSubtract` (simplified), `_custGeomXml` (cubic bezier path fallback).
- **UI "Chèn hình"** (`lib/screens/widgets/shape_tools_dialog.dart`): chọn ShapeType (rect/oval/line/arrow), fill/stroke color, stroke width — chèn vào slide dạng `visualElements['shapes']`.
- **Edit Points (P5)** (`lib/screens/widgets/shape_points_dialog.dart`): hiển thị điểm neo trên lưới 10×10, tap chọn, kéo di chuyển, thêm/xóa điểm; `DrawnShape.anchorPoints` (parse SVG path M/L/H/V → points), `pathFromPoints` (serialize ngược), `withAnchors` (chuyển preset shape → freeform với path mới); nút "Chỉnh điểm" trong ShapeToolsDialog.
- **Shape Properties (P7)** (`lib/screens/widgets/shape_properties_dialog.dart`): chỉnh fillColor, fillTransparency (slider 0–20), strokeColor, strokeWidth, shadow toggle; **CanvasOverlay**: thêm `_DraggableShapeOverlay` — click chọn, kéo di chuyển, resize handle, delete, z-order; **HTML editor panel**: `_selectedShapeId` + `_updateShapes` giống freeTexts; **toolbar**: nút "Thuộc tính hình" (Icons.tune).
- **PPTX**: mỗi DrawnShape → `<p:sp>` với `<a:prstGeom>` + fill + stroke.
- **HTML**: SVG inline (absolute div `data-shape-html`).
- **PDF**: `_buildShapePdf` — Positioned + Container với fill + border.
- **Toolbar**: nút "Hình dạng" (category_outlined).
- i18n EN/VI: 7 chuỗi mới.

### 🔬 Kiểm chứng (P10)
- 18 test tự động mới (`test/shape_engine_test.dart`): DrawnShape round-trip (toMap/fromMap/JSON); svgMarkup rect/oval; pptxPresetGeom; mergeUnion bounding box + mergeIntersect overlap + noop; PPTX p:sp rect + oval + regression; HTML SVG + absolute div + regression; PDF không crash; **anchorPoints parse M L path + 4 corners fallback**; pathFromPoints serialize; withAnchors rect→freeform; **copyWith fillColor/fillTransparency/strokeColor/strokeWidth**.
- `flutter analyze` 0 lỗi/warning; full suite **355/355 test xanh** (+21 mới).

### Giới hạn trung thực
- Merge shapes: union/intersect dùng bounding box đơn giản (chưa có polygon boolean thật — chỉ đúng cho rect/circle không xoay).
- `_custGeomXml` sinh rect path cố định (chưa parse SVG path → OOXML path).
- `ShapeEngine.mergeSubtract` trả về shape gốc (chưa implement boolean subtract thật).

---
## [2.0.0-beta] - 2026-08-15 — Dev (M3/M4) — Tracks 22–34 hoàn thiện (0 bug 0 warning)

### ✨ Tracks 22–28 (Soạn thảo & Định dạng)
- **T22 – Crop ảnh & Xóa nền** (`image_editor_service.dart`, `image_editor_dialog.dart`): crop freeform + tỷ lệ khóa 1:1/16:9/3:2, crop-to-shape (mask clip-path/prstGeom), xóa nền local bằng flood-fill theo màu click, brush xóa/khôi phục, PNG alpha chuẩn, undo, i18n.
- **T23 – Hiệu chỉnh & Hiệu ứng nghệ thuật** (cùng service): sharpness, saturation, tone, duotone theo màu theme, blur/mosaic/pencil/film filters, alpha toàn ảnh giữ 3 định dạng, 6 preset nhanh (B&W, Vintage, Cool, Warm, Soft, Vivid), preview real-time.
- **T24 – Eyedropper & Format Painter** (`eyedropper_service.dart` — FFI GetPixel qua user32; `format_painter_service.dart`): capture màu tại con trỏ, snapshot style text/shape, painter 1 lần/liên tục, phím tắt Ctrl+Shift+C/V (+Ctrl+Shift+I eyedropper), sync ShortcutsProvider.
- **T25 – Hiệu ứng Text & Shape chuyên sâu** (`shape_effect.dart`): shadow/glow/reflection/softEdge/bevel + preset nhanh; OOXML a:effectLst, CSS filter/box-shadow, PDF shadow phẳng; UI tab Hiệu ứng trong ShapePropertiesDialog.
- **T26 – Selection Pane & Group** (`layer.dart`, `layer_service.dart`, `group_service.dart`, `selection_pane.dart`): layer model z-order, pane ẩn/khóa/đổi tên/kéo thứ tự, Group/Ungroup (p:grpSp + a:xfrm child coordinates), sync canvas.
- **T27 – Align/Snap/Guides/Ruler** (`alignment_service.dart`, `guide_settings.dart`, `guides_align_dialog.dart`): align 6 hướng theo slide/selection, distribute, smart guides + snap threshold 3%, snap grid 5%, ruler ticks, guides user tùy ý (khóa/xóa), lưu vào DeckMeta (.ghita).
- **T28 – Text nâng cao** (`text_layout_service.dart`, `text_layout_dialog.dart`): replace font toàn deck, change case (5 chế độ), letter-spacing, text dọc (writing-mode + bodyPr vert), autofit shrink/resize, bullets (start/level/icon + a:buAutoNum), tab stops (a:tabLst + leader dot/hyphen).

### ✨ Tracks 29–34 (Animation & Transition)
- **T29 – Động cơ Animation** (`object_animation.dart`, `animation_engine.dart`): model 4 nhóm (entrance/emphasis/exit/motion), timing (delay/duration/repeat/autoReverse/start), CSS keyframes + animation shorthand, HTML deck player JS theo timeline, by-shape targeting qua data-ghita-id.
- **T30 – Animation Pane & Painter** (`animation_pane.dart`): dock panel liệt kê animation, thêm/xóa/sửa, kéo đổi thứ tự, start/duration/repeat, Clear all, Animation Painter (copy timing giữ nguyên).
- **T31 – Trigger & Motion Path**: trigger click trên shape X (OOXML p:spTgt cond + JS click listener), 12 preset motion path (line, arc, circle, zigzag, curve, heart, star, turn, wave, spiral, swish, boomerang), custom path (điểm %), edit lại path.
- **T32 – Xuất Animation chuẩn OOXML** (`animation_ooxml.dart`): p:timing + p:seq + p:cond (clickEffect/withEffect/afterEffect) + p:animEffect/p:animScale/p:animRot/p:animClr/p:animMotion + p:set visibility, dur/delay/repeatCount chính xác, skip + cảnh báo khi không map được (PPTGenerator.animationWarnings).
- **T33 – Transition toàn diện**: 26 hiệu ứng mới (dissolve, cover/uncover 4 hướng, curtain, cedar, pageCurl, ripple, vortex, shred, diamond, wedge, newsflash, ferris, flip, gallery, honeycomb, invert, orbit, origami, reveal), map ISO + p14 namespace, âm thanh p:snd, thời lượng 0.1–3s từng slide, auto-advance per-slide, cảnh báo export (cedar → fade), dialog Transition mới trên ribbon.
- **T34 – Morph** (`morph_service.dart`): match shape giữa 2 slide (id → type+size), FLIP keyframes trong HTML deck, p14:morph transition cho PPTX, giới hạn 20 shape, toggle trong Transition dialog.

### 🧪 Kiểm chứng
- 60+ test mới: image_editor_edit, format_painter, shape_effect, layer_group, alignment_service, text_layout_service, animation_engine, animation_pane, animation_trigger_path, animation_ooxml, morph_service + integration (ppt_generator timing + transitions).
- `flutter analyze` 0 lỗi/warning; full suite xanh.

### 🔧 Deep review M1–M4 (bổ sung)
- **Timing OOXML**: mọi `p:cTn` trong `p:timing` giờ dùng id duy nhất (trước là `id="0"` lặp lại — rủi ro PowerPoint repair file khi mở).
- **HTML animation player**: sửa bug điều hướng bỏ qua animation — wrapper `showSlide` giờ định nghĩa ở local binding (không chỉ `window.showSlide`) nên changeSlide/goToSlide/bàn phím/cảm ứng đều kích hoạt animation; deck không animation vẫn điều hướng bình thường.
- **Hiệu năng HTML export**: hoist 5 RegExp dùng trong vòng lặp slide (`data-bg-color`, empty div, break thừa) thành static final — tránh compile lại mỗi slide.

---

## [2.0.0-beta] - 2026-08-15 — Dev (2.0.0-beta M1/M2) — Track 20: Zoom trong slide & Cameo (FEAT 22, 23)

### ✨ Tính năng mới
- **Slide Zoom** (`lib/services/zoom_feature_service.dart` + `zoom_dialog.dart`): model `ZoomItem` (targetSlide, thumbnailLabel, frameStyle simple/outline/shadow, x/y/w/h %) — dialog chọn slide đích + khung; block: `<div data-zoom='{json}'>`.
  - **HTML**: thumbnail clickable `goToSlide(N)` (JS player function) — trình chiếu app nhảy đúng slide đích.
  - **PPTX**: `<p:sp>` fallback với `a:hlinkClick action="ppaction://hlinksldjump"` (slide jump) — thay cho `<p:zoom>` (chuẩn p14 phức tạp/dễ hỏng — roadmap cho phép fallback hyperlink).
  - **PDF**: labelled blue box.
- **Cameo** (`lib/services/cameo_service.dart` + `cameo_dialog.dart`): model `CameoData` (label, x/y/w/h %) — dialog chọn nhãn + vị trí; block: `<div data-cameo='{json}'>`.
  - **HTML**: styled camera placeholder (📷 + label + "Live camera").
  - **PPTX**: `<p:sp>` dark placeholder với viền xanh + label (PowerPoint không hỗ trợ `<p:cameo>` chuẩn p14 — giữ placeholder như roadmap P8).
  - **PDF**: dark camera box.
- **Sections** (`lib/models/deck_section.dart`): model `DeckSection` (name, startSlide) + `SectionService` serialize/deserialize — nền tảng cho Section Zoom (P6).
- **Toolbar**: 2 nút mới "Thu phóng" (zoom_in) + "Cameo" (videocam).
- i18n EN/VI: 12 chuỗi mới.

### 🔬 Kiểm chứng (P10)
- 17 test tự động mới (`test/zoom_cameo_test.dart`): ZoomItem round-trip/htmlMarkup goToSlide; zoomsIn/replaceZoomAt; CameoData round-trip/htmlMarkup 📷; cameosIn/replaceCameoAt; DeckSection round-trip + SectionService list; PPTX zoom p:sp + ppaction://hlinksldjump; PPTX cameo placeholder; HTML zoom div goToSlide + cameo placeholder + goToSlide JS function; PDF zoom/cameo không crash; regression deck không zoom/cameo không đổi.
- `flutter analyze` 0 lỗi/warning; full suite **334/334 test xanh** (+17 mới).

### Giới hạn trung thực
- Slide Zoom dùng **fallback hyperlink** (p:sp + hlinkClick) thay vì `<p:zoom>` p14 thật — tương thích mọi PowerPoint/LibreOffice, không lỗi repair.
- Cameo dùng placeholder (không có webcam thật trong trình chiếu HTML/PPTX — roadmap P7/P8 cho phép).
- Section Zoom: model `DeckSection` đã có (P6) — chưa có UI quản lý sections riêng (nối khi có Slide Sorter).

---

## [2.0.0-beta] - 2026-08-15 — Dev (2.0.0-beta M1/M2) — Track 19: Header/Footer & field động (FEAT 21, 24)

### ✨ Tính năng mới
- **Model `DeckMeta`** (`lib/services/header_footer_service.dart`): header, footer, slideNumber, dateTime (auto/tĩnh), dateTimeFormat, excludeFirst — serialize/deserialize JSON, tích hợp vào `PresentationState` + `ConfigService` persistence.
- **UI "Chèn Header & Footer"** (`lib/screens/widgets/header_footer_dialog.dart`): dialog từ ribbon → nhập header/footer text, checkbox slide number, date/time (auto/tĩnh + format), exclude first slide; áp dụng cho toàn deck.
- **PPTX — slide master footer shapes**: `<p:ph type="hdr|ftr|sldNum|dt">` + `<a:fld>` dynamic field (slide number: `type="slidenum"`, date: `type="datetime1"`) — PowerPoint tự cập nhật ngày giờ khi mở file. Header/footer shapes được nhúng vào `<p:spTree>` của `slideMaster1.xml`.
- **excludeFirst (P7)**: `DeckMeta.excludeFirst` tôn trọng trong cả 3 định dạng — **PPTX** `showMasterSp="0"` trên slide 1 (ẩn master footer shapes), **HTML** JS `hfExcludeFirst` ẩn `.ghita-hf` trên slide đầu, **PDF** `_wrapWithHF` bỏ qua header/footer/num/date trên trang đầu.
- **HTML/PDF**: HTML: fixed header/footer bar (`ghita-hf` CSS + divs); PDF: `_wrapWithHF` wraps slide canvas with header/footer Row + slide number + date.
- **Toolbar**: nút "Đầu trang & Chân trang".
- i18n EN/VI: 12 chuỗi mới.

### 🔬 Kiểm chứng (P9, P10)
- 22 test tự động mới (`test/header_footer_test.dart`): DeckMeta round-trip + defaults; masterFooterShapesXml — header/footer/sldNum/dt field shapes; PPTX master includes footer shapes; a:fld slidenum; **PPTX showMasterSp="0" khi excludeFirst**; **HTML header/footer divs + excludeFirst JS hide**; **PDF header/footer wrap + excludeFirst skip**; regression deck không config → master không có footer shapes.
- `flutter analyze` 0 lỗi/warning; full suite **317/317 test xanh** (+22 mới).

### Giới hạn trung thực
- Ngày giờ động dùng `<a:fld type="datetime1">` — PowerPoint cập nhật khi mở; định dạng theo locale hệ thống (không override riêng).

---

## [2.0.0-beta] - 2026-08-15 — Dev (2.0.0-beta M1/M2) — Track 18: Nút hành động, Equation, Symbol, OLE (FEAT 17, 18, 19, 20)

### ✨ Tính năng mới
- **Action buttons** (`lib/services/action_button_service.dart` + `action_button_dialog.dart`): 12 loại nút chuẩn (Home, Next, Back, End, Info, Help, Movie, Sound, Document, Begin, Custom) — chọn loại, hành động (slide next/prev/first/last, URL, file, program), nhãn, màu; block slide: `<div data-action='{json}'>`.
  - **PPTX**: `<p:sp>` + `<a:hlinkClick action="ppaction://hlinksldjump">` (slide jump) hoặc `r:id` hyperlink (URL/file) — prstGeom theo loại nút (chevron/homePlate/info/question...).
  - **HTML**: button styled div (position:absolute %).
  - **PDF**: labelled button box.
- **Equation** (`lib/services/equation_service.dart` + `equation_dialog.dart`): MathML → OOXML `<m:oMath>` converter (mfrac, msqrt, msup, msub, msubsup, munderover ∑, mtable matrix, mrow) — dialog chọn mẫu (fraction, sqrt, quadratic, sum, integral, matrix 2×2, E=mc²) hoặc nhập MathML tùy chỉnh; block: `<div data-equation='{json}'>`.
  - **PPTX**: `<p:sp>` với `<m:oMath>` (namespace `m` khai báo root slide) + `a:mathPr` Cambria Math; fallback plain text.
  - **HTML/PDF**: hiển thị dạng text fallback italic.
- **Symbol** (`lib/services/symbol_service.dart` + `symbol_dialog.dart`): ~200 ký hiệu Unicode 5 nhóm (Currency, Arrows, Math, Greek, Technical, Misc) — lưới chọn, tìm theo tên/ký tự/mã U+XXXX; chèn vào slide dạng `<p>`.
- **Toolbar**: 3 nút mới "Nút hành động", "Công thức", "Ký hiệu".
- i18n EN/VI: 19 chuỗi mới.

### 🔬 Kiểm chứng (P8, P10)
- 27 test tự động mới (`test/actions_equation_symbol_test.dart`): ActionButton round-trip/defaultLabel/htmlMarkup; actionsIn/replaceActionAt; PPTX p:sp + ppaction://hlinksldjump + hyperlink rels; HTML button; Equation round-trip; mathmlToOoxml fraction/sqrt/sup; PPTX m:oMath + namespace; **HTML inline SVG (viewBox, fraction bar, radical path)**; **PDF widget tree**; SymbolService categories/search/code-point; **OLE oleObj + progId + oleObject bin + HTML document icon**; **regression hyperlink text thường vẫn hoạt động** (hlinkClick + rels external) + deck không track-18 features không đổi.
- `flutter analyze` 0 lỗi/warning; full suite **295/295 test xanh** (+27 mới).

### Giới hạn trung thực
- Action slide-jump dùng `ppaction://hlinksldjump` chuẩn PowerPoint (chưa có `p14:action` slide-target cụ thể — mặc định next/prev/first/last).
- Symbol chưa có ô "nhập mã Unicode trực tiếp" chuyên dụng (tìm U+XXXX trong search box — có).
- OLE embedding: file nhúng vào `ppt/media/`, không phải `ppt/embeddings/` (PowerPoint vẫn mở được — OOXML validator không báo lỗi).

---

## [2.0.0-beta] - 2026-08-14 — Dev (2.0.0-beta M1/M2) — Track 17: WordArt & TextBox tự do (FEAT 15, 16)

### ✨ Tính năng mới
- **Model `FreeTextShape`** (`lib/models/free_shape.dart`): x/y/w/h (% slide), text, rotation, z-order, font/size/weight/style, color, background, border, shadow, wordArtStyle; HTML markup sinh position:absolute với % tọa độ; serialize/deserialize toMap/fromMap/JSON.
- **WordArt: 12 styles** (`lib/services/wordart_service.dart`): Fill (Black/Blue/Orange/Green), Gradient (Linear/Radial/Diagonal), Wave, Outline, Shadow, Reflection, Glow — mỗi style có CSS (cho HTML deck + canvas overlay) + OOXML `<a:gradFill>`/`<a:effectLst>` (cho PPTX).
- **CanvasOverlay** (`lib/screens/editor/canvas_overlay.dart`): drag-to-move, resize handle (bottom-right), delete button, z-order sorting, selection highlight — nằm trên preview HTML editor.
- **FreeTextEditDialog** (`lib/screens/widgets/free_text_edit_dialog.dart`): sửa text, tọa độ %, kích thước, font, màu, nền, viền, đổ bóng, rotation, z-order, WordArt style + preview nhỏ.
- **Engine export — ĐỌC thật `visualElements`** (Track 17, P3 — không bỏ qua như trước):
  - **PPTX**: mỗi FreeTextShape → `<p:sp>` với `<a:xfrm>` x/y/w/h EMU tuyệt đối (không xếp dọc), `<a:prstGeom>`, fill gradient/solid/noFill, border, WordArt effect, `<a:rPr>` font/size/color/bold/italic, rotation `rot` attribute.
  - **HTML**: `<div style="position:absolute; left:X%; top:Y%; width:W%; height:H%; ...">` — giữ % tọa độ.
  - **PDF**: `pw.Positioned` + `pw.Container` với `left/top` tính từ % (1% = 0.75pt).
- **Toolbar**: nút "Thêm hộp văn bản" (icon text_fields) → dialog → `updateFreeTexts` → `addSlide` (history).
- i18n EN/VI: 11 chuỗi mới.

### 🔬 Kiểm chứng (P10)
- 17 test tự động mới (`test/free_text_wordart_test.dart`): FreeTextShape round-trip (toMap/fromMap/JSON); htmlMarkup % tọa độ; WordArt 12 styles + CSS + OOXML gradFill/effectLst; PPTX TextBox 30%,40% → EMU đúng (2743200,2743200); WordArt gradient fill; WordArt shadow; rotation attribute; regression deck không visualElements; HTML absolute divs; PDF render; Slide.visualElements persistence.
- `flutter analyze` 0 lỗi/warning; full suite **268/268 test xanh** (+17 mới).

### Giới hạn trung thực
- Canvas overlay dùng px scale tạm (4× % → px) — chưa đồng bộ kích thước preview thật.
- WordArt OOXML chỉ hỗ trợ gradient fill + effect cho style 5/6/7/9/10/12; các style còn lại dùng solid fill hoặc CSS fallback.
- Chưa có kéo-thả resize tỷ lệ khung hình (resize handle tự do).
- `visualElements` key là `freeTexts` — tương thích ngược với Slide cũ không có key này.

---

## [2.0.0-beta] - 2026-08-14 — Dev (2.0.0-beta M1/M2) — Track 16: Screenshot nhanh & Photo Album (FEAT 13, 14)

### ✨ Tính năng mới
- **Screenshot service** (`lib/services/screenshot_service.dart`): chụp **toàn màn hình / cửa sổ active / vùng chọn** bằng PowerShell `Add-Type` C# helper (`Graphics.CopyFromScreen` — .NET built-in, không cần FFmpeg/plugin, chạy Windows 7+).
- **UI "Chụp màn hình"** (`lib/screens/widgets/screenshot_dialog.dart`): SegmentedButton 3 chế độ, nhập tọa độ vùng, nút Capture/Recapture + preview, báo lỗi thân thiện khi thất bại; sau khi chụp → **mở `ImageEditorDialog` (đã có) để crop** → chèn `<img>` vào slide hiện tại.
- **Photo Album** (`lib/screens/widgets/photo_album_dialog.dart`): chọn **nhiều ảnh** (file_picker multi), chọn layout — **1 ảnh / 2 ảnh / 1 lớn + 2 nhỏ / Lưới 2×2 / Lưới 3 / Lưới 4**; tùy chọn **caption** (tên file, sửa được), **frame viền**, **chuyển tiếp mặc định** (Fade/Push/Zoom) giữa slide ảnh.
- **Sinh tự động N slide**: ảnh chia theo layout (1/2/3/4 ảnh mỗi slide) → slide HTML có `<img>` (nén JPEG 85% nếu nhỏ hơn — tái dùng Track 03 pipeline) + `layoutType = pictureAndCaption` + `effect` theo lựa chọn; **chèn vào cuối deck** (`addSlide` + history).
- **Toolbar**: 2 nút mới "Chụp màn hình" + "Album ảnh".
- i18n EN/VI: 20 chuỗi mới (screenshot modes/capture/failed/use, photo album empty/pick/count/caption/frame/transition/create/created).

### 🔬 Kiểm chứng (P7, P10)
- 13 test tự động mới (`test/screenshot_photo_album_test.dart`): ScreenshotService 3 mode không crash (trả null khi không có màn hình); batching ảnh đúng theo từng layout (single 5→5, two 5→3+2+1, grid2x2 10→3 nhóm, oneLargeTwoSmall 7→3+3+1); slide sinh đúng `pictureAndCaption`; transition bật/tắt; regression addSlide/upsertVideo không đổi.
- `flutter analyze` 0 lỗi/warning; full suite **251/251 test xanh** (+13 mới).

### Giới hạn trung thực
- Screenshot cần **Windows + .NET System.Drawing** (chạy qua PowerShell — máy có PowerShell 5.1+ mặc định); vùng chọn nhập tọa độ số (chưa có overlay kéo-thả trực quan).
- Chụp cửa sổ = cửa sổ **đang active** (GetForegroundWindow).
- Photo album chưa hỗ trợ tải ảnh từ web; caption mặc định = tên file (sửa được trước khi tạo).

---

## [2.0.0-beta] - 2026-08-14 — Dev (2.0.0-beta M1/M2) — Track 15: Thư viện Icons & Ảnh kho (FEAT 11, 12)

### ✨ Tính năng mới
- **Model `IconItem`** (`lib/models/icon_item.dart`): name, category, svgPath, color, size; block trong slide HTML: `<span data-icon='{json}'>`.
- **Thư viện icons nhúng ~150 icon SVG** (`lib/services/icon_library_service.dart`): path `d` Material/Fluent-style, 10 nhóm (UI, Navigation, Media, Communication, Business, Education, Arrows, Devices, Time, Travel, Status, Text); **SVG path parser + rasterizer tự viết** (`package:image`: M/L/H/V/C/S/Q/T/A/Z, curve sampling, fill + stroke) — không cần SVG renderer, chạy được trong export isolate.
- **UI "Chèn biểu tượng"** (`lib/screens/widgets/icon_dialog.dart`): tìm kiếm, lọc nhóm, chọn màu (8 swatch), slider kích thước 16–96px, thumbnail PNG render thật, tap = chèn; nút toolbar "Chèn icon".
- **PPTX — icon thành `<p:pic>` PNG**: render PNG 48px màu chọn → `ppt/media/image{n}.png` + rel image + dedupe SHA-256 (2 icon giống nhau → 1 media part); block nằm trong layout flow như ảnh.
- **HTML deck — inline SVG**: `<span data-icon>` thay bằng `<svg>` đúng màu/kích thước, giữ `data-icon` để sửa lại.
- **PDF — icon PNG raster** ở vị trí block.
- **Ảnh kho local** (`lib/services/stock_media_service.dart` + `stock_media_dialog.dart`): 18 ảnh minh họa SVG tự sinh CC0-style (Nature, Business, Technology, Education, Abstract, People) — chèn dạng `<img src="data:image/svg+xml;base64,...">`.
- **Trạng thái "Đã chèn"** snackbar + i18n EN/VI.

### 🔬 Kiểm chứng (P10)
- 10 test tự động mới (`test/icon_library_pipeline_test.dart`): model round-trip; svgMarkup đúng màu/kích thước; iconCount/iconsIn/replaceIconAt; renderPng ra PNG hợp lệ (magic bytes); PPTX `<p:pic>` + media PNG + rel + dedupe; HTML inline SVG giữ data-icon; PDF render; deck không icon không đổi; icon payload rỗng bị skip.
- `flutter analyze` 0 lỗi/warning; full suite **238/238 test xanh** (bao gồm 10 test mới).

### Quốc tế hóa
- 11 chuỗi mới vào .arb EN/VI: insert/search/recent/color/no-results/inserted cho icon + stock media.

### Giới hạn trung thực
- Icons nhúng là **SVG path rasterized bằng bộ vẽ tự viết** (không phải file font) — đủ đẹp cho icon đơn sắc Material/Fluent; không hỗ trợ gradient/pattern fill phức tạp.
- Ảnh kho là **vector minh họa tự sinh** (CC0-style, không phải ảnh bitmap thật); chưa có tìm ảnh Bing/Unsplash online (P6 roadmap — tùy chọn + sau).
- Lịch sử icon gần đây (P7) dừng ở hiển thị "Recent" trong dialog (theo phiên).

---

## [2.0.0-beta] - 2026-08-12 — Dev (2.0.0-beta M1/M2) — Track 14: Mô hình 3D (FEAT 10)

### ✨ Tính năng mới
- **Model `Model3DData`** (`lib/models/model3d_item.dart`): src (GLB data URI), posterSvg (tự sinh), rotate, name; block trong slide HTML: `<div data-model3d='{json}'>`.
- **PPTX — shape `am3d:model3d` chuẩn Office 2017**: `<mc:AlternateContent>` (Choice `Requires="am3d"` + Fallback `p:pic`) chứa graphicFrame `am3d:model3d` — spPr/camera/trans/raster (poster PNG tự vẽ bằng `package:image`)/objViewport/ambientLight + 3 point-lights + a3danim extLst; GLB nhúng `ppt/media/model3d{n}.glb` + rel `…/office/2017/06/relationships/model3d` + Default `glb` (`model/gltf-binary`) trước Override; dedupe SHA-256.
- **Tự xoay (rotate)**: phát animation nhúng đầu tiên của mô hình khi mở slide — a3danim `embedAnim` + timeline `Animate embedded1` (idBase 100 tránh đụng timeline video/audio); không rotate → extension tồn tại nhưng không có timing (PowerPoint bắt buộc có extension).
- **HTML deck**: poster SVG + ghi chú "mở trong PowerPoint để xem & xoay" — **KHÔNG nhúng GLB** (JSON attribute được làm gọn, bỏ payload megabyte).
- **PDF**: placeholder "3D Model — Xem trong PowerPoint" (không vẽ SVG — limit).
- **UI**: nút **"Chèn mô hình 3D"** (icon view_in_ar) trên toolbar → dialog: FilePicker GLB (kiểm tra magic `glTF` — file không hợp lệ báo lỗi rõ), preview poster tự sinh + badge "3D" (không cần 3D renderer), checkbox tự xoay, tên mô hình; sửa model đã chèn (`upsertModel3d` + dropdown).
- Namespace `am3d/a16/p14/a3danim` khai báo trên **root slide** đúng như PowerPoint tự ghi.

### 🔬 Kiểm chứng thật (P10)
- **GLB mẫu tự sinh** (glTF 2.0 hợp lệ — Khronos validator 0 lỗi, tam giác màu + material + NORMAL): bản nhỏ 908B và bản **~5MB** (BIN padded, byteLength hợp lệ).
- **PowerPoint COM**: cả 2 deck (nhỏ + 5MB, một deck rotate=true) mở **OK slides=1** — shape nhận dạng **type=30 (3D model)**; deck HTML mở Chrome: poster SVG + note hiển thị, **không chứa payload GLB**.
- **Bisect gian khổ ghi lại (giá trị cho các track sau)**: 2 lỗi khiến PowerPoint từ chối deck 3D — (1) thiếu đồng thời extLst a3danim + point-lights; (2) **`a16:creationId` phải là GUID RFC-4122 v4 hợp lệ** (chuỗi counter-style bị reject dù cùng format 8-4-4-4-12); thêm: các namespace phải khai báo trên root slide. Golden lấy từ **mẫu chính thức `AnimatedModel3DExample` của Microsoft** (dotnet Open-XML-SDK, chạy được trên máy).
- 9 test tự động: model round-trip; PPTX package (part glb + Default glb + rel 2017/06 + mc:AlternateContent + am3d + raster + rotate timeline/không rotate không timing + dedupe + skip rỗng + deck không 3D không đổi); HTML (poster + note, không GLB bytes, JSON slim); PDF placeholder.

### 🈺 Quốc tế hóa
- 11 chuỗi mới vào .arb EN/VI: insert/edit 3D, pick GLB, invalid file, tên mô hình, tự xoay (+ hint), existing/inserted/updated.

### Giới hạn trung thực
- Preview trong app = poster tự sinh + badge (không renderer 3D — roadmap cho phép).
- HTML/PDF không nhúng model thật (roadmap P7) — ghi chú dẫn về PowerPoint.
- "Tự xoay" phát **animation nhúng của mô hình** (glTF animations) — GLB không có animation thì chỉ hiển thị poster (đúng giới hạn định dạng PowerPoint).
- 3D cần máy có DirectX/GPU (đã kiểm chứng trên máy có RTX 3050).

---

## [2.0.0-beta] - 2026-08-12 — Dev (2.0.0-beta M1/M2) — Track 13: Audio & Narration gắn slide (FEAT 8, 9 + OPT 31)

### ✨ Tính năng mới
- **Nối lại `AudioRecorderPanel`** (trước đây chết) vào editor **cạnh ô Notes** (`html_editor_panel.dart`): ghi âm mic → dừng → **tự nén WAV → m4a bằng FFmpeg** (`-c:a aac 128k`) — không còn WAV cồng kềnh; không FFmpeg → giữ WAV (limit).
- **Model**: `Slide.audioPath` + `Slide.audioEmbedded` + `Slide.audioOptions` (durationMs, autoplay, loop, acrossSlides, hideIcon, trimStart, trimEnd) — toMap/fromMap tương thích ngược + `copyWith(clearAudio)`.
- **PPTX `<p:audio>`**: shape `<p:pic>` đúng cấu trúc PowerPoint tự ghi (golden COM `AddMediaObject2`): `p:nvPr/a:audioFile` (rel `…/audio`) + `p14:media` ext + **icon loa chuẩn PowerPoint** (trích từ golden, nhúng base64 const) + `p:timing` — autoplay `playFrom(0.0)` (dur = durationMs), loop `repeatCount="indefinite"`, **dừng khi rời slide** qua `endCondLst onStopAudio` (bỏ khi chọn "phát xuyên slide"); dedupe theo SHA-256; Default `m4a`/`wav` trước mọi Override.
- **HTML deck**: `<audio controls data-src>` + `ghitaAudios` map (base64, MIME chuẩn `audio/mp4` — Chrome từ chối `audio/m4a`) + inject khi slide active; options: loop/autoplay/trim (currentTime + clamp), **ẩn icon** → nút toggle nhỏ, **phát xuyên slide** → pause-all bỏ qua audio có `data-across`; tự pause khi đổi slide.
- **Trim**: cắt thật bằng FFmpeg (`-ss/-to -c copy`, fallback re-encode) — file nhúng tự cắt; không FFmpeg → timestamps (HTML tôn trọng).
- **Bundle `.ghita`**: implement `media/` (document cũ nhưng chưa có) — `saveProjectBundle(mediaFiles:)` + slides.json ghi `audioPath: 'media/…'` + `audioEmbedded`; `loadProjectBundle` extract về thư mục audio + rewrite path → **mở project trên máy khác vẫn có narration**.
- Ghi âm thất bại/không có quyền mic → xử lý mượt (không crash).

### 🔬 Kiểm chứng thật (P10)
- **PPTX**: deck có narration m4a thật (FFmpeg sine 2s, autoplay + loop) mở **OK** trong PowerPoint COM (`OK slides=1`), shape nhận dạng **type=16 (ppMedia)** tên "Narration".
- **HTML deck**: Chrome headless — thẻ `<audio>` nhận `src` từ `ghitaAudios` khi slide active; probe decode payload base64: **readyState=4, duration 2s** (đã sửa MIME `audio/m4a` → `audio/mp4` vì Chrome báo MEDIA_ERR_SRC_NOT_SUPPORTED).
- **Ghi âm mic thật (gate P10 hoàn tất)**: máy có **Microphone Array (AMD Audio Device)** — chạy `integration_test/mic_recording_test.dart -d windows` (app Windows thật, plugin `record` nạp được — `flutter test` thường không nạp plugin desktop) → **ghi mic 2.85s → transcode m4a (12.4KB) → probe 2849ms PASS**. Bản ghi thật đó được đưa qua đủ chuỗi: xuất PPTX → **PowerPoint COM mở OK slides=1 + shape type=16 (ppMedia) "Narration"**; xuất HTML deck → **Chrome: src inject + decode readyState=4, 2.8s**.
- 10 test tự động: Slide audio round-trip + backward-compat + clearAudio; PPTX package (media/audio1.m4a, Default m4a, rels audio, a:audioFile, icon, timing autoplay/loop/across/onStopAudio, deck không audio không đổi); HTML deck (ghitaAudios, data-src, hide-icon, across exception, MIME mp4); bundle round-trip (media entry + extract + path rewrite).

### 🈺 Quốc tế hóa
- 10 chuỗi mới vào .arb EN/VI: ghi narration, chưa có narration, duration, trim, không FFmpeg, tự phát, lặp, xuyên slide, ẩn icon, xóa.

### Giới hạn trung thực
- **Mic**: kiểm chứng thật trên máy có Microphone Array — integration test (app Windows + plugin `record`). Trên máy không có mic/quyền, panel xử lý mượt (không crash).
- **Phát xuyên slide ở PPTX**: chỉ HTML deck hỗ trợ đầy đủ (PPTX bỏ `onStopAudio` khi chọn across — PowerPoint tự quyết định thời điểm dừng); loop PPTX qua `repeatCount` (mở OK).
- Trim không FFmpeg → timestamps (HTML-only).
- Audio luôn nhúng trong bundle khi lưu `.ghita`; sau khi load ở máy khác, file extract về `Documents/GhitaPPT/audio/`.

---

## [2.0.0-beta] - 2026-08-12 — Dev (2.0.0-beta M1/M2) — Track 12: Quay màn hình (FEAT 7)

### ✨ Tính năng mới
- **Backend FFmpeg gdigrab** (`lib/services/screen_recorder_service.dart`): quay toàn màn hình / cửa sổ (chọn từ danh sách `Get-Process` MainWindowTitle) / vùng tùy chỉnh (tọa độ + kích thước pixel); codec `libx264 ultrafast yuv420p` — đúng định dạng PPTX/Chromium; không cần plugin, không cần quyền đặc biệt, chỉ cần ffmpeg/ffprobe trên PATH (cùng phụ thuộc tùy chọn như Track 11).
- **Điều khiển thu**: đếm ngược 3s trước khi quay, timer mm:ss + chấm đỏ khi đang quay, **Pause/Resume** (cắt segment + nối bằng concat demuxer `-c copy` — ghép không mất chất lượng), **Stop** dừng mượt bằng stdin `q`.
- **Giới hạn**: maxDuration 300s + maxSize 100MB (tự dừng + thông báo lý do), cảnh báo đĩa < 500 MB trước khi quay (hỏi "vẫn quay?").
- **Xử lý lỗi**: không có FFmpeg → màn hình hướng dẫn cài đặt; quay thất bại → thông báo rõ.
- **Nhúng vào slide ngay**: sau Stop, preview kết quả (poster frame FFmpeg + thời lượng + dung lượng) → "Chèn vào slide" qua `upsertVideo` — tái dùng đúng pipeline Track 11 (`<video data-video>` → PPTX `p:pic` ppMedia + timing, HTML deck `ghitaVideos` + player, PDF poster).
- **Sửa lỗ hổng 100KB (ảnh hưởng cả Track 11)**: sanitizer `validateAndSanitizeHtml` giờ áp giới hạn cho **nội dung text** — payload `data:…;base64` được miễn, slide chứa video vài MB vẫn Save được; text > 100KB vẫn bị chặn.
- UI: nút **"Quay màn hình"** trên toolbar editor (cạnh nút Chèn video).

### 🔬 Kiểm chứng thật (P10)
- **Quay thật trên máy** (gdigrab vùng 640×360, ~6s với Pause giữa chừng): 2 segment ghép lại → mp4 5,8s hợp lệ (ffprobe xác nhận), dừng bằng stdin `q` mượt.
- **PPTX**: deck chứa bản quay mở **OK** trong PowerPoint COM (`OK slides=1`), shape nhận dạng **type=16 (ppMedia)**.
- **HTML deck**: mở trong Chrome headless (engine WebView2) — `src` được inject từ `ghitaVideos` khi slide active; probe decode payload thật: **PLAYABLE readyState=4, 5.8s**.
- 9 test tự động: `buildCaptureCommand` 3 mode (args chính xác), `buildConcatList`, probes window/disk, sanitizer media-aware (3 test: video >100KB qua, text >100KB chặn, block elements vẫn strip).

### 🈺 Quốc tế hóa
- 29 chuỗi mới vào .arb EN/VI: dialog quay màn hình (modes, cửa sổ, tọa độ vùng, start/countdown/pause/resume/stop, duration/size, insert/discard, hướng dẫn FFmpeg, cảnh báo đĩa, giới hạn…).

### Giới hạn trung thực
- **Bắt buộc FFmpeg** (không có → hướng dẫn cài; không fallback khác).
- Quay cửa sổ yêu cầu cửa sổ **không minimized** và tên trùng chính xác (giới hạn của gdigrab).
- Vùng tùy chỉnh nhập **tọa độ số** (chưa có drag-region overlay — ghi TODO).
- Pause = ghép segment (có thể lệch vài frame tại điểm nối); quay gồm cả cửa sổ ứng dụng nếu nằm trong vùng chọn.
- Dừng tự động khi đạt giới hạn: lưu vào temp, dialog hiện preview như bình thường.

---

## [2.0.0-beta] - 2026-08-12 — Dev (2.0.0-beta M1/M2) — Track 11: Video nhúng & chỉnh (FEAT 5, 6, 76)

### ✨ Tính năng mới
- **Model `VideoData`** (`lib/models/media_item.dart`): src/poster (data URI), trimStart/End, autoplay, loop, youtubeId, durationMs, bookmarks; JSON round-trip. Video trong slide HTML là thẻ `<video src="data:video/mp4;base64,…" poster="…" controls data-video='{json}'>` — sanitizer cho phép thẻ video, payload đi cùng htmlContent như ảnh.
- **PPTX — shape media thật**: `<p:pic>` kiêm poster + video đúng cấu trúc PowerPoint tự ghi (golden từ COM `AddMediaObject2`): `p:nvPr/a:videoFile` (rel `…/video`), `p14:media` (rel `…/2007/relationships/media`), poster `blipFill`, `hlinkClick r:id="" action="ppaction://media"` (không cần hyperlink rel); `Default mp4` đặt trước mọi Override; dedupe mp4 theo SHA-256 (1 part / nhiều thẻ).
- **Playback options trong PPTX**: `p:timing` chuẩn PowerPoint — on-click = interactiveSeq + `togglePause`; autoplay = mainSeq + `playFrom(0.0)` (dur = durationMs probe bằng ffprobe); loop = `repeatCount="indefinite"` trên media node; nhiều video gộp chung 1 timing (id tuần tự).
- **HTML deck (WebView2)**: payload hoist vào `ghitaVideos` (mp4 + poster), thẻ `<video>` nhận `data-src`/`data-poster` + `preload="none"`, JSON inline chỉ còn metadata (không trùng megabyte); player JS `setupVideo`: áp trim (currentTime + clamp end), loop/autoplay, danh sách bookmark (click → nhảy), YouTube → thumbnail + nút mở ngoài (vẫn chặn iframe); tự pause mọi video khi đổi slide.
- **PDF**: vẽ poster frame của video (hoặc hộp placeholder "Video" khi không có poster).
- **UI**: nút **Chèn video** trên toolbar editor → dialog: chọn file MP4 (FilePicker) hoặc dán link YouTube (parse id + thumbnail qua http có guardrail 10s/2MB); **FFmpeg tự động khi có**: probe duration, lấy frame đầu làm poster, **trim thật** (stream copy, fallback re-encode nhanh); chọn/đổi poster riêng; checkbox tự phát/lặp; bookmark thêm/xóa; sửa video đã chèn (`upsertVideo` + `replaceVideoAt`).
- **Chống rỗng**: video không payload (không src, không online) bị bỏ qua khi xuất PPTX/HTML.
- Toolbar editor chuyển thành **cuộn ngang** — không tràn trên cửa sổ hẹp.

### 🔬 Kiểm chứng PowerPoint thật (P10)
- Deck có video mp4 thật (FFmpeg sinh 3s, autoplay + loop) mở **OK** trong PowerPoint COM (`OK slides=1`, không 0x80070570); COM nhận dạng shape đúng loại **ppMedia (type=16)** — không chỉ là pic thường.
- Cấu trúc shape so khớp golden PowerPoint thật (sinh bằng `AddMediaObject2` + `PlaySettings.PlayOnEntry/LoopUntilStopped`): dạng `p:pic` + `a:videoFile` trong `nvPr` + `p14:media` ext + timing 2 tầng; autoplay = `playFrom(0.0)` + `sldTgt` cond; loop = `repeatCount="indefinite"`.

### 🧪 Kiểm thử
- `test/video_pipeline_test.dart` (12 test): model round-trip + `parseYouTubeId` 4 dạng URL; PPTX package (media/video1.mp4, Default mp4 trước Override, rels video+media+image, p:pic + a:videoFile + ppaction://media, timing autoplay/loop `playFrom`+`repeatCount`, on-click interactiveSeq, dedupe 1 part/2 thẻ, YouTube rel external, empty skip + deck không video không đổi); HTML deck (ghitaVideos map, data-src/preload, JSON gọn không chứa payload, JS setupVideo/trim/bookmarks/youtube/pause **còn nguyên sau minify**); PDF poster; sanitizer cho phép `<video>`.

### 🈺 Quốc tế hóa
- 26 chuỗi mới vào .arb EN/VI: dialog video (insert/edit/file/youtube/trim/poster/bookmarks/autoplay/loop/invalid url/no ffmpeg…).

### Giới hạn trung thực
- **Bookmark & loop**: chỉ phát huy ở HTML deck (OOXML không có bookmark; PPTX loop qua `repeatCount` — mở OK, hành vi phát phụ thuộc PowerPoint).
- **Trim**: áp dụng cho file nhúng chỉ khi có FFmpeg tại lúc chèn; không có FFmpeg → nhúng nguyên file + timestamps (chỉ HTML tôn trọng; PPTX phát cả file).
- **YouTube**: PPTX giữ poster + link ngoài (phát cần PowerPoint + mạng); chưa kiểm chứng phát thật trong slideshow bằng UI tự động.

---

## [2.0.0-beta] - 2026-08-11 — Dev (2.0.0-beta M1/M2) — Track 10: SmartArt (FEAT 4)

### ✨ Tính năng mới
- **Model `SmartArtGraph` + 28 layout** (`lib/models/smartart.dart`): 8 nhóm PowerPoint (List, Process, Cycle, Hierarchy, Relationship, Matrix, Pyramid, Picture) × 3–6 layout mỗi nhóm; node cây (parentId), 3 chủ đề màu (Office / Sắc màu / Đậm).
- **PPTX — `<dgm:>` package**: `data{n}.xml` (dataModel: ptLst/cxnLst) + `layout1.xml` + `quickStyle1.xml` + `colors1.xml` (màu theo theme) + slide binding `<dgm:relIds r:dm/r:lo/r:qs/r:cs>` + ContentTypes; dedupe theo JSON (1 data part / nhiều graphicFrame). *Đã kiểm chứng mở được trong PowerPoint thật — xem 🔬 bên dưới.*
- **HTML/PDF**: SVG inline cho cả 8 nhóm (hộp/chevron/vòng/hệ phân cấp/ma trận/kim tự tháp/ảnh) + painter PDF cùng bảng màu; preview trong dialog.
- **UI**: nút **Chèn SmartArt** trên toolbar → dialog: thumbnail layout theo nhóm, ngăn văn bản (text pane) thêm/xóa mục, chọn chủ đề màu, **relayout giữ nguyên nội dung**; danh sách "SmartArt trong slide" cho chỉnh sửa; `upsertSmartArt` đồng bộ cả 3 định dạng qua `data-smartart`.
- **Chống crash rỗng**: sơ đồ không node bị bỏ qua khi xuất PPTX + SVG "Không có nội dung SmartArt".

### 🔬 Kiểm chứng PowerPoint thật (P8)
- Dùng PowerPoint COM (`Presentations.Open`) mở deck sinh bởi đúng code path: deck chỉ văn bản **OK**, deck có chart **OK**, deck có SmartArt **OK**, deck kết hợp text + chart + SmartArt **OK** (`OK slides=1`, không lỗi 0x80070570, không cần Repair).
- **2 lỗi làm PowerPoint từ chối toàn bộ deck khi có SmartArt được tham chiếu** (deck không frame vẫn mở — bisection 2 phía + golden từ Word `SmartArtLayouts` thật):
  1. Frame slide phải dùng dạng mới `<dgm:relIds r:dm=… r:lo=… r:qs=… r:cs=…/>` — dạng cũ `<dgm:diagram dgm:dataId=…/>` bị PowerPoint hiện đại đánh rơi (0x80070570) dù đúng schema cũ.
  2. `<dgm:t>` trong dataModel phải là text body đầy đủ (`<a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>…`) — chuỗi text trần làm diagram engine crash khi load.
- Bisection từng part (đổi 1 part tại một lần so với golden Word): layout/quickStyle/colors của Ghita đều vượt qua engine; chỉ dataModel sai 2 điểm trên. Giới hạn trung thực: layoutDef vẫn là bản generic tối giản (rendering đúng ý đồ tối giản "flat nodes"; đổi layout trong PowerPoint hoạt động vì binding theo relIds); kiểm chứng render pixel không thực hiện — chỉ kiểm chứng mở + nạp diagram không lỗi.

### 🧪 Kiểm thử
- `test/smartart_test.dart` (9 test): model round-trip + relayout giữ text + đổi màu, dgm package (data/layout/quickStyle/colors well-formed, ptLst/cxnLst/srcId, text-body `<dgm:t>` + rels `r:dm/r:lo/r:qs/r:cs` theo dạng đã kiểm chứng PowerPoint, ContentTypes, dedupe 1 part/2 frame, empty skip, deck không SmartArt không có part diagram), HTML SVG từng nhóm, PDF hợp lệ.

### 🈺 Quốc tế hóa
- 20 chuỗi mới vào .arb EN/VI: tên 8 nhóm + dialog (insert/edit/title/layouts/text pane/add node/color theme/existing/inserted/updated…).

---

## [2.0.0-beta] - 2026-08-11 — Dev (2.0.0-beta M1/M2) — Track 09: Khung dữ liệu kiểu Excel + workbook nhúng (FEAT 3)

### ✨ Tính năng mới
- **`ChartDataGrid`**: lưới dữ liệu kiểu Excel trong dialog biểu đồ — cột A = nhãn, các cột sau = chuỗi series; thêm/xóa dòng & cột, chọn ô (viền highlight), **dán CSV** (paste vào ô đã chọn hoặc thay cả lưới), **Điền nhanh** (10, 20, 30…).
- **Workbook thật** (`EmbeddedWorkbookService`): xlsx tự build bằng `archive` đúng chuẩn — `sheet1` + **`sharedStrings`** (t="s") + styles/workbook/rels/ContentTypes; dữ liệu theo quy ước Excel-chart (A1 trống, B1.. tên chuỗi, A2.. nhãn). Nhúng vào chart package → PowerPoint mở "Chỉnh dữ liệu trong Excel" được ngay.
- **Map lưới → caches**: numCache/strCache trong `chartN.xml` phản chiếu đúng workbook (test mirror: đổi giá trị workbook → re-export → cache khớp).
- **Đồng bộ 2 chiều**: lưới ↔ `ChartData` ↔ dialog → `upsertChart` (data-chart) → cả PPTX/PDF/HTML cập nhật tự động.
- **Nhập CSV**: paste CSV + `parseCsv` (xử lý dấu ngoặc kép, dấu phẩy trong ô, CRLF). *Ghi chú: nút chọn file (file_picker) chưa bổ sung do môi trường offline — luồng paste dữ liệu đã hoạt động.*
- **Chống crash chart rỗng** (P10): biểu đồ không series/giá trị bị bỏ qua khi xuất PPTX (không sinh `<c:chart>` rỗng dễ repair prompt) và hiển thị "Không có dữ liệu biểu đồ" trong SVG.

### 🧪 Kiểm thử
- `test/embedded_workbook_test.dart` (5 test): xlsx thật (workbook/sheet/sharedStrings/styles, t="s", uniqueCount, XML hợp lệ), CSV (quote/kép/CRLF), grid→ChartData, mirror workbook↔chart caches + refs `Sheet1!$B$2:$B$4`, empty-chart skip + SVG friendly.

### 🈺 Quốc tế hóa
- 8 chuỗi mới vào .arb EN/VI: `chartData`, thêm/xóa dòng, thêm/xóa chuỗi, điền nhanh, dán CSV.

---

## [2.0.0-beta] - 2026-08-11 — Dev (2.0.0-beta M1/M2) — Track 08: Động cơ Biểu đồ thật (FEAT 1, 2)

### ✨ Tính năng mới
- **Model `ChartData` + `ChartService`**: biểu đồ sống trong slide HTML dưới dạng `<div data-chart='{json}'>` — 14 loại (Column, Bar, Line, Pie, Area, Donut, Combo, Treemap, Sunburst, Histogram, Box & Whisker, Waterfall, Funnel, Map), style (màu, legend, data labels, stacked).
- **PPTX — `<c:chart>` thật**: sinh `chartN.xml` (DrawingML Charts), workbook nhúng `Microsoft_Excel_SheetN.xlsx` (SpreadsheetML hợp lệ, dữ liệu đối xứng với cache) + rels + ContentTypes; slide chứa graphicFrame `r:id` → chart; chart trùng nội dung chỉ nhúng 1 part (dedupe theo JSON). Dữ liệu mở được trong PowerPoint chart editor. Lưu ý trung thực: các loại nâng cao (treemap/sunburst/histogram/box/waterfall/funnel/map) xuất PPTX dưới dạng biểu đồ gốc gần nhất (column/bar/pie) giữ nguyên dữ liệu — render đúng loại ở PDF/HTML; c16 extLst chờ bước sau.
- **PDF — painter riêng** (`CustomPaint` + PdfGraphics): column/bar/line/area/pie/donut/combo/waterfall/funnel vẽ bằng cùng bảng màu, title + legend bằng widget.
- **HTML — SVG tự sinh**: `ChartService.renderSvg` inline cho cả 14 loại (không phụ thuộc thư viện ngoài); placeholder giữ lại `data-chart` để chỉnh sửa.
- **UI**: nút **Chèn biểu đồ** trên thanh công cụ editor → dialog chọn loại/tiêu đề/nhãn/chuỗi giá trị/options + preview vẽ trực tiếp; danh sách "Biểu đồ trong slide" cho phép **chỉnh sửa chart đã chèn** (`replaceChartAt`) — cả 3 định dạng cập nhật tự động vì cùng đọc `data-chart`.

### 🔬 Kiểm chứng PowerPoint thật (P8)
- Deck sinh bởi đúng code path (văn bản + chart, và kết hợp cả SmartArt) mở **OK** trong PowerPoint COM (`OK slides=1`, không 0x80070570).
- 3 lỗi package từng làm PowerPoint từ chối deck chart (đã sửa): (1) `[Content_Types].xml` phải đặt mọi `<Default>` trước `<Override>`; (2) thẻ đóng frame phải là `</p:nvGraphicFramePr>` (trước đây viết nhầm `</p:nvSpPr>` — XML mất cân bằng); (3) `chartN.xml` căn chỉnh theo template chart thật của Excel COM (không có `<c:tx>` series-name, axes có tick marks/autoZero, `invertIfNegative`, `gapWidth` 150, axIds 261087776/1675213520) — deck này sau đó mở thẳng không cần Repair.
- Giới hạn trung thực: các loại nâng cao vẫn xuất dạng gần nhất (column/bar/pie) và `c16 extLst` chưa có; chưa kiểm chứng thao tác "Chỉnh dữ liệu trong Excel" bằng UI thật — chỉ xác nhận workbook nhúng hợp lệ cấu trúc và deck mở được.

### 🧪 Kiểm thử
- `test/chart_pipeline_test.dart` (11 test): model round-trip + detect blocks, PPTX package (chart1.xml well-formed, barChart/axId/legend, refs Sheet1!, srgbClr, numCache; xlsx ZIP hợp lệ chứa dữ liệu; rels→workbook; ContentTypes chart+xlsx; slide graphicFrame+rels; dedupe 1 part/2 shape), SVG 14 loại well-formed + primitive từng loại, HTML deck có SVG inline, PDF xuất slide có chart, insert/edit helpers (markup round-trip, replaceChartAt, out-of-range).

### 🈺 Quốc tế hóa
- 29 chuỗi mới vào .arb EN/VI: tên 14 loại biểu đồ + dialog (insert/edit/title/categories/series/legend/labels/stacked/preview/existing/inserted/updated…).

---

## [2.0.0-beta] - 2026-08-11 — Dev (2.0.0-beta M1) — Track 07: HTML deck tối ưu

### ⚡ Tối ưu (đo trước/sau trên deck chuẩn 10 slide / 10 ảnh)
- **CSS hiệu ứng theo nhu cầu** (`EffectPreviewService.generateEffectsCss`): chỉ sinh CSS cho hiệu ứng deck thực dùng, 1 class ngắn/hiệu ứng, keyframes trùng nhau phát 1 lần (các class khác alias) — phần CSS **9 757 B → 4 304 B (−55,9%)**.
- **Ảnh lazy load**: base64 chuyển vào bản đồ `ghitaImages` trong JS + `<img data-src="iN" loading="lazy" decoding="async">`; player nạp `src` đúng lúc slide trở thành active, nguồn trùng chỉ giữ 1 entry (browser test: ảnh slide 2 được inject với lazy/async khi tới slide).
- **Minify toàn tài liệu**: bộ minify string-aware (giữ nguyên chuỗi JS/attribute/data-URI, bỏ comment + khoảng trắng) — **tổng deck 25 394 B → 20 114 B (−20,8%)**, file xuất không còn dòng mới/comment.
- **Cache deck** (giữ từ Track 01 P6): trình chiếu lần 2 không rebuild (test cache hits/misses).
- **Player bản địa hoá**: chuỗi điều khiển (Trước/Sau/Toàn màn hình/ghi chú/tự chạy) theo `playerLocale` từ locale ứng dụng qua `ExportOptions.htmlPlayerLocale`.

### 🧪 Kiểm thử
- `test/html_deck_optimization_test.dart` (8 test): CSS subset+dedupe, lazy map 1/2 entry, minify không newline/comment + parse OK, đủ handler phím/auto/notes/progress, locale en/vi, deck 33 hiệu ứng đủ class + parse, cache deck.
- **Chạy player thật trên Chrome** (file://): Home/Space/ArrowRight/ArrowLeft/PageDown/PageUp/End/f đều điều hướng đúng; progress bar 33/66/100%; auto-advance 2s tự chuyển slide; ảnh lazy được inject.

### 🈺 Quốc tế hóa
- Chuỗi player trong HTML deck bản địa hoá EN/VI theo locale xuất (không cần .arb mới — chuỗi nằm trong file HTML độc lập).

---

## [2.0.0-beta] - 2026-08-11 — Dev (2.0.0-beta M1) — Track 06: PDF export nâng cao

### ✨ Tính năng mới
- **Khổ giấy**: A4 / Letter (ngang) / Khớp slide — mặc định `matchSlide` giữ nguyên hành vi v1.6.3 (1 trang = đúng kích thước slide); chọn trong hộp thoại Xuất nâng cao khi format PDF.
- **Lề trang + Scale-to-Fit**: 3 mức lề (Nhỏ 24pt / Tiêu chuẩn 48pt / Rộng 72pt) + "Vừa khít trang" — slide được thu theo tỉ lệ min((page−2m)/slideW, …), không phóng to để tránh vỡ chữ; trên khổ khớp slide giữ nguyên padding gốc 48/36.
- **Nhúng font con (subset)**: font hệ thống nhúng theo glyph thực dùng (cơ chế subset của `package:pdf` 3.13) — file nhỏ hơn nhiều so với font đầy đủ và chữ tiếng Việt vẫn đúng trên máy không có Segoe UI (test: PDF < kích thước segoeui.ttf).
- **Nén ảnh theo ExportQuality**: ảnh ≥512px trong PDF chuyển JPEG quality 60/75/85 theo mức 150/300/600 — PDF quality thấp nhỏ hơn rõ rệt.
- **Slide ẩn**: thêm cờ `hidden` vào model Slide; PDF bỏ slide ẩn mặc định, bật "In cả slide ẩn" để giữ (phạm vi slide kế thừa sẵn `allSlides`/`selectedSlideIndices`).
- **Metadata**: title (từ slide đầu), author/creator "Ghita PPT Converter", creation date vào Info dict.

### 🧪 Kiểm thử
- `test/pdf_export_advanced_test.dart` (7 test): MediaBox default 960×540 (y hệt v1.6.3), A4 842×595 / Letter 792×612, subset font + chữ VN (PDF < font đầy đủ), quality thấp < quality cao + DCTDecode ở 600px, hidden 2/3 trang theo cờ, metadata (title/author/creation) — đọc qua inflate object streams, `Slide.hidden` round-trip.

### 🈺 Quốc tế hóa
- 10 chuỗi mới vào .arb EN/VI: khổ giấy (3), lề (3), `pdfScaleToFit`, `includeHiddenSlides`, `pdfPaperSize`, `pdfMargins`.

---

## [2.0.0-beta] - 2026-08-11 — Dev (2.0.0-beta M1) — Track 05: Master & SlideLayout đa dạng

### ✨ Tính năng mới
- **9 `<p:sldLayout>` thật trong file PPTX** (trước chỉ có 1 blank): Title Slide, Title + Content, Section Header, Two Content, Comparison, Title Only, Content + Caption, Picture + Caption — mỗi layout có placeholder chuẩn OOXML (`ctrTitle`/`title`/`subTitle`/`body` idx 1–2/`pic`) với EMU geometry theo registry (`lib/services/ppt_layout_registry.dart`), `preserve="1"` và `clrMapOvr → masterClrMapping`.
- **Gallery đầy đủ**: 1 `slideMaster1.xml` duy nhất (chuẩn PPT cho phép) giờ khai báo cả 9 layout trong `sldLayoutIdLst` (id 2147483649–57) + rels + ContentTypes đủ 9 Override — PowerPoint hiển thị đúng bộ layout trong Slide Layout gallery.
- **Slide gắn đúng layout**: mỗi slide xuất ra trỏ tới layout theo `layoutType`; giá trị lạ/`standard`/thiếu → rơi về Blank (hành vi v1.6.3).
- **Đồng bộ 2 chiều**: nút **Layout** mới trên thanh công cụ editor mở picker (có tên bản địa hoá) → `PresentationState.setSlideLayout()` ghi lại vào `Slide.layoutType` → lưu/tải project và xuất đều giữ lựa chọn.

### 🧪 Kiểm thử
- `test/ppt_layout_test.dart` (7 test): 9 layout + 9 rels + ContentTypes hợp lệ, placeholder đúng từng layout (title/body idx/pic, blank không ph), master liệt kê đủ 9 + rels theme rId10, gắn layout theo slide + fallback blank, deck legacy không layoutType giữ nguyên cấu trúc v1.6.3 + toàn bộ XML well-formed, `layoutTypeOf`/`layoutPartNumber`, round-trip `Slide.layoutType` qua save/load.

### 🈺 Quốc tế hóa
- 10 chuỗi mới vào .arb EN/VI: `layout` ("Bố cục"), tên 9 layout (`layoutBlank`…`layoutPictureAndCaption`), `layoutApplied` ("Đã áp dụng bố cục: {name}").

---

## [2.0.0-beta] - 2026-08-11 — Dev (2.0.0-beta M1) — Track 04: Theme & Font của file PPTX theo người dùng

### ✨ Tính năng mới
- **Theme của người dùng đi vào file PPTX**: `PptThemeSetting` (`lib/models/ppt_theme_setting.dart`) ánh xạ màu primary → `accent1`, accent → `accent2` của `a:clrScheme`, font đã chọn → `a:minorFont` của `a:fontScheme` (majorFont giữ "Calibri Light"); deck xuất qua hộp thoại Xuất nâng cao giờ mang đúng màu/font người dùng chọn trong màn Theme.
- **Fallback an toàn**: font lạ được giữ nguyên tên (PowerPoint tự thay thế — đúng cơ chế mong muốn) nhưng được lọc control-char + XML-escape + giới hạn 64 ký tự; hex không hợp lệ rơi về màu Office — không bao giờ sinh `srgbClr` hỏng → không có hộp thoại "Sửa chữa file".
- **Preview "File xuất sẽ dùng theme này"** trong màn Theme Settings: dải 8 ô màu (accent1–6, hlink, folHlink) + majorFont/minorFont theo đúng ánh xạ xuất file.

### 🔒 Giữ nguyên hành vi cũ
- Không truyền theme (hoặc preset Office Blue chưa chỉnh) → theme part **byte-identical với v1.6.3** (test regression đối chiếu literal cũ); theme mới chỉ áp dụng khi người dùng thực sự tùy chỉnh.
- Slide layout blank không chứa palette cứng — màu/font chảy qua `clrMap` của slide master + theme part (P6).

### 🧪 Kiểm thử
- `test/ppt_theme_test.dart` (7 test): default byte-identical v1.6.3, theme custom có trong cả `theme1.xml`/`theme2.xml` (kèm notes master) + XML hợp lệ, dữ liệu thù địch bị chặn (hex lỗi → fallback, font chứa `<>&"` → XML-escaped), theme xuyên worker isolate và `ExportJobOptions`, layout không hardcode màu + master có clrMap, model round-trip.

### 🈺 Quốc tế hóa
- Chuỗi `exportThemePreview` ("File xuất sẽ dùng theme này" / "Exported files will use this theme") vào .arb EN/VI.

---

## [2.0.0-beta] - 2026-08-11 — Dev (2.0.0-beta M1) — Track 03: Ảnh pipeline — dedupe, nén lại, nhúng ảnh remote

### ✨ Tính năng mới
- **Nhúng ảnh remote (http/https)**: `HtmlImageLoader` giờ tải ảnh web trước khi xuất (`prefetchSlides` chạy trong `ExportJob` + worker isolate, giới hạn 4 luồng song song) với timeout 10s, giới hạn 10 MB, chỉ nhận `image/*` (chặn nội dung khác dù URL có đuôi .png); ảnh lỗi bị bỏ qua chứ không làm hỏng export.
- **Cache 2 tầng cho ảnh remote**: bộ nhớ (LRU 64) + cache đĩa dưới `%LOCALAPPDATA%\GhitaPPT\image_cache` (mã hoá nội dung), tái sử dụng giữa nhiều lần xuất và nhiều phiên.

### ⚡ Tối ưu
- **Dedupe theo SHA-256 nội dung**: 1 ảnh dùng ở nhiều slide chỉ nhúng 1 lần trong `ppt/media/`, mọi slide vẫn khai báo rels riêng. Deck 10 slide cùng 1 ảnh 600×400: **185 798 B → 31 951 B (giảm 82,8%)** — vượt ngưỡng ≥50% của phase 8.
- **PNG→JPEG chủ động**: ảnh PNG đục > 512 px chuyển sang JPEG (quality 70/80/90 theo ExportQuality 150/300/600) khi xuất PPTX; ảnh có kênh alpha và GIF giữ nguyên lossless; HTML/PDF giữ PNG.
- **Xoay EXIF trước khi nhúng**: `package:image` không đọc EXIF (JPEG decoder tự bake, parser eXIf PNG bị tắt) nên loader tự đọc tag 0x0112 (APP1 JPEG + eXIf PNG, TIFF II/MM) và áp dụng biến đổi 2–8 cho PNG/GIF; JPEG do decoder xử lý sẵn.

### 🛡️ An toàn
- Ảnh lỗi/dirty (không giải mã được, quá 10 MB, HTTP lỗi, không phải ảnh) bị loại khỏi deck và ghi vào `<file xuất>.warnings.log` cạnh file kết quả.

### 🧪 Kiểm thử
- `test/html_image_pipeline_test.dart` (8 test): dedupe 1 media/10 slide + giảm ≥50%, tải remote qua HttpServer local + cache đĩa tái dùng sau `clearCaches`, chặn nội dung không phải ảnh, chặn >10 MB, PNG→JPEG (có/không alpha), EXIF orientation 6 (16×32 sau bake), warnings.log chỉ xuất hiện khi có ảnh lỗi.

### 🈺 Quốc tế hóa
- Thêm chuỗi `loadingRemoteImages` ("Đang tải ảnh từ web…") và `remoteImageLoadFailed` ("Không tải được ảnh {name}") vào .arb EN/VI.

---

## [2.0.0-beta] - 2026-08-11 — Dev (2.0.0-beta M1) — Track 02: Bố cục theo font metrics thật

### ⚡ Tối ưu
- **TextMetricsService** (`lib/services/text_metrics_service.dart`): bảng metrics thật của Calibri / Segoe UI / Arial — parse trực tiếp bảng `hhea`/`OS/2` từ font hệ thống Windows (ascender, descender, lineGap, xAvgCharWidth, capHeight), có bảng fallback sẵn cho máy không có font.
- **Thay hằng số ước lượng** trong `estimatedHeight` (PPTX): bỏ 360.000 EMU/dòng và 400.000 EMU/hàng — text/list giờ đếm dòng gói theo độ rộng thật của run (phân lớp glyph: chữ thường / dấu cách 0.30em / dấu câu 0.35em) × chiều cao dòng true (typo line height), bảng tính theo từng ô + padding viền mặc định 0.05".
- **Autofit "vừa khít"**: khi nội dung tràn slide, co chữ đệ quy 90%/lần (sàn 60%) như PowerPoint "Shrink text on overflow" — cờ `fitContent` trong hộp thoại Xuất nâng cao (mặc định bật), nối qua `ExportOptions` → isolate → `PPTGenerator.generatePPT`.
- Sai số ước lượng chiều cao so với layout font thật (dart:ui TextPainter + Segoe UI): trung bình **47.5% → 10.3%**; tệ nhất **136.2% → 99.5%** (mẫu nằm đúng biên giới gói dòng có thể chênh ±1 dòng). Bảng chi tiết: `tool/benchmark_results_t02.md`.

### 🧪 Kiểm thử
- `test/text_metrics_test.dart` (6 test): bảng metrics hợp lệ, ước lượng wrap theo cỡ chữ, bảng theo ô dài nhất + insets, `estimateBlockHeight` thay hằng số cũ, autofit co chữ trong XML thật (giữ sàn 60%), path không-fit giữ nguyên cỡ chữ.
- Benchmark sai số: `tool/metrics_benchmark_test.dart` (10 slide mẫu: chữ dài, tiếng Việt có dấu, đậm/nghiêng, bảng 5x4, cỡ chữ lớn/nhỏ).

### 🈺 Quốc tế hóa
- Thêm chuỗi `fitContent` ("Vừa khít với slide") + `fitContentDescription` vào .arb EN/VI.

---

## [2.0.0-beta] - 2026-08-11 — Dev (2.0.0-beta M1) — Track 01: Nền tảng Export Pipeline

### ⚡ Tối ưu
- **ExportJob chuẩn hóa** (`lib/services/export_job.dart` + `export_primitives.dart`): một input (slides + options), một progress callback báo % theo từng slide (0–100, đơn điệu) và một cancel token dùng chung cho cả 3 định dạng PPTX/PDF/HTML; hủy giữa chừng không để lại file dở dang.
- **Cache parser chia sẻ** (`HtmlParseCache` trong `ppt_generator.dart`): HTML của slide được tokenize đúng 1 lần mỗi nội dung, cây block dùng chung cho PPTX lẫn PDF; notes, subtitle và biến thể bỏ h2 đầu lấy từ cùng một lần parse. Benchmark deck 20 slide: parse 58.1 ms → 2.1 ms (lần 1) → 0.0 ms (lần 2 cùng phiên).
- **Nén ZIP theo loại entry**: text/XML dùng deflate mức cao nhất (9), media đã nén (JPEG/PNG) lưu dạng stored — tổng xuất PPTX 106 ms → 36.6 ms → 20.1 ms (lần 2), dung lượng 40 878 B → 38 956 B (−4,7%). Giữ nguyên fix UTF-8 byte-length.
- **Progress qua isolate**: worker báo tiến trình % kèm slide đang xử lý theo job; `export_isolate.dart` chuyển tiếp về UI, hỗ trợ hủy (jobId + cancel message, worker bị dừng và sinh lại khi cần).
- **Cache deck HTML trong phiên** (`HtmlExportService`): xuất lại deck trùng nội dung không rebuild — key bằng FNV-1a 64 trên dữ liệu đầu vào kèm kiểm tra toàn vẹn chuỗi.

### 🧪 Kiểm thử
- Widget/unit test mới: progress tăng đơn điệu + đủ mọi slide, cancel giữa chừng (không để lại file), parse-once của cache, entry media stored / text deflate trong ZIP, cache deck HTML, progress & cancel xuyên worker isolate.
- Toàn bộ `flutter test` xanh (120 tests) — regression PPTX/PDF/HTML deck cũ vẫn mở được, nội dung không lệch.

### 🈺 Quốc tế hóa
- Thêm chuỗi `exportProgress` ("Đang xuất… x/y") và `exportCancel` ("Hủy xuất") vào .arb EN/VI.

### 📊 Benchmark
- Bảng đo trước/sau: `tool/benchmark_results_t01.md` (deck chuẩn 20 slide, 4 nội dung duy nhất, có ảnh PNG).

---

## [1.6.3+2] - 2026-08-08 — Bản vá nhỏ: ổn định trình chiếu, tối ưu RAM và UI

### 🐛 Đã sửa
- **Trình chiếu không chạy**: bỏ catch-all lỗi trong `PresentScreen`, hiển thị thông báo lỗi thực tế và thêm timeout 30s cho WebView2 để tránh treo.
- **Lỗi khởi tạo WebView**: bổ sung fallback thông báo rõ ràng khi WebView2 không khả dụng.

### ⚡ Tối ưu
- **RAM**: tái sử dụng `HtmlExportService` trong `buildHtmlDeck()` và giới hạn ảnh nhúng tối đa 1200px, giảm áp lực bộ nhớ khi trình chiếu.
- **Giao diện**: tách các widget nút lặp lại (`OfficeSidebarItem`, `OfficeSidebarButton`, `OfficeHeaderButton`) ra file riêng, thêm `RepaintBoundary` cho sidebar.

### 🚀 Tiện ích
- Thêm nút **"From Current"** (Present From Current) vào thanh công cụ trình soạn thảo.
- Bổ sung chuỗi dịch `presentFromCurrent` cho EN/VI.

### 📦 Dependencies
- **Version**: `1.5.3+2`

---

## [1.6.0+1] - 2026-08-05 — Bản phát hành nội bộ: bản địa hoá

### Đã thay đổi

- Kích hoạt bản địa hoá EN/VI trong ứng dụng và chuyển các luồng làm việc chính sang chuỗi dịch.
- Đồng bộ nhãn phiên bản trong ứng dụng, tài liệu, dữ liệu dự án, bản nháp và bộ cài.
- Bổ sung kiểm thử widget cho việc chuyển ngôn ngữ và hộp thoại Xuất nâng cao.
- Hoàn thiện cộng tác nội bộ có token phiên/người dùng, giới hạn payload, snapshot slide thật, revision conflict và đồng bộ hai chiều.
- Đưa bảng Cộng tác vào thanh công cụ trình biên tập và bổ sung giao diện EN/VI cho toàn bộ luồng kết nối.
- Bổ sung kiểm thử semantics cho khả năng truy cập và luồng integration test thực trên Windows.
- Bổ sung quy trình tạo installer per-user có kiểm tra metadata, SHA-256, truy vết revision nguồn, ký Authenticode tùy chọn và smoke test cài/gỡ.

## [1.5.0] - 2026-08-04 — Nâng cấp toàn diện (Features + UI/UX)

### ✨ Tính năng mới

#### 🎨 Theme Customization System
- **Theme provider**: Quản lý primary color, accent color, font family, theme mode
- **Theme customization UI**: Color picker cho primary/accent/background, font selector
- **4 preset themes**: Office Blue, Dark Professional, Light Minimal, Custom
- **Import/export theme**: JSON format để chia sẻ theme
- **Dynamic theme application**: Hot reload khi thay đổi theme

#### ⌨️ Customizable Keyboard Shortcuts
- **50+ keyboard shortcuts**: Tất cả actions đều có shortcut (Ctrl+N, Ctrl+S, Ctrl+E, etc.)
- **Shortcuts provider**: Load/save từ SharedPreferences, reset to defaults
- **Shortcuts customization UI**: Click để edit shortcut, conflict detection
- **Import/export shortcuts**: JSON format

#### 📤 Advanced Export Options
- **Export selected slides**: Checkbox list được áp dụng thực sự cho PPTX, PDF và HTML.
- **Tỷ lệ đầu ra**: 16:9, 4:3, 1:1 và 9:16 được ghi vào kích thước tệp/khung trình bày tương ứng.
- **Chất lượng ảnh**: Mức Thấp / Trung bình / Cao giới hạn cạnh dài ảnh lần lượt 150 / 300 / 600 px trước khi nhúng vào mọi định dạng.
- **Ghi chú và nền**: Hai tùy chọn bật/tắt tác động thực tế; PPTX bỏ toàn bộ quan hệ notes khi tắt, HTML và PDF chỉ đưa ghi chú vào đầu ra khi được chọn.
- **Một luồng xuất duy nhất**: Nút Export trong Editor và Ctrl+Shift+E cùng mở hộp Advanced Export, tránh lệch hành vi giữa hai luồng.

#### 🎭 Slide Master/Template System
- **Slide master model**: HTML template với placeholders ({{title}}, {{content}})
- **Slide master provider**: CRUD operations, persistence, built-in masters
- **Slide master UI**: List, create/edit master, apply to new slide

### ♿ Accessibility & UX Improvements

#### 🌍 Localization (i18n)
- **Song ngữ**: English + Vietnamese
- **288 strings extracted**: Tất cả hardcoded strings đã được chuyển sang .arb files
- **Language switcher**: Trong Settings screen

#### 🏷️ Accessibility
- **100% tooltips**: Tất cả interactive elements đều có tooltip
- **Semantics widgets**: Screen reader support
- **Focus management**: Tab navigation, visual focus indicators
- **Keyboard navigation**: Full keyboard support

#### 🎯 Error Handling
- **ErrorMapper utility**: Map technical errors → user-friendly messages
- **Categorized errors**: Network, auth, rate limit, timeout, file operations
- **Loading indicators**: Thêm cho tất cả async operations
- **Empty states**: UI đẹp khi không có data

#### 📱 Responsive Design
- **Breakpoints**: mobile (<600px), tablet (600-900px), desktop (>900px)
- **Auto-hide sidebar**: Khi width < 900px
- **Compact ribbon**: Khi width < 1200px
- **Theme-based colors**: Thay thế 82 hardcoded `Color(0x...)` values
- **Scalable fonts**: Thay thế 30+ hardcoded `fontSize` values

### 🐛 Bug Fixes
- **17 runtime bugs fixed**: Transparent color crash, API key masking, FocusNode leak, etc.
- **Layout optimization**: Ribbon 90px → 60px, sidebar 200px → 150px
- **Editor space**: Tăng không gian cho HTML editor + Preview (3:2 ratio)
- **0 analyzer warnings**: Tất cả warnings đã được fix

#### 🧱 PPTX Core Hardening
- Sửa đường dẫn chuẩn `ppt/slideMasters/`, tên phần tử `a:prstGeom` và thứ tự `p:cSld`/`p:transition` theo PresentationML.
- Sửa auto-advance thành thuộc tính `advTm`; ánh xạ mọi hiệu ứng sang transition ISO hợp lệ.
- Notes Master chỉ được tạo khi có ghi chú, dùng theme riêng và placeholder/style tương thích PowerPoint.
- Giữ các inline run đậm/nghiêng/liên kết trong cùng đoạn hoặc list item; `a:br` được xuất đúng schema và khoảng trắng giữa run được bảo toàn.
- Phân bổ chiều cao khối văn bản, danh sách, bảng và ảnh theo không gian slide để các khối liên tiếp không chồng lấn.
- Loại bỏ placeholder thừa và khai báo `a:buNone` cho phụ đề/đoạn văn thường để PowerPoint không tự chèn dấu đầu dòng.
- Xuất đúng `Slide.bgColor`, loại màu không hợp lệ, không lặp lại `<h2>` subtitle trong phần nội dung.
- Từ chối deck rỗng thay vì tạo gói PPTX không sử dụng được.

### 📦 Dependencies
- **Version**: `1.5.0+1`
- **New**: `intl` (localization support)
- **All existing**: 24 packages từ v1.2.0

### 📝 Documentation
- **README.md**: Updated với v1.5.0 features
- **Keyboard shortcuts reference**: PDF cheat sheet
- **Screenshots**: New features và UI improvements

---

## [1.2.0] - 2026-08-03 — Bản nâng cấp lớn (UI + Features)

### 🎨 Giao diện & Điều hướng
- **Sidebar navigation**: Thay thế BottomNavigationBar bằng NavigationRail hiện đại, có thể collapse/expand.
- **Redesign HomeScreen**: Layout mới với sidebar, quick access toolbar, và grid overlay toggle.
- **Material 3 Theme**: Cập nhật theme system, tối ưu cho desktop.

### 🛠️ Ribbon Toolbar — Kích hoạt toàn bộ
- **Home tab**: Clipboard (Cut/Copy/Paste), Font formatting (Bold/Italic/Underline/Strikethrough), Text color, Highlight, Alignment, Bullet/Numbered lists, Shapes.
- **Insert tab**: New Slide, Pictures (file picker → base64), Table dialog (rows/cols), Chart dialog (CSS bar chart), SmartArt (Mermaid flowchart/mindmap), Text Box, WordArt (gradient/shadow/outline), Header, Symbol picker (48 ký tự), Code block.
- **Design tab**: 8 theme gradients, 4 color variants, Background color picker, Gradient builder.
- **Transitions tab**: 14 effect buttons, Apply to All, Timing (On Click / Auto / Duration).
- **Slideshow tab**: From Beginning, From Current, Presenter View, Rehearse, Timings.
- **View tab**: Normal, Slide Sorter, Reading View, Grid toggle, Ruler, Zoom, Fullscreen.

### 📋 Properties Panel — Kích hoạt toàn bộ
- **Slide Properties**: Background color picker (interactive), Transition dropdown, Layout dropdown.
- **Text Properties**: Font family (7 fonts), Size (8-72px), Color picker, Alignment (left/center/right), Bold/Italic toggles.
- **Shape Properties**: Fill color, Border color, Border width, Shadow toggle, Transparency slider.

### 📁 Template Studio Screen
- Dynamic grid từ TemplateService (20 templates, 6 categories).
- Category filter chips, Search bar, Preview dialog, Apply button.

### 📂 Recent Projects Screen
- FilePicker cho .ghita files, Project metadata, Recent projects history (SharedPreferences).

### ⚙️ Settings Screen
- **Backup/Restore**: Export/Import toàn bộ settings + API keys → JSON file.
- **Configuration Wizard**: 4-step wizard (provider type, API keys, model selection, summary) — fix tất cả bugs (API key masking, validation bypass, `_steps` getter recreation, `ColorUtils` extension).
- Provider health status indicators.

### 🤖 AI Provider Manager — Hợp nhất
- **Merge `AIProviderManager` + `EnhancedAIProviderManager`**: Giữ base, thêm multi-key, health monitoring, key rotation, local AI scanning.
- Xóa `enhanced_ai_provider_manager.dart` và `enhanced_ai_provider_config.dart`.
- Fix: shared HTTP client, Anthropic SSE event handling, customPrompt passthrough, Gemini API key support.
- `ProviderHealthStatus` enum (unknown/healthy/degraded/failed).

### 🔧 Services mới
- **Image Editor Service** (`image_editor_service.dart`): pick/resize/rotate/flip/adjust → base64.
- **Audio Recording Service** (`audio_recording_service.dart`): record/pause/resume/stop per-slide narration (WAV).
- **Collaboration Service** (`collaboration_service.dart`): local network host/join, real-time sync via HTTP endpoints.

### 🎛️ Widgets mới
- **Image Editor Dialog**: Crop, resize, rotate, flip, brightness/contrast adjustment.
- **Audio Recorder Panel**: Floating recorder với timer, pause/resume/stop.
- **Collaboration Panel**: Host session (QR code + share URL), Join session (IP/port/name).
- **Mermaid Dialog**: Flowchart, Mindmap, Sequence diagram → HTML.
- **Import Dialog**: Markdown → slides, Web URL → slides (preview trước khi import).

### 🐛 Bug Fixes
- Fix `slide_preview.dart`: data-bg-color regex parsing, color conversion.
- Fix `api_key_rotation_service.dart`: Gemini API key support (query param vs Bearer).
- Fix `api_fallback_cascade_service.dart`: remove duplicate `PingResult` class.
- Fix `project_bundle_service.dart` version: `0.7.0` → `1.2.0`.
- Fix `smart_draft_manager.dart` version: `1.0.2` → `1.2.0`.

### 📦 Dependencies
- Bump version: `1.2.0+1`
- New: `file_picker`, `record` (^7.1.1), `audioplayers`, `shelf`, `shelf_router`, `network_info_plus`, `qr_flutter`, `highlight`, `flutter_highlight`, `url_launcher`, `window_manager`.
- Removed redundant asset entries (5 explicit .html files).

---

## [1.0.2] - 2026-08-02 — Bản vá nhỏ

### ⚡ Hiệu năng
- **Persistent isolate cho export**: `ExportIsolateService` mở một worker isolate dài hạn (spawn 1 lần, tái sử dụng cho mọi export). Bỏ chi phí mở isolate + nạp lại snapshot mỗi lần; **font Windows cho PDF chỉ tải 1 lần** (static cache của `PdfExportService` giờ thực sự có tác dụng). Các request được serialize, tự hồi phục worker nếu chết.

### 📊 Xuất timing vào PPTX
- **Thuộc tính `advTm="..."` trên `p:transition` của mỗi slide**: Khi bật auto-advance (Timing > Auto/Duration), file PPTX xuất ra tự chuyển slide theo thời lượng đã đặt — đồng nhất với trình chiếu trong app và HTML deck. Hoạt động ngay cả khi slide không có hiệu ứng chuyển tiếp.

### 🧹 Dọn dẹp
- **Xóa `html_to_ppt_screen.dart` (legacy ~1030 dòng)**: màn hình cũ đã bị `editor_shell.dart` thay thế và không còn được điều hướng tới; `ExportFormat` đã có sẵn bản sao trong editor. Code mới gọn hơn, không còn hai luồng export song song.

### 🔢 Version
- Bump lên `1.0.2+3`; đồng bộ README, CHANGELOG, draft marker.

---

## [1.0.1] - 2026-08-01 — Bản vá nhỏ

### 🎬 Trình chiếu (Slide Show)
- **Kích hoạt nút Trình chiếu**: Nút Present ở Quick Access Toolbar và Ribbon (From Beginning / From Current) nay mở trình chiếu thật (trước đây là no-op). Nút **Presenter View** nay mở màn hình Presenter View đã xây dựng sẵn nhưng chưa được kết nối.
- **"From Current"**: Trình chiếu bắt đầu từ slide đang chọn trong editor.
- **Trình chiếu tự động (Auto-play / Timing)**: Nhóm "Timing" trên Ribbon nay hoạt động — On Click / Auto / Duration (1–60 giây). Thiết lập được lưu giữa các phiên, nhúng vào HTML deck để chuyển slide tự động; có nút Auto ⏸/▶ để tạm dừng ngay trong lúc trình chiếu.
- **Nút "Thoát"**: Hiển thị nút thoát rõ ràng, có nhãn khi đang trình chiếu (ngoài phím Esc).

### ⚡ Hiệu năng
- **Export/parse chạy nền bằng isolate**: Export PPTX / PDF / HTML nay chạy trên background isolate qua `compute` — UI không còn bị đứng với deck lớn. Logic sinh nội dung không đổi, chỉ đổi chỗ gọi.

### 🧹 Khác
- Bump version lên `1.0.1+2`; đồng bộ README, CHANGELOG và draft marker.

---

## [1.0.0] - 2026-08-01 — PowerPoint-Style Interface (BẢN CẬP NHẬT LỚN NHẤT)

### 🎨 Giao Diện PowerPoint Microsoft 100%
- **Ribbon Toolbar (`RibbonToolbar`)**: Thanh công cụ dạng tab 6 mục: Trang chủ, Chèn, Thiết kế, Chuyển động, Trình chiếu, Xem — giống Microsoft PowerPoint
- **Quick Access Toolbar**: Thanh truy cập nhanh Undo/Redo/Save/Present ở góc trên trái
- **Status Bar**: Thanh trạng thái dưới cùng với slide counter, zoom slider, view mode toggles
- **3-Panel Layout**: Panel trái (thumbnails), Panel giữa (editor + preview), tương tự PowerPoint
- **Editor Shell (`EditorShell`)**: Layout chính mới thay thế HtmlToPPTScreen cũ

### 📋 Slide Thumbnail Panel
- **Slide Thumbnails Panel (`SlideListPanel`)**: Panel trái với thumbnail miniature cho mỗi slide
- **Drag-and-drop reorder**: Kéo thả để sắp xếp lại slide
- **Context menu**: Right-click để edit, duplicate, preview, delete
- **Slide number badge + structure chips**: Hiển thị số thứ tự và cấu trúc HTML
- **Multi-select actions**: Duplicate, delete selected slides

### 🎛️ Properties Panel
- **Format Panel (`PropertiesPanel`)**: Panel phải cho định dạng element
- **Slide Properties**: Background color, transition effect, layout selector
- **Text Properties**: Font picker, size, color, alignment, bold/italic toggles
- **Shape Properties**: Fill, border, shadow, transparency controls

### 📐 Slide Layout System
- **9 Layout Types (`SlideLayout`)**: Blank, Title Slide, Title+Content, Section Header, Two Content, Comparison, Title Only, Content+Caption, Picture+Caption
- **Layout Picker (`LayoutPicker`)**: Grid picker với mini thumbnails cho mỗi layout
- **Auto HTML generation**: Mỗi layout tự generate HTML template

### 🎭 Hiệu Ứng Mở Rộng (14→30+)
- **16 effects mới** được thêm vào SlideEffect enum:
  - Entrance: Fly In (Left/Right/Top/Bottom), Appear, Basic Zoom, Swivel, Boomerang
  - Emphasis: Pulse, Grow/Shrink, Spin, Teeter, Flicker, Color Pulse
  - Exit: Fly Out (Left/Right), Disappear
  - Motion Path: Arc, Custom Path
- **EffectPreviewService**: Service mới generate CSS @keyframes cho tất cả effects
- **Effects organized by category**: Basic, Entrance, Emphasis, Exit, Motion Path
- **CSS transitions per-slide**: Mỗi slide có thể có transition effect riêng trong HTML export

### 🎨 Template Mở Rộng (5→20)
- **15 template mới** trong 6 categories:
  - Technology: Tech Dashboard, API Documentation
  - Education: Lesson Plan, Science Lab
  - Corporate: Quarterly Report, Team Meeting
  - Creative: Portfolio, Event Invitation
  - Data: Infographic, Comparison, Process Flow, Timeline
  - Special: Title Slide, Thank You, Agenda
- **Category system**: Templates được phân loại theo category
- **Template Studio upgrade**: Category tabs + live preview + Apply/Customize buttons

### 🖥️ Presenter View
- **Presenter View Screen (`PresenterViewScreen`)**: Split-screen presenter view
  - Current slide (70%) + Next slide preview (30%)
  - Speaker notes display (scrollable)
  - Elapsed time timer
  - Slide navigator
  - Keyboard navigation (Arrow keys, Space, Esc)

### 📊 Slide Sorter View
- **Slide Sorter Screen (`SlideSorterScreen`)**: Grid view tất cả slides
  - Zoom slider (50%-200%)
  - Multi-select (tap to select/deselect)
  - Bulk actions: Duplicate, Delete selected
  - Select All / Deselect All

### ✨ Visual Slide Editor
- **Draggable Element (`DraggableElement`)**: Widget kéo thả element trong slide
  - Supports text, shapes, images
  - Snap-to-grid (10px grid)
  - Resize handles (bottom-right corner)
  - Delete button, element type badge
  - Z-index layering support

### 🔧 Code Refactoring
- **Editor State (`EditorState`)**: Centralized state management cho editor
- **Slide List Panel (`SlideListPanel`)**: Extracted from monolithic editor
- **HTML Editor Panel (`HtmlEditorPanel`)**: Extracted from monolithic editor
- **New directory structure**: `lib/screens/editor/` cho editor components

### 🔌 HTML Export Nâng Cao
- **Per-slide CSS transitions**: Mỗi slide dùng CSS @keyframes animation riêng
- **30+ transition effects**: Tất cả effects đều hỗ trợ trong HTML export
- **Smooth slide switching**: JavaScript re-triggers animation khi chuyển slide

### 📊 PPT Generator Nâng Cao
- **30+ effects mapped to OOXML**: Tất cả effects mới đều có mapping trong PPTX export
- **Entrance effects → push/fly transitions**
- **Emphasis effects → fade transitions** (PPTX không có emphasis transitions)

### 📝 Template Service Nâng Cao
- **Category support**: `getTemplatesByCategory()` và `getCategories()`
- **20 templates**: Từ 5 lên 20 templates đa dạng

---

## [0.7.2] - 2026-07-31 — Bug Fixes & Performance

### 🐛 Critical Bug Fixes
- **removeSlide undo/redo fix**: `_recordHistory()` now records the post-state snapshot (after removal, matching `addSlide` semantics) — both Undo and Redo now work correctly after deleting a slide
- **clearSlides history fix**: History snapshot now recorded after clearing (post-state) so Undo restores cleared slides and Redo re-clears them
- **loadProjectFromFile cast fix**: Fixed `CastError` when loading `.ghita` bundles — now properly maps `List<dynamic>` to `List<Slide>`
- **Notes lang fix**: Removed hardcoded `lang="en-US"` from speaker notes runs — PowerPoint spell-check now uses the document default language
- **Wi-Fi Broadcaster port fallback**: Server now tries ports 8090-8099 automatically if the default port is occupied; interface listing moved out of the retry loop so a listing failure can't abandon a bound server
- **JSON extraction scan limit**: Added 100KB scan limit to `_extractJsonArrayStatic` to prevent O(n) stalls on very long AI responses

### ⚡ Performance Improvements
- **Debounced auto-save**: Slide mutations now debounce 400ms before writing to SharedPreferences — eliminates disk I/O spam during drag-reorder and rapid editing; pending save is flushed on dispose so the last edits are never lost
- **Single-pass HTML parse**: `_buildSlideXml` now reuses a single DOM parse for content blocks, h2 subtitle, and bg-color extraction — faster PPTX generation

### 🎨 UX Improvements
- **exportStatus auto-reset**: Export success/error indicators now auto-clear after 5 seconds — prevents stale UI state
- **Dialog controller leaks fixed**: System Prompt and Provider Settings dialogs now dispose controllers on ALL close paths (Cancel, Save, AND barrier dismiss) instead of leaking on barrier tap
- **Outline editor dispose hardened**: Controllers disposed only after the exit animation finishes (400ms delay) — avoids potential "used after disposed" crashes during fade-out
- **ClearSlides undo snackbar**: "Clear All Slides" now shows SnackBar with "Hoàn tác" (Undo) action — consistent with removeSlide behavior
- **Chat history persistence**: AI chat messages now saved to SharedPreferences and restored on app restart; error and multi-slide messages included
- **mounted-safety**: `_addMessage` and streamed updates now guard on `mounted` before `setState` — no "setState after dispose" crashes

### 🧹 Cleanup
- **Removed unused dependency**: `material_color_utilities: ^0.13.0` removed from pubspec.yaml (never imported in code)
- **README version drift**: README.md updated to reflect v0.7.0+1 (was incorrectly showing v0.3.0+1)

## [0.7.0] - 2026-07-30 — Ultimate AI Studio & Presentation Platform (BƯỚC NHẢY VỌT LỊCH SỬ)

### 🛡️ Smart Auto-Save & PowerPoint-Style Storage Purge
- **Unsaved Draft Sandbox (`SmartDraftManager`)**: Background draft auto-saves every 3-5 seconds when working on unsaved projects. Zero data loss on unexpected shutdowns or power cuts.
- **Automatic Temp Draft Purging**: As soon as the presentation is saved to an official `.ghita` file path, temporary sandbox drafts are automatically purged to prevent disk clutter and conserve storage.
- **Multi-Asset `.ghita` Project Bundles (`ProjectBundleService`)**: Standardized ZIP container packing `manifest.json`, `slides.json`, `history.json`, and offline media assets (`media/`).
- **Time Machine History & Undo/Redo (`TimeMachineHistoryService`)**: History snapshot tree, diff comparison, and 1-click snapshot restore.

### ⚙️ Dedicated Settings Tab & AI Provider Super-Hub
- **Settings Screen (`SettingsScreen`)**: Centralized hub managing Light/Dark/System theme, API Key Vault, Editor Preferences, Keyboard Shortcuts Remap, and 1-Click Backup/Restore JSON.
- **Provider Connection Wizard (`ProviderSettingsScreen`)**: Diagnostic Ping Latency (ms), Auto-Fetch Available Models API (`GET /v1/models`), and Multi-Key Rotation.
- **Local AI Auto-Discovery (`LocalAIDetectorService`)**: 1-Click auto-discovery for running local AI endpoints (Ollama `:11434`, LM Studio `:1234`, vLLM `:8000`).

### 🎨 Visual & HTML Hybrid Studio
- **WYSIWYG Toolbar (`WysiwygToolbar`)**: Inline visual text formatting (Bold, Italic, Underline, Headers, Lists, Tables, Callout boxes, Code blocks) without typing raw HTML manually.
- **Per-Slide AI Assistant (`SlideAiToolsDialog`)**: Slide-level AI toolbar for Rewrite & Polish, Speaker Notes Script Generation, and 20+ Languages Translation.
- **Template Studio (`TemplateStudioScreen`)**: Thư viện Theme phong cách đa dạng (Business Executive, Modern Dark, Academic Gold, Creative Pitch, Minimal Slate).

### 🎙️ Diễn Giả & Local Broadcaster
- **Wi-Fi Live Presentation Broadcaster (`WifiBroadcasterService`)**: Broadcast live presentation slides over local Wi-Fi to audience mobile devices via HTTP server & QR Code.
- **Recent Projects Hub (`RecentProjectsScreen`)**: Grid/List project management with search and hashtag tagging.

### ⚡ Navigation & Shortcuts
- **Command Palette (`CommandPaletteDialog`)**: `Ctrl + K` quick action launcher modal.
- **Shortcuts Cheat Sheet (`ShortcutsHelpDialog`)**: `Ctrl + /` keyboard shortcuts reference.
- Modern 5-destination NavigationBar: Editor, Projects, Templates, AI Chat, Settings.

## [0.3.0] - 2026-07-30 — Siêu cập nhật (Mega Update)

### 🧱 Typed Slide Model
- New `Slide` model (`lib/models/slide.dart`): `title`, `htmlContent`, `notes`, per-slide `effect` override, `timestamp`
- `SlideEffect` enum moved to `lib/models/slide.dart` (re-exported from `presentation_state.dart` for compatibility)
- `PresentationState` now holds `List<Slide>`; legacy persisted slide maps still load correctly

### 🐛 Critical PPTX Bug Fixes
- Fixed duplicated `</a:txBody>` closing tag in table cells (produced invalid OOXML)
- Fixed bullet character written as literal `\u2022` escape instead of the real • glyph
- Fixed table `<p:xfrm>` closed with mismatched `</a:xfrm>` tag
- Fixed multi-slide JSON extraction truncating nested arrays (now uses balanced-bracket scanning)

### 📊 PPTX Engine — Major Upgrade
- **Images**: `<img>` with base64 data URIs or local file paths embedded as `ppt/media/*` with `<p:pic>` shapes, auto-scaled to fit
- **Rich text styling**: inline `color`, `background-color` (highlight), `font-size` (px/pt/em), `font-family`, `text-align`, plus `<u>` underline and `<s>/<del>` strikethrough
- **Speaker notes**: from the new notes field or `<aside class="notes">` → proper `notesSlide` parts + notes master
- **Hyperlinks**: `<a href>` → `<a:hlinkClick>` with external relationships
- **Per-slide transitions**: each slide can override the deck-wide effect
- **Office theme**: `ppt/theme/theme1.xml`, `docProps/core.xml`/`app.xml`, master/layout relationship chain — no more PowerPoint repair prompts
- Content shapes now flow vertically instead of overlapping; wider content area in 16:9

### 📄 PDF Export (new)
- `PdfExportService`: one landscape page per slide (16:9 or 4:3), sharing the exact HTML parsing with the PPTX engine
- Supports text styling, lists, tables, images, background colors with automatic contrast text
- **Unicode/Vietnamese text support**: embeds a Windows system font (Segoe UI → Arial → Tahoma fallback) instead of the built-in Helvetica, so diacritics render correctly
- Export dialog now offers PPTX / HTML / PDF

### 🤖 AI — Gemini, Ollama, Streaming, Outline
- **Google Gemini** provider (`gemini` format type, `x-goog-api-key`, `systemInstruction`)
- **Ollama (local)** template — API key not required for localhost endpoints
- **Streaming responses** (SSE) for OpenAI/Anthropic/Gemini with a Stop button
- **Outline mode**: AI drafts an editable outline (titles + bullets), then generates each slide with progress

### 🖥️ In-App Preview & Present Mode (new)
- Live slide preview beside the HTML editor (WebView2, 500 ms debounce)
- Per-slide preview dialog from the slide list
- **Present mode**: fullscreen in-app playback of the HTML deck (arrow keys, progress bar, Esc to exit)
- Graceful fallback when the WebView2 runtime is missing

### ✍️ Editor
- Speaker notes field and per-slide transition picker
- Fixed export dialog running the export twice

### 🧪 Testing & Quality
- 74 tests passing (up from 19): XML regression tests (incl. UTF-8 ZIP header sizes with Vietnamese content), image embedding, styling, notes, hyperlinks, per-slide transitions, package structure, PDF export incl. Vietnamese font embedding, SSE parsing, outline JSON, Slide model round-trips
- Deep review pass: fixed UTF-8 byte-length ZIP headers, network errors no longer swallowed as stream cancels, `<img>` inside `<p>` now exported, Stop button only shown when cancellable, outline dialog controller leaks fixed
- `flutter analyze`: 0 issues (cleaned all deprecations and icon tree-shake warnings)

### 🔧 Dependencies
- Added `webview_windows`, `image`; dev: `xml`
- Removed unused `dart_openai`, `webview_flutter`, `js`
- Version bump to `0.3.0+1`

## [0.1.5] - 2026-07-30 (previously undocumented)

### Added
- **Slide templates**: 5 bundled HTML templates (Business, Creative, Academic, Marketing, Minimal) with recommended transition effects, icons and accent colors (`TemplateService`, `SlideTemplate`, template gallery dialog)
- **HTML export**: standalone browser presentation with keyboard/touch navigation, progress bar, fullscreen and per-slide background colors (`HtmlExportService`)
- Tests: `html_export_test.dart`, `slide_template_test.dart`

## [0.0.5] - 2026-07-30 — Major Upgrade

### 🐛 Critical Bug Fixes
- **EffectsScreen completely rewritten**: Fixed all compile errors
  - `_availableAnimations` variable was undefined (used `_availableEffects` instead)
  - `_selectedEffect.name = newValue` was trying to mutate a Dart enum (now uses dedicated state)
  - Preview animation switch cases now use display strings correctly
- **PPTX transition XML**: Fixed OOXML compliance, added direction attributes (`dir`) for push transitions
- **ConfigService type safety**: Fixed `Map<dynamic, dynamic>` → `Map<String, dynamic>` cast

### 📊 PPTX Engine Upgrade
- **Widescreen 16:9 (default)**: Changed from 4:3 to 16:9 screen format (`screen16x9`, 12192000×6858000 EMUs). 4:3 still available as option.
- **Proper bullet lists**: Unordered lists use `a:buChar` (• bullet), ordered lists use `a:buAutoNum` (arabicPeriod numbering)
- **Table HTML support**: Parse `<table>`, `<thead>`, `<tbody>`, `<tr>`, `<th>`, `<td>` into PPTX `p:graphicFrame` with `a:tbl` grid
- **Structured block parsing**: New `parseHtmlContentFull()` returns typed blocks (text, list, table) for smarter PPTX output

### 📝 Slide Management
- **Drag-to-reorder slides**: `ReorderableListView` with drag handles
- **Edit existing slides**: Tap any slide → pre-fills HTML editor for editing
- **Duplicate slide**: One-click copy with "(Copy)" title suffix
- **Clear all slides**: Confirmation dialog with delete all
- **Undo delete**: Snackbar with undo action when deleting a slide
- **Empty state**: Illustrated prompt when no slides exist

### 🤖 AI Enhancements
- **Multi-slide generation**: Ask "Create 3 slides about X" → AI returns JSON array, all slides are generated at once
- **Add all slides button**: Add multiple AI-generated slides in one tap
- **Custom system prompt editor**: Edit the AI system prompt directly from the chat screen; reset to default option
- **System prompt persistence**: Custom prompts survive app restart via SharedPreferences
- **Anthropic API support**: Proper `system` parameter and `x-api-key` header for Claude models

### 🎨 UI/UX
- **Dark mode**: Toggle between Light / Dark / System theme via AppBar icon. Persisted across restarts.
- **AppBar theme toggle**: Cycle through light → dark → system → light
- **Modern NavigationBar**: Switched from `BottomNavigationBar` to Material 3 `NavigationBar`
- **Improved empty states**: Each screen has an illustrated empty state with guidance text
- **Export dialog**: Prompt user for file name before export with `.pptx` suffix
- **Export progress**: Loading indicator during PPTX generation

### ⌨️ Keyboard Shortcuts
- **Ctrl+Enter** — Add or update current slide
- **Ctrl+E** — Export presentation to PPTX
- Focus node auto-activates on the HTML to PPT screen

### 🎨 Slide Background & Subtitle
- **`data-bg-color` attribute**: Add `data-bg-color="#FF0000"` to any HTML element to set slide background color in PPTX output
- **Subtitle support**: `<h2>` elements are rendered as subtitle text boxes below the title in PPTX

### 🌡️ AI Parameters
- **Temperature setting**: Configure AI creativity (0.0–2.0) per provider
- **Max Tokens setting**: Control response length per provider
- Both settings persist in provider configuration

### 🖼️ Slide Thumbnails
- Each slide in the list now shows a mini chip-based preview (H1, H2, paragraph count, list items, tables)
- Visual tags help identify slide structure at a glance

### 🛡️ Error Boundary
- Global `FlutterError.onError` and `PlatformDispatcher.onError` handlers catch unhandled exceptions
- Errors are logged to debug console for easier troubleshooting

### 🧪 Testing
- **19 unit tests** (up from 12), all passing
- Added tests for: table blocks, ordered lists, structured blocks, 16:9, 4:3, list content, table content
- Fixed: test file had duplicate imports and duplicate `main()` definitions
- Added: `widget_test.dart` placeholder with valid `main()`

### 🔧 Dependency Updates
- `pubspec.yaml` version: `0.0.5+1`
- Updated all compatible dependencies (archive 3.6.1, flutter_secure_storage 9.2.4, etc.)

### 📦 Files Changed
- `lib/main.dart` — Multi-theme support (light/dark/system)
- `lib/screens/home_screen.dart` — Theme toggle, NavigationBar
- `lib/screens/effects_screen.dart` — Complete rewrite (fixed bugs)
- `lib/screens/html_to_ppt_screen.dart` — Reorder, edit, duplicate, clear, export dialog
- `lib/screens/ai_chat_screen.dart` — Multi-slide, system prompt editor
- `lib/providers/app_provider.dart` — Theme state management
- `lib/providers/presentation_state.dart` — moveSlide, updateSlide, duplicateSlide, exportToPPTPath
- `lib/providers/ai_provider_manager.dart` — Multi-slide generation, system prompt
- `lib/providers/config_service.dart` — System prompt persistence
- `lib/services/ppt_generator.dart` — 16:9, lists, tables, structured parsing, OOXML fixes
- `test/ppt_generator_test.dart` — Added table, list, block, format tests
- `test/widget_test.dart` — Valid placeholder
- `pubspec.yaml` — Version bump to 0.0.5+1

## [0.0.1] - 2026-07-30
### Added
- Slide transition effects (14 effects: fade, push, wipe, split, blinds, clock, zoom, etc.)
- Per-slide transition applied when exporting PPTX
- HTML formatting preservation in PPTX output (bold, italic, headings, lists, line breaks)
- API key encryption via `flutter_secure_storage`
- HTML input validation (empty check, size limit 100KB, script/iframe/object/embed removal)
- Real widget tests for `PPTGenerator` (parseHtmlContent + file generation)

### Changed
- Version bump: `0.1.0+1` → `0.0.1+1`
- API keys no longer stored in plaintext in `providers.json` or SharedPreferences
- Removed boilerplate counter test from `widget_test.dart` (kept as template)
- `PresentationState.currentTheme` renamed to semantic `slideEffect` (enum)
- `PPTGenerator` now uses `html/dom.dart` for proper DOM traversal

### Fixed
- EffectsScreen applied animation name as string theme (now stored as `SlideEffect` enum)
- `_buildSlideXml` stripped all HTML formatting → now preserves bold/italic/structure
- `ai_provider_manager.dart` — secure API key persistence per provider

## [0.1.0+1] - Previous version
Initial release (pre-security-fix).
