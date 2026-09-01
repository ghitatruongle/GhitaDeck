import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/utils/error_mapper.dart';

/// ErrorMapper mapping table: technical errors → user-friendly VI/EN messages.
void main() {
  group('mapErrorToUserMessage', () {
    test('socket/network errors are mapped in both languages', () {
      const e = SocketException('connection refused');
      expect(ErrorMapper.mapErrorToUserMessage(e),
          contains('Không thể kết nối mạng'));
      expect(ErrorMapper.mapErrorToUserMessage(e, locale: 'en'),
          contains('Cannot connect to network'));
    });

    test('timeout errors', () {
      final e = TimeoutException('timed out');
      expect(ErrorMapper.mapErrorToUserMessage(e), contains('hết thời gian'));
      expect(ErrorMapper.mapErrorToUserMessage(e, locale: 'en'),
          contains('Request timed out'));
    });

    test('http exceptions', () {
      for (final code in ['400', '500', '503']) {
        final e = HttpException('HTTP $code status code', uri: Uri.parse('http://x/'));
        expect(ErrorMapper.mapErrorToUserMessage(e), isNotEmpty);
        expect(ErrorMapper.mapErrorToUserMessage(e, locale: 'en'), isNotEmpty);
      }
    });

    test('file system errors', () {
      const fs = FileSystemException('Cannot open', 'file.txt');
      expect(ErrorMapper.mapErrorToUserMessage(fs), isNotEmpty);
      const pa = FileSystemException('Access denied', '/x');
      expect(ErrorMapper.mapErrorToUserMessage(pa, locale: 'en')
          .trim(), isNotEmpty);
    });

    test('format errors', () {
      const e = FormatException('bad');
      expect(ErrorMapper.mapErrorToUserMessage(e), contains('không hợp lệ'));
      expect(ErrorMapper.mapErrorToUserMessage(e, locale: 'en'),
          contains('Invalid data'));
    });

    test('http status strings 401/403/404 are recognized', () {
      expect(ErrorMapper.mapErrorToUserMessage('401 Unauthorized'),
          contains('Phiên đăng nhập'));
      expect(ErrorMapper.mapErrorToUserMessage('403 Forbidden', locale: 'en'),
          contains('permission'));
      expect(ErrorMapper.mapErrorToUserMessage('404 Not Found', locale: 'en'),
          contains('Resource not found'));
    });

    test('unknown errors fall back to a generic message', () {
      expect(ErrorMapper.mapErrorToUserMessage(Exception('weird')), isNotEmpty);
      expect(ErrorMapper.mapErrorToUserMessage(Exception('weird'), locale: 'en'),
          isNotEmpty);
    });
  });
}
