import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/config/build_info.dart';
import 'package:ghita_deck/models/slide.dart';
import 'package:ghita_deck/services/project_bundle_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('0.0.2 release contract', () {
    test('central metadata has independent app, protocol and schema versions',
        () {
      expect(BuildInfo.appVersion, '0.0.2');
      expect(BuildInfo.displayVersion, '0.0.2+3');
      expect(BuildInfo.coreVersion, '2.0.5-beta.3');
      expect(BuildInfo.collaborationProtocolVersion, 2);
      expect(BuildInfo.bundleSchemaVersion, 2);
    });

    test('pubspec version matches the centralized release contract', () {
      final content = File('pubspec.yaml').readAsStringSync();
      expect(content, contains('version: 0.0.2+3'));
      expect(content, contains('name: ghita_deck'));
    });

    test('installer defines use the stable display version', () {
      final content =
          File('installer/ghita_deck_installer.iss').readAsStringSync();
      expect(content, contains('#define MyAppDisplayVersion "0.0.2+3"'));
      expect(content, contains('#define MyAppVersion "0.0.2"'));
      expect(content, contains('#define MyAppBuild "3"'));
    });

    test('new project bundles include app and schema metadata', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('ghita_release_contract_');
      try {
        final path = '${tempDir.path}/new.ghita';
        final service = ProjectBundleService();
        expect(
          await service.saveProjectBundle(
            targetPath: path,
            slides: [Slide(title: 'Intro', htmlContent: '<h1>Intro</h1>')],
          ),
          isTrue,
        );
        final loaded = await service.loadProjectBundle(
          path,
          extractDir: tempDir.path,
        );
        expect(loaded, isNotNull);
        expect(loaded!['manifest']['appVersion'], BuildInfo.appVersion);
        expect(loaded['manifest']['schemaVersion'],
            BuildInfo.bundleSchemaVersion);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('future project schemas are rejected instead of silently misread',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('ghita_future_schema_');
      try {
        final path = '${tempDir.path}/future.ghita';
        final service = ProjectBundleService();
        expect(
          await service.saveProjectBundle(
            targetPath: path,
            slides: [Slide(title: 'Future', htmlContent: '<p>Future</p>')],
            schemaVersion: BuildInfo.bundleSchemaVersion + 1,
          ),
          isTrue,
        );
        expect(
          await service.loadProjectBundle(path, extractDir: tempDir.path),
          isNull,
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
