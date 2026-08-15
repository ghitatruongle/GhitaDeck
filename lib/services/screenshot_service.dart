/// Screenshot capture service (Track 16, FEAT 13).
///
/// Captures the Windows desktop to a PNG file using a PowerShell
/// `Add-Type` C# helper (no FFmpeg, no third-party dependency — the
/// built-in .NET `Graphics.CopyFromScreen` is always available on
/// Windows 7+). Supports full-screen, active window, and custom region
/// capture.
library;

import 'dart:io';
import 'dart:typed_data';

class ScreenshotService {
  ScreenshotService._();

  /// The C# helper embedded in the PowerShell script — compiled on-the-fly
  /// by `Add-Type` so it works on any Windows machine without admin rights.
  static const String _csharpHelper = '''
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public class ScreenCapture {
  [DllImport("user32.dll")]
  static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")]
  static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")]
  static extern IntPtr GetDC(IntPtr hWnd);
  [DllImport("user32.dll")]
  static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);

  [StructLayout(LayoutKind.Sequential)]
  public struct RECT { public int Left, Top, Right, Bottom; }

  public static void CaptureFullScreen(string path) {
    var bounds = System.Windows.Forms.Screen.PrimaryScreen.Bounds;
    using (var bmp = new Bitmap(bounds.Width, bounds.Height)) {
      using (var g = Graphics.FromImage(bmp)) {
        g.CopyFromScreen(bounds.X, bounds.Y, 0, 0, bounds.Size);
      }
      bmp.Save(path, ImageFormat.Png);
    }
  }

  public static void CaptureWindow(string path) {
    var hWnd = GetForegroundWindow();
    RECT r;
    GetWindowRect(hWnd, out r);
    int w = r.Right - r.Left, h = r.Bottom - r.Top;
    if (w <= 0 || h <= 0) { CaptureFullScreen(path); return; }
    using (var bmp = new Bitmap(w, h)) {
      using (var g = Graphics.FromImage(bmp)) {
        g.CopyFromScreen(r.Left, r.Top, 0, 0, new Size(w, h));
      }
      bmp.Save(path, ImageFormat.Png);
    }
  }

  public static void CaptureRegion(string path, int x, int y, int w, int h) {
    if (w <= 0 || h <= 0) { CaptureFullScreen(path); return; }
    using (var bmp = new Bitmap(w, h)) {
      using (var g = Graphics.FromImage(bmp)) {
        g.CopyFromScreen(x, y, 0, 0, new Size(w, h));
      }
      bmp.Save(path, ImageFormat.Png);
    }
  }
}
''';

  /// Capture the full screen and return the PNG bytes.
  static Future<Uint8List?> captureFullScreen() async =>
      _capture('CaptureFullScreen');

  /// Capture the active foreground window and return the PNG bytes.
  static Future<Uint8List?> captureWindow() async =>
      _capture('CaptureWindow');

  /// Capture a screen region [x,y,w,h] and return the PNG bytes.
  static Future<Uint8List?> captureRegion(
      int x, int y, int w, int h) async =>
      _capture('CaptureRegion', args: '$x,$y,$w,$h');

  /// Run the PowerShell capture script and return the PNG bytes.
  static Future<Uint8List?> _capture(String method, {String args = ''}) async {
    final outPath =
        '${Directory.systemTemp.path}\\ghita_ss_${DateTime.now().millisecondsSinceEpoch}.png';
    try {
      final script = '''
Add-Type -TypeDefinition @"
$_csharpHelper
"@ -ReferencedAssemblies "System.Drawing","System.Windows.Forms"
[ScreenCapture].$method("$outPath"${args.isNotEmpty ? ',$args' : ''})
''';
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', script],
      );
      if (result.exitCode != 0) return null;
      final file = File(outPath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      await file.delete();
      return bytes;
    } catch (_) {
      return null;
    }
  }
}