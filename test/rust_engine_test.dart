import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/l10n/app_localizations.dart';
import 'package:ghita_ppt_converter/screens/settings_screen.dart';
import 'package:ghita_ppt_converter/services/rust_engine.dart';
import 'package:ghita_ppt_converter/services/zip_codec.dart';
import 'package:ghita_ppt_converter/providers/ai_provider_manager.dart';
import 'package:ghita_ppt_converter/providers/app_provider.dart';
import 'package:ghita_ppt_converter/providers/locale_provider.dart';
import 'package:ghita_ppt_converter/providers/shortcuts_provider.dart';
import 'package:ghita_ppt_converter/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Rust init succeeds → rustReady with reported version', () async {
    final service =
        RustEngineService(rustInit: () async => 'ghita_core 0.1.0');
    await service.ensureInitialized();

    expect(service.status, EngineStatus.rustReady);
    expect(service.detail, 'ghita_core 0.1.0');
  });

  test('Broken init → fallingBack, never throws (auto-fallback)', () async {
    final service = RustEngineService(
        rustInit: () async => throw StateError('cannot find dll'));
    await service.ensureInitialized();

    expect(service.status, EngineStatus.fallingBack);
    expect(service.detail, contains('cannot find dll'));
  });

  test('setEngine(rust) retries failed init', () async {
    var calls = 0;
    final service = RustEngineService(rustInit: () async {
      calls++;
      if (calls == 1) throw StateError('first load broken');
      return 'ghita_core 0.1.0';
    });

    await service.ensureInitialized();
    expect(service.status, EngineStatus.fallingBack);

    await service.setEngine(EngineKind.rust);
    expect(service.status, EngineStatus.rustReady);
    expect(calls, 2);
  });

  test('setEngine(dart) persists preference and stays on Dart', () async {
    final service = RustEngineService(rustInit: () async => 'ghita_core');
    await service.loadPreference();
    expect(service.preferred, EngineKind.dart); // default = Dart (T02 gate)

    await service.setEngine(EngineKind.dart);
    expect(service.preferred, EngineKind.dart);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(RustEngineService.prefKey), 'dart');
  });

  test('loadPreference reads stored engine choice', () async {
    SharedPreferences.setMockInitialValues(
        {RustEngineService.prefKey: 'dart'});
    final service = RustEngineService();

    await service.loadPreference();
    expect(service.preferred, EngineKind.dart);
  });

  test('loadPreference maps stored rust choice and syncs zip config', () async {
    SharedPreferences.setMockInitialValues(
        {RustEngineService.prefKey: 'rust'});
    ZipEngineConfig.setPreferredRust(false);
    final service = RustEngineService();

    await service.loadPreference();
    expect(service.preferred, EngineKind.rust);
    expect(ZipEngineConfig.preferredRust, isTrue,
        reason: 'engine preference must reach the zip backend');
  });

  test('init runs only once (no duplicate DLL load)', () async {
    var calls = 0;
    final service = RustEngineService(rustInit: () async {
      calls++;
      return 'ghita_core';
    });

    await service.ensureInitialized();
    await service.ensureInitialized();
    expect(calls, 1);
  });

  testWidgets('Settings Engine card shows fallback status', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final engine = RustEngineService(
        rustInit: () async => throw StateError('dll missing'));
    // Probe now so the card renders the settled status without async churn.
    await engine.ensureInitialized();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: engine),
          ChangeNotifierProvider(create: (_) => AppProvider()),
          ChangeNotifierProvider(create: (_) => AIProviderManager()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => ShortcutsProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: Consumer<LocaleProvider>(
          builder: (context, localeProvider, _) => MaterialApp(
            locale: localeProvider.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Engine'), findsOneWidget);
    // Preferred engine is Dart (measurement-backed default); with the real
    // probe failing the card must not claim Rust is running.
    expect(find.textContaining('Dart engine'), findsOneWidget);
    expect(find.textContaining('Rust engine'), findsNothing);
  });
}
