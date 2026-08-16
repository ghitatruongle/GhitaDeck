import 'dart:io';

typedef Coverage = ({int found, int hit});

void main(List<String> args) {
  final path = args.isEmpty ? 'coverage/lcov.info' : args.first;
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Coverage file not found: $path');
    exitCode = 2;
    return;
  }

  final byFile = <String, Coverage>{};
  String? current;
  var found = 0;
  var hit = 0;
  void finish() {
    final name = current;
    if (name != null) byFile[name] = (found: found, hit: hit);
    current = null;
    found = 0;
    hit = 0;
  }

  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      finish();
      current = line.substring(3).replaceAll('\\', '/');
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length >= 2) {
        found++;
        if ((int.tryParse(parts[1]) ?? 0) > 0) hit++;
      }
    } else if (line == 'end_of_record') {
      finish();
    }
  }
  finish();

  final production = Map<String, Coverage>.fromEntries(byFile.entries.where(
    (entry) =>
        (entry.key.startsWith('lib/') || entry.key.contains('/lib/')) &&
        !entry.key.contains('lib/l10n/app_localizations'),
  ));
  final checks = <String, ({Map<String, Coverage> files, double minimum})>{
    'production': (files: production, minimum: 40),
    'services': (
      files: _matching(production, 'lib/services/'),
      minimum: 65,
    ),
    'providers': (
      files: _matching(production, 'lib/providers/'),
      minimum: 20,
    ),
    'screens': (
      files: _matching(production, 'lib/screens/'),
      minimum: 12,
    ),
  };

  var failed = false;
  for (final entry in checks.entries) {
    final total = _sum(entry.value.files.values);
    final percent = total.found == 0 ? 0 : total.hit * 100 / total.found;
    stdout.writeln(
      '${entry.key}: ${percent.toStringAsFixed(2)}% '
      '(${total.hit}/${total.found}, minimum ${entry.value.minimum.toStringAsFixed(0)}%)',
    );
    if (percent < entry.value.minimum) failed = true;
  }
  if (failed) {
    stderr.writeln('Coverage gate failed.');
    exitCode = 1;
  }
}

Map<String, Coverage> _matching(
  Map<String, Coverage> source,
  String fragment,
) =>
    Map.fromEntries(
        source.entries.where((entry) => entry.key.contains(fragment)));

Coverage _sum(Iterable<Coverage> values) {
  var found = 0;
  var hit = 0;
  for (final value in values) {
    found += value.found;
    hit += value.hit;
  }
  return (found: found, hit: hit);
}
