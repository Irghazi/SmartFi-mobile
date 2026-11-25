import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/services/app_update_service.dart';
import 'package:mobile/core/services/home_widget_service.dart';
import 'package:mobile/core/theme/neo_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/validators.dart';
import 'package:mobile/data/models/app_update_model.dart';
import 'package:mobile/data/models/category_model.dart';
import 'package:mobile/data/models/transaction_model.dart';
import 'package:mobile/data/models/user_model.dart';
import 'package:mobile/data/repositories/dummy/dummy_auth_repository.dart';
import 'package:mobile/data/repositories/dummy/dummy_category_repository.dart';
import 'package:mobile/data/repositories/dummy/dummy_transaction_repository.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/auth/screens/login_screen.dart';
import 'package:mobile/features/auth/screens/register_screen.dart';
import 'package:mobile/features/categories/providers/category_provider.dart';
import 'package:mobile/features/dashboard/widgets/category_pie_chart.dart';
import 'package:mobile/features/dashboard/widgets/expense_bar_chart.dart';
import 'package:mobile/features/dashboard/widgets/recent_transactions_list.dart';
import 'package:mobile/features/dashboard/widgets/summary_cards.dart';
import 'package:mobile/features/dashboard/widgets/widget_2x2.dart';
import 'package:mobile/features/reports/widgets/report_filter_card.dart';
import 'package:mobile/features/reports/widgets/report_summary_cards.dart';
import 'package:mobile/features/reports/widgets/report_table.dart';
import 'package:mobile/features/settings/providers/settings_provider.dart';
import 'package:mobile/features/settings/widgets/app_update_card.dart';
import 'package:mobile/features/settings/widgets/audio_settings_card.dart';
import 'package:mobile/features/settings/widgets/balance_correction_card.dart';
import 'package:mobile/features/settings/widgets/danger_zone_card.dart';
import 'package:mobile/features/settings/widgets/notification_settings_card.dart';
import 'package:mobile/features/settings/widgets/savings_target_card.dart';
import 'package:mobile/features/settings/widgets/subscription_info_card.dart';
import 'package:mobile/features/settings/widgets/theme_settings_card.dart';
import 'package:mobile/features/transactions/providers/transaction_provider.dart';
import 'package:mobile/features/transactions/services/smart_input_parser.dart';
import 'package:mobile/features/transactions/widgets/transaction_form_dialog.dart';
import 'package:mobile/features/transactions/widgets/transaction_monthly_summary.dart';
import 'package:mobile/features/update/providers/app_update_provider.dart';
import 'package:mobile/shared/widgets/neo_app_bar.dart';
import 'package:mobile/shared/widgets/neo_badge.dart';
import 'package:mobile/shared/widgets/neo_card.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
    SharedPreferences.setMockInitialValues({});
  });

  group('SmartFi Unit & Widget Tests', () {
    test('CurrencyFormatter memformat Rupiah & angka negatif secara konsisten', () {
      expect(CurrencyFormatter.formatRupiah(1000000), 'Rp 1.000.000');
      expect(CurrencyFormatter.formatRupiah(25000), 'Rp 25.000');
      expect(CurrencyFormatter.formatRupiah(0), 'Rp 0');
      expect(CurrencyFormatter.formatRupiah(-50000), '-Rp 50.000');
      expect(CurrencyFormatter.parseCleanInt('-50.000'), -50000);
      expect(CurrencyFormatter.parseCleanInt('Rp 1.250.000'), 1250000);
    });

    test('Validators memvalidasi email dan kata sandi dengan benar', () {
      expect(Validators.validateEmail('user@smartfi.com'), isNull);
      expect(Validators.validateEmail('bukan-email'), isNotNull);
      expect(Validators.validatePassword('123456'), isNull);
      expect(Validators.validatePassword('123'), isNotNull);
      expect(Validators.validateRequired('', 'Nama'), isNotNull);
      expect(Validators.validateNominal('0'), isNotNull);
    });

    test(
      'SmartInputParser menangani kata kunci, word boundary, dan nominal kecil',
      () {
        final categories = CategoryModel.defaultCategories;
        final parseExpense = SmartInputParser.parse(
          'Makan siang padang 25 ribu',
          categories,
        );
        expect(parseExpense.type, 'expense');
        expect(parseExpense.nominal, 25000);
        expect(parseExpense.category, 'Makanan');

        final parseIncome = SmartInputParser.parse(
          'Gaji bulanan kantor 5 juta',
          categories,
        );
        expect(parseIncome.type, 'income');
        expect(parseIncome.nominal, 5000000);
        expect(parseIncome.category, 'Gaji');

        // Kata "masuk" pada "masuk angin" tidak boleh salah deteksi sebagai pemasukan
        final parseMed = SmartInputParser.parse(
          'Beli obat masuk angin 15rb',
          categories,
        );
        expect(parseMed.type, 'expense');
        expect(parseMed.nominal, 15000);

        // Nominal kecil < 1000 tetap terbaca
        final parseParking = SmartInputParser.parse(
          'Parkir motor 500',
          categories,
        );
        expect(parseParking.type, 'expense');
        expect(parseParking.nominal, 500);
        expect(parseParking.category, 'Transportasi');
      },
    );

    testWidgets('NeoBadge & NeoCard aman di ruang sempit dan mendukung Dark Mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NeoTheme.darkTheme,
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 110,
                child: NeoCard(
                  child: NeoBadge(text: 'KATEGORI PANJANG SEKALI'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('KATEGORI PANJANG SEKALI'), findsOneWidget);
    });

    testWidgets('Dashboard, Transaksi, Laporan & Settings bebas overflow di layar 320px + textScale 1.3 (Dark Mode)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final sampleTxs = [
        TransactionModel(
          id: 'tx_1',
          userId: 'u1',
          type: 'income',
          nominal: 15000000,
          description: 'Gaji Bulanan & Bonus Proyek Besar Akhir Tahun',
          categoryId: 'def-4',
          categoryName: 'Gaji',
          transactionDate: now,
          createdAt: now,
        ),
        TransactionModel(
          id: 'tx_2',
          userId: 'u1',
          type: 'expense',
          nominal: 3750000,
          description: 'Belanja Kebutuhan Rumah Tangga dan Bahan Pokok',
          categoryId: 'def-1',
          categoryName: 'Belanja Rumah Tangga Bulanan',
          transactionDate: now,
          createdAt: now,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream<AppUser?>.value(null)),
            transactionRepositoryProvider.overrideWithValue(DummyTransactionRepository()),
            transactionsProvider.overrideWith(
              (ref) => TransactionsNotifier(
                ref.read(transactionRepositoryProvider),
                null,
              ),
            ),
          ],
          child: MaterialApp(
            theme: NeoTheme.lightTheme,
            darkTheme: NeoTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    const DashboardSummaryCards(
                      balance: 11250000,
                      income: 15000000,
                      expense: 3750000,
                    ),
                    const SizedBox(height: 12),
                    Widget2x2(
                      balance: 11250000,
                      incomeThisMonth: 15000000,
                      expenseThisMonth: 3750000,
                      targetSavings: 5000000,
                      transactionsThisMonth: sampleTxs,
                    ),
                    const SizedBox(height: 12),
                    ExpenseBarChart(transactions: sampleTxs),
                    const SizedBox(height: 12),
                    CategoryPieChart(transactions: sampleTxs),
                    const SizedBox(height: 12),
                    RecentTransactionsList(transactions: sampleTxs),
                    const SizedBox(height: 12),
                    TransactionMonthlySummary(transactions: sampleTxs),
                    const SizedBox(height: 12),
                    ReportFilterCard(
                      startDate: now,
                      endDate: now,
                      reportType: 'all',
                      onStartDateChanged: (_) {},
                      onEndDateChanged: (_) {},
                      onReportTypeChanged: (_) {},
                      onSearch: () {},
                      onReset: () {},
                    ),
                    const SizedBox(height: 12),
                    const ReportSummaryCards(
                      totalIncome: 15000000,
                      totalExpense: 3750000,
                      netBalance: 11250000,
                    ),
                    const SizedBox(height: 12),
                    ReportTable(
                      transactions: sampleTxs,
                      totalIncome: 15000000,
                      totalExpense: 3750000,
                      netBalance: 11250000,
                    ),
                    const SizedBox(height: 12),
                    const AudioSettingsCard(),
                    const SizedBox(height: 12),
                    const NotificationSettingsCard(),
                    const SizedBox(height: 12),
                    const ThemeSettingsCard(),
                    const SizedBox(height: 12),
                    const SavingsTargetCard(),
                    const SizedBox(height: 12),
                    const BalanceCorrectionCard(),
                    const SizedBox(height: 12),
                    const DangerZoneCard(),
                    const SizedBox(height: 12),
                    const SubscriptionInfoCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('25% dari pemasukan'), findsOneWidget);
    });

    testWidgets('LoginScreen & RegisterScreen bebas overflow di layar 320px', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    test('Provider repository aman fallback ke Dummy saat Firebase belum diinisialisasi', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(authRepositoryProvider), isA<DummyAuthRepository>());
      expect(container.read(transactionRepositoryProvider), isA<DummyTransactionRepository>());
      expect(container.read(categoryRepositoryProvider), isA<DummyCategoryRepository>());
    });

    testWidgets('NeoAppBar menampilkan notifikasi defisit & target tabungan secara akurat', (
      WidgetTester tester,
    ) async {
      final now = DateTime.now();
      final surplusMeetingTarget = [
        TransactionModel(
          id: 'tx_a',
          userId: 'u1',
          type: 'income',
          nominal: 10000000,
          description: 'Gaji',
          categoryId: 'def-4',
          categoryName: 'Gaji',
          transactionDate: now,
          createdAt: now,
        ),
        TransactionModel(
          id: 'tx_b',
          userId: 'u1',
          type: 'expense',
          nominal: 2000000,
          description: 'Kebutuhan Bulanan',
          categoryId: 'def-1',
          categoryName: 'Makanan',
          transactionDate: now,
          createdAt: now,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('scope_surplus_ok'),
          overrides: [
            authStateProvider.overrideWith((ref) => Stream<AppUser?>.value(null)),
            settingsProvider.overrideWith(
              (ref) => _StubSettingsNotifier(
                ref,
                const SettingsState(savingsTarget: 5000000),
              ),
            ),
            transactionsProvider.overrideWith(
              (ref) => _StubTransactionsNotifier(surplusMeetingTarget),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              appBar: NeoAppBar(title: 'Beranda'),
              body: SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();
      expect(find.textContaining('Semua aman'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Kasus di bawah target tabungan (masuk 10jt, keluar 7jt -> sisa 3jt < target 5jt)
      final belowTargetTxs = [
        surplusMeetingTarget.first,
        surplusMeetingTarget.last.copyWith(nominal: 7000000),
      ];
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('scope_below_target'),
          overrides: [
            authStateProvider.overrideWith((ref) => Stream<AppUser?>.value(null)),
            settingsProvider.overrideWith(
              (ref) => _StubSettingsNotifier(
                ref,
                const SettingsState(savingsTarget: 5000000),
              ),
            ),
            transactionsProvider.overrideWith(
              (ref) => _StubTransactionsNotifier(belowTargetTxs),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              appBar: NeoAppBar(title: 'Beranda'),
              body: SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();
      expect(find.text('DI BAWAH TARGET TABUNGAN'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Kasus defisit bulanan (masuk 3jt, keluar 4.5jt)
      final deficitTxs = [
        surplusMeetingTarget.first.copyWith(nominal: 3000000),
        surplusMeetingTarget.last.copyWith(nominal: 4500000),
      ];
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('scope_deficit'),
          overrides: [
            authStateProvider.overrideWith((ref) => Stream<AppUser?>.value(null)),
            settingsProvider.overrideWith(
              (ref) => _StubSettingsNotifier(
                ref,
                const SettingsState(savingsTarget: 5000000),
              ),
            ),
            transactionsProvider.overrideWith(
              (ref) => _StubTransactionsNotifier(deficitTxs),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              appBar: NeoAppBar(title: 'Beranda'),
              body: SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();
      expect(find.text('PENGELUARAN MELEBIHI PEMASUKAN'), findsOneWidget);
    });

    testWidgets('TransactionFormDialog mempertahankan nama kategori lama yang sudah dihapus', (
      WidgetTester tester,
    ) async {
      final now = DateTime.now();
      final deletedCatTx = TransactionModel(
        id: 'tx_del_cat',
        userId: 'u1',
        type: 'expense',
        nominal: 75000,
        description: 'Beli buku lama',
        categoryId: 'cat_deleted_999',
        categoryName: 'Hobi Lama',
        transactionDate: now,
        createdAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  TransactionFormDialog.show(
                    context: context,
                    userId: 'u1',
                    categories: CategoryModel.defaultCategories,
                    editingTx: deletedCatTx,
                    onSave: (_) async {},
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Hobi Lama'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('AppUpdateInfo membandingkan versi, build number, dan forceUpdate dengan benar', () {
      const current = AppVersionInfo(versionName: '1.0.0', buildNumber: 1);

      expect(AppUpdateInfo.compareVersions('1.10.0', '1.2.0'), greaterThan(0));
      expect(AppUpdateInfo.compareVersions('v1.0.0', '1.0.0'), 0);

      const newerBuild = AppUpdateInfo(
        latestVersion: '1.1.0',
        latestBuildNumber: 2,
        minSupportedBuildNumber: 1,
        forceUpdate: false,
        releaseNotes: '- Fitur baru',
        downloadUrl: 'https://example.com/smartfi-v1.1.0.apk',
      );
      expect(newerBuild.isUpdateAvailable(current), isTrue);
      expect(newerBuild.isForceRequired(current), isFalse);

      const forcedByMinBuild = AppUpdateInfo(
        latestVersion: '1.2.0',
        latestBuildNumber: 3,
        minSupportedBuildNumber: 2,
        forceUpdate: false,
        downloadUrl: 'https://example.com/smartfi-v1.2.0.apk',
      );
      expect(forcedByMinBuild.isUpdateAvailable(current), isTrue);
      expect(forcedByMinBuild.isForceRequired(current), isTrue);

      const invalidUrl = AppUpdateInfo(
        latestVersion: '2.0.0',
        latestBuildNumber: 5,
        downloadUrl: 'bukan-url',
      );
      expect(invalidUrl.isUpdateAvailable(current), isFalse);
    });

    testWidgets('AppUpdateCard & UpdateDialog bebas overflow di layar 320px (Dark Mode)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const sampleUpdate = AppUpdateInfo(
        latestVersion: '1.2.0',
        latestBuildNumber: 2,
        minSupportedBuildNumber: 1,
        forceUpdate: false,
        releaseNotes: '- Tambah fitur update otomatis Firebase\n- Perbaikan stabilitas',
        downloadUrl: 'https://example.com/smartfi-v1.2.0.apk',
      );

      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('scope_update_ui'),
          overrides: [
            appUpdateProvider.overrideWith(
              (ref) => _StubAppUpdateNotifier(
                const AppUpdateState(
                  status: AppUpdateStatus.available,
                  currentVersion: AppVersionInfo(versionName: '1.0.0', buildNumber: 1),
                  updateInfo: sampleUpdate,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: NeoTheme.lightTheme,
            darkTheme: NeoTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(12),
                  child: AppUpdateCard(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PEMBARUAN APLIKASI'), findsOneWidget);
      expect(find.text('UPDATE SEKARANG'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('UPDATE SEKARANG'));
      await tester.pumpAndSettle();

      expect(find.text('PEMBARUAN TERSEDIA'), findsOneWidget);
      expect(find.text('v1.0.0 → v1.2.0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('HomeWidgetSummary menghitung saldo, arus kas bulan ini, target & status logout', () {
      final now = DateTime(2026, 11, 25);
      final txs = [
        TransactionModel(
          id: 'tx_prev',
          userId: 'u1',
          type: 'income',
          nominal: 2000000,
          description: 'Tabungan bulan lalu',
          categoryId: 'def-4',
          categoryName: 'Gaji',
          transactionDate: DateTime(2026, 10, 15),
          createdAt: DateTime(2026, 10, 15),
        ),
        TransactionModel(
          id: 'tx_now_inc',
          userId: 'u1',
          type: 'income',
          nominal: 5000000,
          description: 'Gaji November',
          categoryId: 'def-4',
          categoryName: 'Gaji',
          transactionDate: now,
          createdAt: now,
        ),
        TransactionModel(
          id: 'tx_now_exp',
          userId: 'u1',
          type: 'expense',
          nominal: 1500000,
          description: 'Pengeluaran November',
          categoryId: 'def-1',
          categoryName: 'Makanan',
          transactionDate: now,
          createdAt: now,
        ),
      ];

      final summary = HomeWidgetSummary.fromTransactions(
        transactions: txs,
        savingsTarget: 10000000,
        isLoggedIn: true,
        isDark: true,
        now: now,
      );
      // Saldo total = 2jt + 5jt - 1.5jt = 5.5jt -> 55% dari target 10jt
      expect(summary.isLoggedIn, isTrue);
      expect(summary.balanceText, 'Rp 5.500.000');
      expect(summary.incomeMonthText, 'Rp 5.000.000');
      expect(summary.expenseMonthText, 'Rp 1.500.000');
      expect(summary.targetPercent, 55);
      expect(summary.isDark, isTrue);

      final loggedOut = HomeWidgetSummary.fromTransactions(
        transactions: txs,
        savingsTarget: 10000000,
        isLoggedIn: false,
        isDark: false,
        now: now,
      );
      expect(loggedOut.isLoggedIn, isFalse);
      expect(loggedOut.targetPercent, 0);
      expect(loggedOut.incomeMonthText, '-');
    });
  });
}

class _StubAppUpdateNotifier extends AppUpdateNotifier {
  _StubAppUpdateNotifier(AppUpdateState initial)
      : super(AppUpdateService(), autoStart: false) {
    state = initial;
  }
}

class _StubSettingsNotifier extends SettingsNotifier {
  _StubSettingsNotifier(super.ref, SettingsState initial) {
    state = initial;
  }

  @override
  Future<void> loadSettings() async {}
}

class _StubTransactionsNotifier extends TransactionsNotifier {
  _StubTransactionsNotifier(List<TransactionModel> initial)
      : super(DummyTransactionRepository(), null) {
    state = AsyncValue.data(initial);
  }
}
