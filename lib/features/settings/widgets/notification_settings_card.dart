import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/neo_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/neo_button.dart';
import '../../../shared/widgets/neo_card.dart';
import '../../../shared/widgets/neo_input.dart';
import '../providers/settings_provider.dart';

/// Kartu pengaturan pengingat harian & deteksi anomali pengeluaran harian
class NotificationSettingsCard extends ConsumerStatefulWidget {
  const NotificationSettingsCard({super.key});

  @override
  ConsumerState<NotificationSettingsCard> createState() =>
      _NotificationSettingsCardState();
}

class _NotificationSettingsCardState
    extends ConsumerState<NotificationSettingsCard> {
  final TextEditingController _dailyLimitController = TextEditingController();
  bool _isActive = false;
  String _timeStr = '08:00';
  bool _isAnomalyEnabled = true;
  int _rawDailyLimit = 0;
  bool _isInit = false;
  bool _isLoading = false;
  bool _hasEdited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final s = ref.read(settingsProvider);
      _isActive = s.isReminderActive;
      _timeStr = s.reminderTime;
      _isAnomalyEnabled = s.isAnomalyAlertEnabled;
      _rawDailyLimit = s.dailySpendingLimit;
      _dailyLimitController.text = _rawDailyLimit > 0
          ? CurrencyFormatter.formatRupiah(_rawDailyLimit)
          : '';
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _dailyLimitController.dispose();
    super.dispose();
  }

  void _onDailyLimitChanged(String val) {
    _hasEdited = true;
    final clean = val.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) {
      _rawDailyLimit = 0;
      _dailyLimitController.value = const TextEditingValue(text: '');
      return;
    }
    final parsed = int.tryParse(clean) ?? 0;
    _rawDailyLimit = parsed;
    final formatted = CurrencyFormatter.formatRupiah(parsed);
    _dailyLimitController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _selectTime() async {
    AudioService().playClickSound();
    final parts = _timeStr.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 8,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );

    final isDark = NeoColors.isDark(context);

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: NeoColors.primaryBlue,
                    onPrimary: NeoColors.white,
                    surface: NeoColors.surfaceDark,
                    onSurface: NeoColors.textLight,
                  )
                : const ColorScheme.light(
                    primary: NeoColors.primaryBlue,
                    onPrimary: NeoColors.white,
                    surface: NeoColors.surfaceLight,
                    onSurface: NeoColors.black,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final min = picked.minute.toString().padLeft(2, '0');
      setState(() {
        _hasEdited = true;
        _timeStr = '$hour:$min';
      });
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(settingsProvider.notifier).setReminder(
            isActive: _isActive,
            time: _timeStr,
            isAnomalyAlertEnabled: _isAnomalyEnabled,
            dailySpendingLimit: _rawDailyLimit,
          );
      _hasEdited = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengaturan pengingat & deteksi anomali diperbarui!'),
            backgroundColor: NeoColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal memperbarui pengingat: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: NeoColors.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleTestNotification() async {
    await NotificationService().showTestNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notifikasi uji coba dikirim! Periksa bilah status HP Anda.'),
          backgroundColor: NeoColors.primaryBlue,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider, (_, next) {
      if (!_hasEdited) {
        setState(() {
          _isActive = next.isReminderActive;
          _timeStr = next.reminderTime;
          _isAnomalyEnabled = next.isAnomalyAlertEnabled;
          _rawDailyLimit = next.dailySpendingLimit;
          _dailyLimitController.text = _rawDailyLimit > 0
              ? CurrencyFormatter.formatRupiah(_rawDailyLimit)
              : '';
        });
      }
    });

    final textCol = NeoColors.text(context);
    final mutedCol = NeoColors.mutedText(context);
    final borderCol = NeoColors.border(context);
    final secondaryCol = NeoColors.surfaceSecondary(context);

    return NeoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: NeoColors.headerBg(context),
                  border: Border.all(color: borderCol, width: 2),
                  boxShadow: NeoColors.hardShadow(offset: 2),
                ),
                child: Icon(Icons.notifications_active, color: textCol, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PENGINGAT & ANOMALI',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'PENGINGAT HARIAN & DETEKSI BOROS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: mutedCol,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Switch Aktifkan Pengingat Harian
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: secondaryCol,
              border: Border.all(color: borderCol, width: 2),
              boxShadow: NeoColors.hardShadow(offset: 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PENGINGAT CATAT HARIAN',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Ingatkan catat uang tiap hari',
                        style: TextStyle(fontSize: 9, color: mutedCol),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _isActive,
                  activeTrackColor: NeoColors.primaryBlueLight,
                  activeThumbColor: NeoColors.primaryBlue,
                  onChanged: (val) {
                    AudioService().playClickSound();
                    setState(() {
                      _hasEdited = true;
                      _isActive = val;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Pemilih Jam Pengingat
          InkWell(
            onTap: _isActive ? _selectTime : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: _isActive ? secondaryCol : NeoColors.disabledSurface(context),
                border: Border.all(color: borderCol, width: 2),
                boxShadow: NeoColors.hardShadow(offset: _isActive ? 2 : 0),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'WAKTU PENGINGAT (SETIAP HARI)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: _isActive ? textCol : mutedCol,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: _isActive ? textCol : mutedCol,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _timeStr,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: _isActive ? textCol : mutedCol,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Switch Deteksi Anomali Pengeluaran Harian
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: secondaryCol,
              border: Border.all(color: borderCol, width: 2),
              boxShadow: NeoColors.hardShadow(offset: 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DETEKSI ANOMALI HARIAN',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Peringatan jika pengeluaran hari ini melonjak',
                        style: TextStyle(fontSize: 9, color: mutedCol),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _isAnomalyEnabled,
                  activeTrackColor: NeoColors.yellowAccent,
                  activeThumbColor: NeoColors.warningYellow,
                  onChanged: (val) {
                    AudioService().playClickSound();
                    setState(() {
                      _hasEdited = true;
                      _isAnomalyEnabled = val;
                    });
                  },
                ),
              ],
            ),
          ),

          if (_isAnomalyEnabled) ...[
            const SizedBox(height: 10),
            NeoInput(
              label: 'Batas Harian Kustom (Opsional)',
              controller: _dailyLimitController,
              hintText: 'Kosong = otomatis (>= 2x rata-rata)',
              keyboardType: TextInputType.number,
              onChanged: _onDailyLimitChanged,
            ),
          ],
          const SizedBox(height: 16),

          NeoButton(
            text: _isLoading ? 'MENYIMPAN...' : 'SIMPAN PENGATURAN',
            backgroundColor: NeoColors.primaryBlue,
            textColor: NeoColors.white,
            onPressed: _isLoading ? null : _handleSave,
          ),
          const SizedBox(height: 10),
          NeoButton(
            text: 'UJI NOTIFIKASI',
            variant: NeoButtonVariant.outline,
            icon: Icon(Icons.notifications_none, size: 18, color: textCol),
            onPressed: _handleTestNotification,
          ),
        ],
      ),
    );
  }
}
