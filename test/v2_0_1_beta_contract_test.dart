import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/config/build_info.dart';
import 'package:ghita_ppt_converter/models/slide.dart';
import 'package:ghita_ppt_converter/services/project_bundle_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v2.0.1-beta release contract', () {
    test('central metadata has independent app, protocol and schema versions', () {
      expect(BuildInfo.appVersion, '2.0.1-beta.1');
      expect(BuildInfo.displayVersion, '2.0.1-beta.1+1');
      expect(BuildInfo.coreVersion, '2.0.1');
      expect(BuildInfo.collaborationProtocolVersion, 2);
      expect(BuildInfo.bundleSchemaVersion, 2);
    });

    test('new project bundles include app and schema metadata', () async {
      final tempDir = await Directory.systemTemp.createTemp('ghita_beta_contract_');
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
        expect(
          loaded['manifest']['schemaVersion'],
          BuildInfo.bundleSchemaVersion,
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('future project schemas are rejected instead of silently misread', () async {
      final tempDir = await Directory.systemTemp.createTemp('ghita_future_schema_');
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
