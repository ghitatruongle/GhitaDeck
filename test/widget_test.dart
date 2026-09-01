import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/providers/ai_provider_manager.dart';
import 'package:ghita_ppt_converter/providers/app_provider.dart';
import 'package:ghita_ppt_converter/providers/presentation_state.dart';
import 'package:ghita_ppt_converter/providers/shortcuts_provider.dart';
import 'package:ghita_ppt_converter/providers/theme_provider.dart';
import 'package:ghita_ppt_converter/providers/locale_provider.dart';
import 'package:ghita_ppt_converter/services/rust_engine.dart';
import 'package:ghita_ppt_converter/l10n/app_localizations.dart';
import 'package:ghita_ppt_converter/screens/home_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Ctrl+Shift+E opens Advanced Export with default shortcuts',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final appProvider = AppProvider()..updateIndex(1);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appProvider),
          ChangeNotifierProvider(create: (_) => AIProviderManager()),
          ChangeNotifierProvider(create: (_) => PresentationState()),
          ChangeNotifierProvider(create: (_) => ShortcutsProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => RustEngineService()),
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
            home: const HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Projects'), findsOneWidget);
    final localeProvider = Provider.of<LocaleProvider>(
      tester.element(find.byType(HomeScreen)),
      listen: false,
    );
    await localeProvider.setLocale(const Locale('vi'));
    await tester.pumpAndSettle();
    expect(find.text('D\u1ef1 \u00c1n'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.text('Xu\u1ea5t n\u00e2ng cao'), findsOneWidget);
  });
}
