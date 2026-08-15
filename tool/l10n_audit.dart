/// l10n audit (Track 67, OPT 49).
library;

/// Usage: `dart run tool/l10n_audit.dart`
///
/// * Hard gate — EN and VI .arb files must have identical key sets
///   (exit 1 otherwise).
/// * Informational — scans `lib/` for hardcoded Vietnamese string literals
///   that should live in .arb. Files that are already locale-aware
///   (return `locale == 'vi' ? … : …`) are skipped, as are pure-identifier
///   strings. This is a heuristic scanner, not a linter.
import 'dart:io';

Future<void> main() async {
  var problems = 0;

  // 1. .arb key sync (hard gate).
  final en = await File('lib/l10n/app_en.arb').readAsString();
  final vi = await File('lib/l10n/app_vi.arb').readAsString();
  final enKeys = _keys(en);
  final viKeys = _keys(vi);
  final missingInVi = enKeys.difference(viKeys);
  final missingInEn = viKeys.difference(enKeys);
  if (missingInVi.isNotEmpty) {
    problems++;
    stdout.writeln('MISSING in app_vi.arb: ${missingInVi.toList()..sort()}');
  }
  if (missingInEn.isNotEmpty) {
    problems++;
    stdout.writeln('MISSING in app_en.arb: ${missingInEn.toList()..sort()}');
  }
  if (missingInEn.isEmpty && missingInVi.isEmpty) {
    stdout.writeln('OK: ${enKeys.length} keys in sync EN=VI');
  }

  // 2. Hardcoded Vietnamese scan (informational).
  final viRe = RegExp("['\"]([^'\"\\\\n]{6,})['\"]");
  final vietnameseTokens = <String>{
    'không', 'được', 'trong', 'trên', 'tại', 'trình', 'chiếu',
    'thuyết', 'tạo', 'mới', 'lưu', 'xóa', 'sửa', 'thêm', 'chèn',
    'chọn', 'tìm', 'kiếm', 'thay', 'thế', 'tiếng', 'việt',
    'nhập', 'xuất', 'mở', 'đóng', 'bật', 'tắt', 'đang', 'chờ',
    'làm', 'xong', 'áp', 'dụng', 'hủy', 'đồng', 'bộ', 'chỉnh', 'đổi',
    'giao', 'diện', 'ngôn', 'ngữ', 'phím', 'chính', 'tả',
    'trợ', 'năng', 'đọc', 'dịch', 'ghi', 'chú',
    'giảng', 'cộng', 'đám', 'mây', 'tài', 'khoản', 'hồ', 'sơ',
    'slide', 'deck', 'điểm', 'trung', 'bình', 'hoàn', 'thiện',
  };
  var viHits = 0;
  final root = Directory('lib');
  await for (final entity in root.list(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.contains('app_localizations')) continue; // generated
    final content = await entity.readAsString();
    // Skip locale-aware files (return locale == 'vi' ? … : …).
    if (content.contains("locale == 'vi'") || content.contains('locale == "vi"')) {
      continue;
    }
    for (final m in viRe.allMatches(content)) {
      final token = m.group(1)!.toLowerCase();
      if (RegExp(r'^[a-z0-9_ ]+$').hasMatch(token)) continue;
      final hits = vietnameseTokens.where((t) => token.contains(t));
      if (hits.isNotEmpty && !_isL10nContext(content, m.start)) {
        viHits++;
        if (viHits <= 40) {
          stdout.writeln(
              'VI hardcode? ${entity.path}:${_lineOf(content, m.start)}: "$token"');
        }
      }
    }
  }
  stdout.writeln('VI hardcode heuristic hits: $viHits (informational — '
      'app UI is Vietnamese-primary; EN strings already live in .arb).');

  stdout.writeln(problems == 0 ? 'CLEAN' : 'PROBLEMS: $problems');
  exitCode = problems == 0 ? 0 : 1;
}

Set<String> _keys(String arb) {
  final re = RegExp(r'^\s*"([a-zA-Z0-9_]+)"\s*:', multiLine: true);
  return re.allMatches(arb).map((m) => m.group(1)!).toSet();
}

bool _isL10nContext(String content, int pos) {
  final start = content.lastIndexOf('\n', pos) + 1;
  var end = content.indexOf('\n', pos);
  if (end < 0) end = content.length;
  final line = content.substring(start, end);
  return line.contains('.l10n.') ||
      line.contains('l10n.') ||
      line.contains('tooltip:') ||
      line.contains("'tooltip':") ||
      line.contains("'title':") ||
      line.contains("'content':");
}

int _lineOf(String content, int pos) => content.substring(0, pos).split('\n').length;
