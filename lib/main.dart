import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_theme.dart';
import 'core/database/db_helper.dart';
import 'core/services/audio_service.dart';
import 'core/services/storage_service.dart';
import 'providers/app_settings_provider.dart';
import 'providers/customer_debt_provider.dart';
import 'providers/financial_report_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/pos_provider.dart';
import 'providers/supplier_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Core Services
  await StorageService.init();
  AudioService.init();

  // Pre-warm database & catalog copy
  try {
    await DBHelper.instance.database;
  } catch (_) {}

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()..loadSettings()),
        ChangeNotifierProvider(create: (_) => POSProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => CustomerDebtProvider()),
        ChangeNotifierProvider(create: (_) => SupplierProvider()),
        ChangeNotifierProvider(create: (_) => FinancialReportProvider()),
      ],
      child: const NadmhaApp(),
    ),
  );
}

class NadmhaApp extends StatelessWidget {
  const NadmhaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettingsProvider>(context);
    final bool isOnboardingDone = StorageService.isOnboardingCompleted();

    return MaterialApp(
      title: 'نظمها - Nadmha POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(settings.language),
      supportedLocales: const [
        Locale('ar', 'DZ'),
        Locale('fr', 'DZ'),
        Locale('ar'),
        Locale('fr'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: isOnboardingDone ? const MainNavigationScreen() : const OnboardingScreen(),
    );
  }
}
