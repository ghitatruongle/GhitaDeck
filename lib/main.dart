import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/home_screen.dart';
import 'providers/app_provider.dart';
import 'providers/ai_provider_manager.dart';
import 'providers/presentation_state.dart';
import 'providers/shortcuts_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'services/collaboration_service.dart';
import 'theme/app_theme.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // window_manager must be initialized before runApp for the editor's
  // fullscreen toggle (View tab) and any window-level operations to work.
  await windowManager.ensureInitialized();

  // Global error boundary
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exception}');
    debugPrint('Stack: ${details.stack}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformDispatcher Error: $error');
    debugPrint('Stack: $stack');
    return true;
  };

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => PresentationState()),
        ChangeNotifierProvider(create: (_) {
          final manager = AIProviderManager();
          // Track 65 OPT 30: heavy init (secure-storage reads) happens after
          // the first frame so startup is never blocked on provider config.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            manager.loadProviders();
          });
          return manager;
        }),
        ChangeNotifierProvider(create: (_) => ShortcutsProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ProxyProvider<PresentationState, CollaborationService>(
          create: (_) => CollaborationService(),
          update: (_, presentation, service) =>
              (service ?? CollaborationService())..bindPresentation(presentation),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: Consumer3<AppProvider, ThemeProvider, LocaleProvider>(
        builder: (context, appProvider, themeProvider, localeProvider, _) {
          return MaterialApp(
            title: 'Ghita PPT Converter',
            debugShowCheckedModeBanner: false,
            locale: localeProvider.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            themeMode: appProvider.themeMode,
            theme: AppTheme.lightTheme(
              primaryColor: themeProvider.primaryColor,
              accentColor: themeProvider.accentColor,
              fontFamily: themeProvider.fontFamily,
            ),
            darkTheme: AppTheme.darkTheme(
              primaryColor: themeProvider.primaryColor,
              accentColor: themeProvider.accentColor,
              fontFamily: themeProvider.fontFamily,
            ),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
