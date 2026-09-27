import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  const currentPath = 'tool/perf_current.json';
  const baselinePath = 'tool/perf_baseline.json';
  final suites = args.isEmpty
      ? null
      : args.toSet();

  final currentFile = File(currentPath);
  if (!currentFile.existsSync()) {
    stderr.writeln(
        'perf gate: $currentPath not found. Run the benchmark suites with '
        'GHITA_BENCH_LABEL set before gating.');
    exit(2);
  }
  final baselineFile = File(baselinePath);
  if (!baselineFile.existsSync()) {
    stderr.writeln('perf gate: $baselinePath not found.');
    exit(2);
  }

  Map<String, dynamic> current;
  Map<String, String> baseline;
  try {
    current = jsonDecode(currentFile.readAsStringSync()) as Map<String, dynamic>;
    baseline = (jsonDecode(baselineFile.readAsStringSync()) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v.toString()));
  } catch (e) {
    stderr.writeln('perf gate: unreadable input ($e)');
    exit(2);
  }

  var failures = 0;
  for (final entry in current.entries) {
    final suite = entry.key;
    if (suites != null && !suites.contains(suite)) continue;
    final data = entry.value as Map<String, dynamic>;
    for (final metric in (data['metrics'] as List).cast<Map<String, dynamic>>()) {
      final name = metric['name'] as String;
      final gate = baseline[name];
      if (gate == null) continue;
      final value = (metric['valueMs'] as num).toDouble();
      final gateValue = double.tryParse(gate) ?? 0;
      final ok = value <= gateValue;
      final mark = ok ? 'PASS' : 'FAIL';
      stdout.writeln('perf gate [$suite] $mark $name: ${value.toStringAsFixed(1)} ms '
          '(gate $gateValue ms)');
      if (!ok) failures++;
    }
  }

  if (failures > 0) {
    stderr.writeln('perf gate: $failures metric(s) breached their gates.');
    exit(1);
  }
  stdout.writeln('perf gate: all measured metrics within gates.');
}
