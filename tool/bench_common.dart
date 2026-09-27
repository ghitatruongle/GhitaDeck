import 'dart:convert';
import 'dart:io';

class BenchMetric {
  final String name;
  final double valueMs;
  final double gateMs;

  const BenchMetric(this.name, this.valueMs, this.gateMs);

  bool get passes => valueMs <= gateMs;

  Map<String, dynamic> toJson() => {
        'name': name,
        'valueMs': valueMs,
        'gateMs': gateMs,
        'passes': passes,
      };
}

class BenchEnvironment {
  final String os;
  final int cores;
  final String dartVm;
  final String flutterVersion;
  final DateTime timestamp;

  const BenchEnvironment({
    required this.os,
    required this.cores,
    required this.dartVm,
    required this.flutterVersion,
    required this.timestamp,
  });

  static BenchEnvironment current() {
    return BenchEnvironment(
      os: Platform.operatingSystemVersion,
      cores: Platform.numberOfProcessors,
      dartVm: Platform.version,
      flutterVersion: Platform.environment['FLUTTER_VERSION'] ?? 'unknown',
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'os': os,
        'cores': cores,
        'dartVm': dartVm,
        'flutterVersion': flutterVersion,
        'timestamp': timestamp.toIso8601String(),
      };

  String get header {
    final t = timestamp.toIso8601String().substring(0, 19);
    return '| Điều kiện đo | $os · $cores lõi · Dart $dartVm · lúc $t |';
  }
}

class PerfGateReport {
  final String suite;
  final BenchEnvironment environment;
  final List<BenchMetric> metrics;

  const PerfGateReport({
    required this.suite,
    required this.environment,
    required this.metrics,
  });

  bool get passes => metrics.every((m) => m.passes);

  String get failedNames =>
      metrics.where((m) => !m.passes).map((m) => m.name).join(', ');

  void writeCurrentJson(String path) {
    final file = File(path);
    var existing = <String, dynamic>{};
    if (file.existsSync()) {
      try {
        existing =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      } catch (_) {
        existing = {};
      }
    }
    existing[suite] = {
      'environment': environment.toJson(),
      'metrics': metrics.map((m) => m.toJson()).toList(),
      'passes': passes,
    };
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(existing),
        flush: true);
  }
}
