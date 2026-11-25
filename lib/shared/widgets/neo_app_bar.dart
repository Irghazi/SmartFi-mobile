import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/audio_service.dart';
import '../../core/theme/neo_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../../features/transactions/providers/transaction_provider.dart';
import 'neo_modal.dart';

class _NotificationItem {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String body;

  const _NotificationItem({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.body,
  });
}

class NeoAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final VoidCallback? onAvatarTap;

  const NeoAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.onAvatarTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64.0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);
    final user = userAsync.asData?.value;
    final settings = ref.watch(settingsProvider);
    final txs = ref.watch(transactionsProvider).asData?.value ?? [];

    final now = DateTime.now();
    final totalIncome =
        txs.where((t) => t.isIncome).fold<int>(0, (sum, t) => sum + t.nominal);
    final totalExpense =
        txs.where((t) => t.isExpense).fold<int>(0, (sum, t) => sum + t.nominal);
    final balance = totalIncome - totalExpense;
    final incomeThisMonth = txs
        .where((t) =>
            t.isIncome &&
            t.transactionDate.month == now.month &&
            t.transactionDate.year == now.year)
        .fold<int>(0, (sum, t) => sum + t.nominal);
    final expenseThisMonth = txs
        .where((t) =>
            t.isExpense &&
            t.transactionDate.month == now.month &&
            t.transactionDate.year == now.year)
        .fold<int>(0, (sum, t) => sum + t.nominal);

    final notifications = <_NotificationItem>[];
    var hasAlert = false;

    if (txs.isNotEmpty && balance <= 0) {
      hasAlert = true;
      notifications.add(_NotificationItem(
        icon: Icons.warning_amber_rounded,
        accentColor: NeoColors.dangerRedLight,
        title: 'Peringatan Saldo Menipis',
        body:
            'Saldo aktif saat ini ${CurrencyFormatter.formatRupiah(balance)}. Periksa kembali pengeluaran Anda.',
      ));
    }

    if (incomeThisMonth > 0 && expenseThisMonth > incomeThisMonth) {
      hasAlert = true;
      notifications.add(_NotificationItem(
        icon: Icons.trending_up,
        accentColor: NeoColors.dangerRedLight,
        title: 'Pengeluaran Melebihi Pemasukan',
        body:
            'Pengeluaran bulan ini (${CurrencyFormatter.formatRupiah(expenseThisMonth)}) melampaui pemasukan (${CurrencyFormatter.formatRupiah(incomeThisMonth)}).',
      ));
    } else if (settings.savingsTarget > 0 &&
        incomeThisMonth > 0 &&
        (incomeThisMonth - expenseThisMonth) < settings.savingsTarget) {
      hasAlert = true;
      final monthlySavings = incomeThisMonth - expenseThisMonth;
      notifications.add(_NotificationItem(
        icon: Icons.savings_outlined,
        accentColor: NeoColors.yellowAccent,
        title: 'Di Bawah Target Tabungan',
        body:
            'Sisa arus kas bulan ini (${CurrencyFormatter.formatRupiah(monthlySavings)}) masih di bawah target tabungan (${CurrencyFormatter.formatRupiah(settings.savingsTarget)}).',
      ));
    }

    if (settings.isReminderActive) {
      notifications.add(_NotificationItem(
        icon: Icons.notifications_active,
        accentColor: NeoColors.primaryBlueLight,
        title: 'Pengingat Harian Aktif',
        body:
            'Anda akan diingatkan setiap hari pukul ${settings.reminderTime} untuk mencatat transaksi.',
      ));
    }

    String initials = 'US';
    if (user != null && user.name.trim().isNotEmpty) {
      final parts =
          user.name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty) {
        initials = parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
      }
    }

    final borderCol = NeoColors.border(context);
    final textCol = NeoColors.text(context);

    return Container(
      decoration: BoxDecoration(
        color: NeoColors.surface(context),
        border: Border(
          bottom: BorderSide(color: borderCol, width: 4.0),
        ),
        boxShadow: const [
          BoxShadow(
            color: NeoColors.black,
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: textCol,
                    fontWeight: FontWeight.w900,
                    fontSize: 18.0,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (actions != null) ...actions!,

              // Tombol Notifikasi (Lonceng Neobrutalism)
              GestureDetector(
                onTap: () {
                  AudioService().playClickSound();
                  NeoModal.show(
                    context: context,
                    title: 'Pemberitahuan',
                    child: notifications.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.notifications_none,
                                  size: 36,
                                  color: NeoColors.mutedText(context),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Semua aman! Belum ada pemberitahuan baru saat ini.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: textCol,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Anda dapat mengaktifkan pengingat catat transaksi harian di menu Pengaturan.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: NeoColors.mutedText(context),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: notifications.map((item) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: item.accentColor,
                                  border: Border.all(color: NeoColors.black, width: 2),
                                  boxShadow: NeoColors.hardShadow(offset: 2),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(item.icon, size: 20, color: NeoColors.black),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title.toUpperCase(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12,
                                              color: NeoColors.textDark,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.body,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                              color: NeoColors.textDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  );
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: NeoColors.yellowAccent,
                    border: Border.all(color: NeoColors.black, width: 2.0),
                    boxShadow: NeoColors.hardShadow(offset: 2.0),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.notifications_outlined, size: 22, color: NeoColors.black),
                      if (hasAlert)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: NeoColors.dangerRed,
                              border: Border.all(color: NeoColors.black, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Avatar Pengguna
              GestureDetector(
                onTap: () {
                  AudioService().playClickSound();
                  onAvatarTap?.call();
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: NeoColors.primaryBlueLight,
                    border: Border.all(color: NeoColors.black, width: 2.0),
                    boxShadow: NeoColors.hardShadow(offset: 2.0),
                  ),
                  child: user?.avatarUrl != null && user!.avatarUrl!.trim().isNotEmpty
                      ? Image.network(
                          user.avatarUrl!.trim(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                color: NeoColors.textDark,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: NeoColors.textDark,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

