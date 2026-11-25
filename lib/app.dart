import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/services/home_widget_service.dart';
import 'core/theme/neo_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/main/main_screen.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/transactions/providers/transaction_provider.dart';
import 'features/update/providers/app_update_provider.dart';
import 'features/update/widgets/update_dialog.dart';

class SmartFiApp extends ConsumerStatefulWidget {
  const SmartFiApp({super.key});

  @override
  ConsumerState<SmartFiApp> createState() => _SmartFiAppState();
}

class _SmartFiAppState extends ConsumerState<SmartFiApp> {
  bool _isUpdateDialogOpen = false;

  @override
  void initState() {
    super.initState();
    HomeWidgetService().initDeepLinkHandler((tabIndex) {
      if (!mounted) return;
      ref.read(mainTabIndexProvider.notifier).state = tabIndex;
      if (ref.read(authStateProvider).asData?.value != null) {
        ref.read(routerProvider).go('/dashboard');
      }
    });
  }

  void _maybeShowUpdateDialog(AppUpdateState updateState) {
    if (_isUpdateDialogOpen || !updateState.shouldAutoPrompt) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _isUpdateDialogOpen) return;
      final latestState = ref.read(appUpdateProvider);
      if (!latestState.shouldAutoPrompt) return;

      final navContext = rootNavigatorKey.currentContext;
      if (navContext == null || !navContext.mounted) return;

      _isUpdateDialogOpen = true;
      try {
        await UpdateDialog.show(navContext);
      } finally {
        _isUpdateDialogOpen = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);
    final authAsync = ref.watch(authStateProvider);
    final txsAsync = ref.watch(transactionsProvider);

    // Sinkronkan ringkasan terbaru ke Widget Beranda Android 4x2 secara otomatis
    if (!authAsync.isLoading) {
      final isLoggedIn = authAsync.asData?.value != null;
      if (!isLoggedIn || txsAsync.hasValue) {
        final summary = HomeWidgetSummary.fromTransactions(
          transactions: txsAsync.asData?.value ?? const [],
          savingsTarget: settings.savingsTarget,
          isLoggedIn: isLoggedIn,
          isDark: settings.themeMode == 'dark',
        );
        HomeWidgetService().syncWidget(summary);
      }
    }

    // Aktifkan listener real-time Firestore `app_config/android` sejak aplikasi dibuka
    final updateState = ref.watch(appUpdateProvider);
    _maybeShowUpdateDialog(updateState);

    return MaterialApp.router(
      title: 'SmartFi Mobile',
      debugShowCheckedModeBanner: false,
      theme: NeoTheme.lightTheme,
      darkTheme: NeoTheme.darkTheme,
      themeMode: settings.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      routerConfig: router,
    );
  }
}
