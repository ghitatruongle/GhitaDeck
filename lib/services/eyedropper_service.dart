import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffi/ffi.dart';

/// Eyedropper Service (Track 24, P1–P2).
///
/// Captures the colour of the screen pixel under the cursor using the
/// Windows GDI API (`GetCursorPos` + `GetPixel`). Returns `#RRGGBB`.
///
/// This is a local, offline implementation — no webview snapshot needed.
class EyedropperService {
  static bool get isSupported => Platform.isWindows;

  // ---- Windows GDI bindings (user32.dll) --------------------------------
  // Modern dart:ffi uses bare native function types as the first type
  // argument (no NativeFunction<> wrapper). GetCursorPos is bound against
  // Pointer<Int32> (the two 32-bit POINT members) to avoid a native Struct.
  static final int Function(Pointer<Int32>) _getCursorPos =
      _user32.lookupFunction<Int32 Function(Pointer<Int32>), int Function(Pointer<Int32>)>(
    'GetCursorPos',
  );
  static final int Function(int) _getDC =
      _user32.lookupFunction<Int32 Function(Int32), int Function(int)>(
    'GetDC',
  );
  static final int Function(int, int) _releaseDC =
      _user32.lookupFunction<Int32 Function(Int32, Int32), int Function(int, int)>(
    'ReleaseDC',
  );
  static final int Function(int, int, int) _getPixel =
      _user32.lookupFunction<Uint32 Function(Int32, Int32, Int32), int Function(int, int, int)>(
    'GetPixel',
  );

  static DynamicLibrary get _user32 => Platform.isWindows
      ? DynamicLibrary.open('user32.dll')
      : DynamicLibrary.process();

  /// Capture the colour at the current cursor position.
  /// Returns `#RRGGBB` or null if the capture fails (e.g. not on Windows).
  static String? pickAtCursor() {
    if (!isSupported) return null;
    try {
      final pt = calloc<Int32>(2);
      try {
        if (_getCursorPos(pt) == 0) return null;
        final x = pt[0];
        final y = pt[1];
        return pickAt(x, y);
      } finally {
        calloc.free(pt);
      }
    } catch (e) {
      debugPrint('Eyedropper error: $e');
      return null;
    }
  }

  /// Capture the colour at explicit screen coordinates.
  static String? pickAt(int x, int y) {
    if (!isSupported) return null;
    try {
      final hdc = _getDC(0); // screen DC
      if (hdc == 0) return null;
      try {
        final colorRef = _getPixel(hdc, x, y);
        if (colorRef == 0xFFFFFFFF) {
          // GetPixel returns CLR_INVALID (0xFFFFFFFF) on failure; a true
          // white pixel is indistinguishable, so re-query once.
          final again = _getPixel(hdc, x, y);
          if (again == 0xFFFFFFFF && again == colorRef) return null;
        }
        // COLORREF layout: 0x00BBGGRR
        final r = colorRef & 0xFF;
        final g = (colorRef >> 8) & 0xFF;
        final b = (colorRef >> 16) & 0xFF;
        return '#${_hex(r)}${_hex(g)}${_hex(b)}';
      } finally {
        _releaseDC(0, hdc);
      }
    } catch (e) {
      debugPrint('Eyedropper error: $e');
      return null;
    }
  }

  static String _hex(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
}
