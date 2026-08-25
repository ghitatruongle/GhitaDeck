// P2 (v2.0.1-beta.2) — UI layout audit.
//
// Pumps the main screens at the window sizes and text scales that map to
// real Windows scaling (100 % / 125 % / 150 %) and fails on ANY layout
// exception (RenderFlex overflow, unbounded constraints, late-init crashes).
// This is the automated half of the manual scaling matrix from T05 phase 9.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/config/build_info.dart';
import 'package:ghita_ppt_converter/l10n/app_localizations.dart';
import 'package:ghita_ppt_converter/providers/ai_provider_manager.dart';
import 'package:ghita_ppt_converter/providers/locale_provider.dart';
import 'package:ghita_ppt_converter/providers/app_provider.dart';
import 'package:ghita_ppt_converter/providers/presentation_state.dart';
import 'package:ghita_ppt_converter/providers/shortcuts_provider.dart';
import 'package:ghita_ppt_converter/providers/theme_provider.dart';
import 'package:ghita_ppt_converter/screens/editor/editor_shell.dart';
import 'package:ghita_ppt_converter/screens/editor/editor_state.dart';
import 'package:ghita_ppt_converter/screens/recent_projects_screen.dart';
import 'package:ghita_ppt_converter/screens/settings_screen.dart';
import 'package:ghita_ppt_converter/screens/theme_settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
const _windowManagerChannel = MethodChannel('window_manager');

Widget _app(Widget home, double textScale) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>(create: (_) => AppProvider()),
        ChangeNotifierProvider<PresentationState>(create: (_) {
          final state = PresentationState();
          state
            ..addSlide(Slide(
              title: 'Slide dài để thử bố cục với tiêu đề rất dài ă â ê ô ơ ư',
              htmlContent:
                  '<h1>Tiêu đề</h1><p>Nội dung mẫu có dấu tiếng Việt để kiểm '
                  'tra xuống dòng, bảng <b>đậm</b> <i>nghiêng</i> và danh sách.</p>'
                  '<ul><li>Mục một</li><li>Mục hai</li></ul>',
              notes: 'Ghi chú người trình bày cho slide thử bố cục.',
            ))
            ..addSlide(Slide(title: 'Hai', htmlContent: '<p>2</p>'));
          return state;
        }),
        ChangeNotifierProvider<AIProviderManager>(
            create: (_) => AIProviderManager()),
        ChangeNotifierProvider<ShortcutsProvider>(
            create: (_) => ShortcutsProvider()),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
        ChangeNotifierProvider<EditorState>(create: (_) => EditorState()),
      ],
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        locale: const Locale('vi'),
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: Scaffold(body: home),
      ),
    );

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget screen,
  Size size,
  double textScale,
) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
          size: size, textScaler: TextScaler.linear(textScale)),
      child: _app(screen, textScale),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  final exception = tester.takeException();
  expect(exception, isNull,
      reason: 'layout broke at ${size.width}x${size.height} '
          'textScale $textScale: $exception');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final tempDir = Directory.systemTemp.createTempSync('ghita_p2_audit');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
    // window_manager is a pure pass-through plugin: answer every call so
    // HomeScreen lifecycle code can run headless.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_windowManagerChannel, (call) async => null);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pathProviderChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_windowManagerChannel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
  });

  const sizes = <Size>[Size(1280, 720), Size(1024, 640)];
  const scales = <double>[1.0, 1.25, 1.5];

  group('editor shell', () {
    for (final size in sizes) {
      for (final scale in scales) {
        testWidgets(
            '${size.width.toInt()}x${size.height.toInt()} @ ${(scale * 100).round()}%',
            (tester) async {
          await tester.binding.setSurfaceSize(size);
          final screen = Builder(
            builder: (context) => Consumer<PresentationState>(
              builder: (context, pres, _) => const EditorShell(),
            ),
          );
          await _pumpScreen(tester, screen, size, scale);
          await tester.pump(const Duration(seconds: 1));
          final exception = tester.takeException();
          expect(exception, isNull);
        });
      }
    }
  });

  group('standalone screens', () {
    final screens = <String, Widget Function()>{
      'recent projects': () => const RecentProjectsScreen(),
      'settings': () => const SettingsScreen(),
      'theme settings': () => const ThemeSettingsScreen(),
    };

    screens.forEach((name, build) {
      for (final size in sizes) {
        for (final scale in scales) {
          testWidgets('$name ${size.width.toInt()}x${size.height.toInt()} '
              '@ ${(scale * 100).round()}%', (tester) async {
            await _pumpScreen(tester, build(), size, scale);
          });
        }
      }
    });

    test('build info reports the stable release identity', () {
      expect(BuildInfo.appVersion, '2.0.1');
      expect(BuildInfo.channel, 'stable');
      expect(BuildInfo.numericVersion, '2.0.1.3');
    });
  });
}
