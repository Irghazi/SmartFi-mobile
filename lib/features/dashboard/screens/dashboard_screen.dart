import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/neo_colors.dart';
import '../../../data/models/transaction_model.dart';
import '../../../shared/widgets/blueprint_background.dart';
import '../../auth/providers/auth_provider.dart';
import '../../main/main_screen.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/expense_bar_chart.dart';
import '../widgets/initial_balance_dialog.dart';
import '../widgets/recent_transactions_list.dart';
import '../widgets/spending_anomaly_banner.dart';
import '../widgets/summary_cards.dart';
import '../widgets/widget_2x2.dart';
import '../../settings/providers/settings_provider.dart';

/// Layar utama Dashboard keuangan SmartFi
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _checkedUserId;

  Future<void> _checkInitialBalance(List<TransactionModel> transactions) async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    if (_checkedUserId == user.id) return;
    _checkedUserId = user.id;

    final prefs = await SharedPreferences.getInstance();
    final isCompleted = prefs.getBool('smartfi_onboarding_completed_${user.id}') ?? false;

    if (transactions.isEmpty && !isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          InitialBalanceDialog.show(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final dailyAnomaly = ref.watch(dailyAnomalyProvider);

    final textCol = NeoColors.text(context);
    final mutedCol = NeoColors.mutedText(context);

    return BlueprintBackground(
      child: RefreshIndicator(
        color: NeoColors.primaryBlue,
        backgroundColor: NeoColors.surface(context),
        onRefresh: () async {
          await ref.read(transactionsProvider.notifier).loadTransactions(showLoading: false);
        },
        child: transactionsAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.65,
                child: Center(
                  child: CircularProgressIndicator(color: textCol),
                ),
              ),
            ],
          ),
          error: (err, _) => ListView(
            padding: const EdgeInsets.all(24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
              Icon(Icons.cloud_off, size: 48, color: mutedCol),
              const SizedBox(height: 12),
              Text(
                'Gagal memuat data dashboard.\nTarik ke bawah atau tekan Coba Lagi.\n($err)',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, color: textCol),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.read(transactionsProvider.notifier).loadTransactions(),
                icon: const Icon(Icons.refresh),
                label: const Text('COBA LAGI'),
              ),
            ],
          ),
          data: (transactions) {
            _checkInitialBalance(transactions);

            // Perhitungan data keuangan
            final income = transactions
                .where((t) => t.isIncome)
                .fold<int>(0, (sum, t) => sum + t.nominal);
            final expense = transactions
                .where((t) => t.isExpense)
                .fold<int>(0, (sum, t) => sum + t.nominal);
            final balance = income - expense;

            final now = DateTime.now();
            final transactionsThisMonth = transactions
                .where((t) =>
                    t.transactionDate.month == now.month &&
                    t.transactionDate.year == now.year)
                .toList();

            final incomeThisMonth = transactionsThisMonth
                .where((t) => t.isIncome)
                .fold<int>(0, (sum, t) => sum + t.nominal);
            final expenseThisMonth = transactionsThisMonth
                .where((t) => t.isExpense)
                .fold<int>(0, (sum, t) => sum + t.nominal);

            return ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // Header Sambutan
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DASHBOARD UTAMA',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: textCol,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'RINGKASAN FINANSIAL ANDA',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: mutedCol,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: NeoColors.yellowAccent,
                        border: Border.all(color: NeoColors.black, width: 2),
                        boxShadow: NeoColors.hardShadow(offset: 2),
                      ),
                      child: const Text(
                        'AKTIF',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: NeoColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Banner Peringatan Anomali Pengeluaran Harian (jika terdeteksi)
                if (dailyAnomaly.isAnomaly) ...[
                  SpendingAnomalyBanner(
                    anomaly: dailyAnomaly,
                    onAskMentor: () {
                      ref.read(mainTabIndexProvider.notifier).state = 2;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // 3 Kartu Ringkasan (Saldo, Masuk, Keluar)
                DashboardSummaryCards(
                  balance: balance,
                  income: income,
                  expense: expense,
                ),
                const SizedBox(height: 20),

                // Widget 2x2 Doughnut Metrics
                Widget2x2(
                  balance: balance,
                  incomeThisMonth: incomeThisMonth,
                  expenseThisMonth: expenseThisMonth,
                  targetSavings: ref.watch(settingsProvider).savingsTarget,
                  transactionsThisMonth: transactionsThisMonth,
                ),
                const SizedBox(height: 20),

                // Grafik Batang Pengeluaran 7 Hari
                ExpenseBarChart(
                  transactions: transactions,
                ),
                const SizedBox(height: 20),

                // Diagram Pie Distribusi Kategori
                CategoryPieChart(
                  transactions: transactions,
                ),
                const SizedBox(height: 20),

                // 5 Transaksi Terbaru
                RecentTransactionsList(
                  transactions: transactions,
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}
