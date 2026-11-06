// Coverage summary for CI (T04 phase 9).
//
// Reads coverage/lcov.info and prints a compact report — to the console and,
// when running in GitHub Actions, to the job step summary. Thresholds act as
// a RATCHET hard gate: falling below today's measured floors exits non-zero
// so any regression fails CI while later tracks climb toward the 55 %
// repository goal.
//
// Usage: dart run tool/coverage_summary.dart
import 'dart:io';

const _keyFiles = <String, double>{
  'ai_provider_manager.dart': 55.0,
  'pdf_export_service.dart': 65.0,
};

const _repoFloor = 47.0;
const _repoGoal = 55.0;

void main() {
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    stderr.writeln('coverage/lcov.info not found — run flutter test --coverage first.');
    exit(1);
  }

  var totalFound = 0, totalHit = 0;
  var nonL10nFound = 0, nonL10nHit = 0;
  final keyFileStats = <String, ({int hit, int found})>{};

  for (final rawLine in file.readAsLinesSync()) {
    if (rawLine.startsWith('SF:')) {
      final name = rawLine.split(RegExp(r'[\\:]')).last;
      fileIsL10n = name.startsWith('app_localizations');
      keyFileStats[name] = (hit: 0, found: 0);
    } else if (rawLine.startsWith('LF:')) {
      final found = int.parse(rawLine.split(':').last);
      totalFound += found;
      if (!fileIsL10n) nonL10nFound += found;
      _bump(keyFileStats, found, 0);
    } else if (rawLine.startsWith('LH:')) {
      final hit = int.parse(rawLine.split(':').last);
      totalHit += hit;
      if (!fileIsL10n) nonL10nHit += hit;
      _bump(keyFileStats, 0, hit);
    } else if (rawLine.startsWith('end_of_record')) {
      fileIsL10n = false;
    }
  }

  String pct(int hit, int found) =>
      found == 0 ? 'n/a' : '${(100 * hit / found).toStringAsFixed(1)}%';

  final lines = <String>[
    '| Metric | Coverage | Floor | Goal |',
    '| --- | --- | --- | --- |',
    '| Repository (all lib) | ${pct(totalHit, totalFound)} | '
        '$_repoFloor% | $_repoGoal% |',
    '| Repository (ex-generated l10n) | ${pct(nonL10nHit, nonL10nFound)} | — | $_repoGoal% |',
  ];
  keyFileStats.forEach((name, stats) {
    final floor = _keyFiles[name];
    if (floor != null) {
      lines.add('| `$name` | ${pct(stats.hit, stats.found)} | $floor% | $floor% |');
    }
  });

  final report = ['### 📊 Coverage summary', ...lines].join('\n');
  stdout.writeln(report);

  final failures = <String>[];
  if (totalFound == 0) {
    failures.add('no coverage data found in coverage/lcov.info');
  } else if (100 * totalHit / totalFound < _repoFloor) {
    failures.add(
        'repository coverage fell below the $_repoFloor% ratchet floor');
  }
  _keyFiles.forEach((name, floor) {
    if (!keyFileStats.containsKey(name)) {
      failures.add('$name missing from coverage report');
    }
  });
  keyFileStats.forEach((name, stats) {
    final floor = _keyFiles[name];
    if (floor != null) {
      if (stats.found == 0) {
        failures.add('$name has no coverage data');
      } else if (100 * stats.hit / stats.found < floor) {
        failures.add('$name fell below its $floor% floor');
      }
    }
  });
  for (final f in failures) {
    stdout.writeln('::error::coverage gate: $f');
  }
  if (failures.isNotEmpty) {
    stderr.writeln('coverage gate failed with ${failures.length} violation(s)');
    exit(1);
  }

  final summaryPath = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (summaryPath != null) {
    File(summaryPath).writeAsStringSync('$report\n');
  }
}

var fileIsL10n = false;

void _bump(Map<String, ({int hit, int found})> stats, int found, int hit) {
  // The trailing SF entry is the file the current LF/LH belongs to.
  if (stats.isEmpty) return;
  final last = stats.keys.last;
  final cur = stats[last]!;
  stats[last] = (hit: cur.hit + hit, found: cur.found + found);
}
