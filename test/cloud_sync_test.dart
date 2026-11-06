import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/services/cloud_sync_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const creds = CloudCredentials(
      baseUrl: 'https://cloud.example.com/remote.php/dav/files/user',
      username: 'user',
      password: 'pw');

  group('T50 — CloudSyncService (WebDAV over fake client)', () {
    test('uploads a version and bumps the counter from PROPFIND listing',
        () async {
      const propfindXml = '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">'
          '<d:response><d:href>/files/user/ghita/p1/v1.ghita</d:href>'
          '<d:propstat><d:prop><d:getcontentlength>10</d:getcontentlength>'
          '<d:getlastmodified>2026-08-15T00:00:00Z</d:getlastmodified>'
          '</d:prop></d:propstat></d:response>'
          '<d:response><d:href>/files/user/ghita/p1/latest.ghita</d:href>'
          '<d:propstat><d:prop><d:getcontentlength>10</d:getcontentlength>'
          '</d:prop></d:propstat></d:response>'
          '</d:multistatus>';

      final seen = <String>[];
      final mock = MockClient((request) async {
        seen.add('${request.method} ${request.url.path}');
        if (request.method == 'PROPFIND') {
          return http.Response(propfindXml, 207);
        }
        if (request.method == 'PUT') {
          expect(request.headers['authorization'], isNotNull);
          if (request.url.path.endsWith('v2.ghita')) {
            return http.Response('', 201);
          }
          return http.Response('', 201);
        }
        return http.Response('', 404);
      });

      final version = await CloudSyncService.uploadVersion(
          creds, 'p1', [1, 2, 3],
          client: mock);
      expect(version, 2, reason: 'requests: $seen');
    });

    test('downloads latest and specific versions', () async {
      final mock = MockClient((request) async {
        if (request.url.path.endsWith('v3.ghita')) {
          return http.Response.bytes([9, 9, 9], 200);
        }
        return http.Response.bytes([1, 2, 3], 200);
      });
      final latest =
          await CloudSyncService.downloadVersion(creds, 'p1', client: mock);
      expect(latest, [1, 2, 3]);
      final v3 = await CloudSyncService.downloadVersion(creds, 'p1',
          version: 3, client: mock);
      expect(v3, [9, 9, 9]);
    });

    test('returns null when the remote file is missing', () async {
      final mock = MockClient((_) async => http.Response('', 404));
      final bytes =
          await CloudSyncService.downloadVersion(creds, 'p1', client: mock);
      expect(bytes, isNull);
    });

    test('lists versions from PROPFIND and sorts newest first', () async {
      const xml = '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">'
          '<d:response><d:href>/files/user/ghita/p1/v1.ghita</d:href>'
          '<d:propstat><d:prop><d:getcontentlength>10</d:getcontentlength>'
          '</d:prop></d:propstat></d:response>'
          '<d:response><d:href>/files/user/ghita/p1/v3.ghita</d:href>'
          '<d:propstat><d:prop><d:getcontentlength>30</d:getcontentlength>'
          '</d:prop></d:propstat></d:response>'
          '<d:response><d:href>/files/user/ghita/p1/v2.ghita</d:href>'
          '<d:propstat><d:prop><d:getcontentlength>20</d:getcontentlength>'
          '</d:prop></d:propstat></d:response>'
          '</d:multistatus>';
      final mock = MockClient((request) async {
        if (request.method == 'PROPFIND') return http.Response(xml, 207);
        return http.Response('', 404);
      });
      final versions =
          await CloudSyncService.listVersions(creds, 'p1', client: mock);
      expect(versions.map((v) => v.version), [3, 2, 1]);
      expect(versions.first.sizeBytes, 30);
    });

    test('deletes a remote version', () async {
      var deleted = false;
      final mock = MockClient((request) async {
        if (request.method == 'DELETE') {
          deleted = true;
          return http.Response('', 204);
        }
        return http.Response('', 404);
      });
      final ok =
          await CloudSyncService.deleteVersion(creds, 'p1', 5, client: mock);
      expect(ok, isTrue);
      expect(deleted, isTrue);
    });

    test('sanitises project names and normalises base URLs', () {
      expect(CloudSyncService.normalizedBaseUrl('https://x.com/'),
          'https://x.com');
      expect(
          CloudSyncService.normalizedBaseUrl('https://x.com'), 'https://x.com');
      expect(
        CloudSyncService.normalizedBaseUrl('http://localhost:8080/'),
        'http://localhost:8080',
      );
      expect(
        () => CloudSyncService.normalizedBaseUrl('http://x.com'),
        throwsFormatException,
      );
      expect(
        () => CloudSyncService.normalizedBaseUrl('https://user:pass@x.com'),
        throwsFormatException,
      );
    });
  });

}
