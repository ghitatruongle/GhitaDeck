import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalImageAllowlist {
  LocalImageAllowlist._();

  static List<String>? debugAllowedDirs;

  static final Set<String> _roots = <String>{};
  static final Set<String> _pickedFiles = <String>{};
  static String? _projectDir;
  static bool _warmed = false;

  static bool get isWarmed => _warmed;

  static Future<void> ensureWarm() async {
    if (_warmed) return;
    final override = debugAllowedDirs;
    if (override != null) {
      for (final dir in override) {
        _addRoot(dir);
      }
      _warmed = true;
      return;
    }
    try {
      final support = await getApplicationSupportDirectory();
      _addRoot(support.path);
      final temp = await getTemporaryDirectory();
      _addRoot(temp.path);
      final docs = await getApplicationDocumentsDirectory();
      _addRoot(p.join(docs.path, 'GhitaDeck'));
    } catch (_) {}
    _warmed = true;
  }

  static void registerPickedFile(String path) {
    final canonical = _canonicalFile(path);
    if (canonical == null) return;
    _pickedFiles.add(canonical);
    _addRoot(p.dirname(canonical));
  }

  static void registerPickedDirectory(String path) {
    _addRoot(path);
  }

  static void setCurrentProjectDir(String? path) {
    if (path == null || path.isEmpty) {
      _projectDir = null;
      return;
    }
    _projectDir = _canonicalDir(path);
  }

  static bool allows(String src) {
    if (src.isEmpty) return false;
    final lower = src.toLowerCase();
    if (lower.startsWith('file:')) return false;
    if (lower.startsWith('\\\\')) return false;
    if (!p.isAbsolute(src)) {
      final projectDir = _projectDir;
      if (projectDir == null) return false;
      final joined = _canonicalFile(p.join(projectDir, src));
      if (joined == null) return false;
      return _isAllowedPath(joined);
    }
    final candidate = _canonicalFile(src);
    if (candidate == null) return false;
    return _isAllowedPath(candidate);
  }

  static void resetForTests() {
    _roots.clear();
    _pickedFiles.clear();
    _projectDir = null;
    _warmed = false;
  }

  static Map<String, dynamic> exportSnapshot() => {
        'roots': _roots.toList(growable: false),
        'pickedFiles': _pickedFiles.toList(growable: false),
        'projectDir': _projectDir ?? '',
      };

  static void applySnapshot(Map<String, dynamic> snapshot) {
    final roots = snapshot['roots'];
    if (roots is List) {
      for (final root in roots) {
        _addRoot(root.toString());
      }
    }
    final picked = snapshot['pickedFiles'];
    if (picked is List) {
      for (final file in picked) {
        final canonical = _canonicalPath(file.toString());
        if (canonical != null) _pickedFiles.add(canonical);
      }
    }
    final project = snapshot['projectDir'];
    _projectDir = project is String && project.isNotEmpty ? project : null;
    _warmed = true;
  }

  static bool _isAllowedPath(String candidate) {
    if (_pickedFiles.contains(candidate)) return true;
    for (final root in _roots) {
      if (candidate == root || candidate.startsWith('$root${p.separator}')) {
        return true;
      }
    }
    final projectDir = _projectDir;
    if (projectDir != null &&
        (candidate == projectDir ||
            candidate.startsWith('$projectDir${p.separator}'))) {
      return true;
    }
    return false;
  }

  static void _addRoot(String path) {
    final canonical = _canonicalPath(path);
    if (canonical == null || canonical.isEmpty) return;
    _roots.add(canonical);
  }

  static String? _canonicalPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.toLowerCase().startsWith('file:')) return null;
    return _normalize(trimmed);
  }

  static String? _canonicalFile(String path) {
    final canonical = _canonicalPath(path);
    if (canonical == null || canonical.isEmpty) return null;
    return canonical;
  }

  static String? _canonicalDir(String path) {
    return _canonicalPath(path);
  }

  static String _normalize(String path) {
    var normalized = p.normalize(p.absolute(path));
    while (normalized.endsWith('/') || normalized.endsWith('\\')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized.toLowerCase();
  }
}
