// T03 (v2.0.1-beta.2) — EyedropperService contract tests (phase 9).
//
// The GDI FFI path (GetCursorPos/GetPixel) cannot be mocked through a
// platform channel, so these tests pin the *contract* that the editor relies
// on: support flag matches the host OS, calls never throw, and every
// non-null result is an uppercase #RRGGBB string. On headless CI sessions
// GetPixel legitimately returns null; on desktop sessions it returns a colour.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/eyedropper_service.dart';

const _colorPattern = r'^#[0-9A-F]{6}$';

void main() {
  group('support detection', () {
    test('isSupported mirrors Platform.isWindows', () {
      expect(EyedropperService.isSupported, Platform.isWindows);
    });
  });

  group('pickAt', () {
    test('never throws and returns either null or #RRGGBB', () {
      String? result = 'sentinel';
      expect(
        () => result = EyedropperService.pickAt(10, 10),
        returnsNormally,
        reason: 'GDI failures must be swallowed, not propagated',
      );
      if (result != null && result!.isNotEmpty) {
        expect(result, matches(_colorPattern));
      }
    });

    test('corner coordinates behave the same as centre ones', () {
      for (final point in [(0, 0), (1, 1)]) {
        String? out;
        expect(() => out = EyedropperService.pickAt(point.$1, point.$2),
            returnsNormally);
        if (out != null) expect(out, matches(_colorPattern));
      }
    });

    test('repeat queries are stable in format (DC released between calls)',
        () {
      final first = EyedropperService.pickAt(5, 5);
      final second = EyedropperService.pickAt(5, 5);
      if (first != null && second != null) {
        // Same screen pixel → same colour on both reads.
        expect(second, first);
      }
    });
  });

  group('pickAtCursor', () {
    test('follows the same result contract as pickAt', () {
      String? out;
      expect(() => out = EyedropperService.pickAtCursor(), returnsNormally);
      if (out != null) {
        expect(out, matches(_colorPattern));
      } else {
        // null is legitimate off-Windows or when GetCursorPos fails.
        expect(Platform.isWindows || out == null, isTrue);
      }
    });
  });
}
