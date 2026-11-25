import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsState {
  final int savingsTarget;
  final String themeMode; // 'light' | 'dark'
  final bool isClickMuted;
  final bool isAiMuted;
  final bool isReminderActive;
  final String reminderTime;

  const SettingsState({
    this.savingsTarget = 5000000,
    this.themeMode = 'light',
    this.isClickMuted = false,
    this.isAiMuted = false,
    this.isReminderActive = false,
    this.reminderTime = '08:00',
  });

  SettingsState copyWith({
    int? savingsTarget,
    String? themeMode,
    bool? isClickMuted,
    bool? isAiMuted,
    bool? isReminderActive,
    String? reminderTime,
  }) {
    return SettingsState(
      savingsTarget: savingsTarget ?? this.savingsTarget,
      themeMode: themeMode ?? this.themeMode,
      isClickMuted: isClickMuted ?? this.isClickMuted,
      isAiMuted: isAiMuted ?? this.isAiMuted,
      isReminderActive: isReminderActive ?? this.isReminderActive,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final Ref _ref;
  String? _activeUserId;

  SettingsNotifier(this._ref) : super(const SettingsState()) {
    _init();
  }

  String _targetKey(String uid) => 'smartfi_savings_target_$uid';
  String _reminderActiveKey(String uid) => 'smartfi_reminder_active_$uid';
  String _reminderTimeKey(String uid) => 'smartfi_reminder_time_$uid';

  void _init() {
    loadSettings();
    _ref.listen<AppUser?>(
      authStateProvider.select((s) => s.asData?.value),
      (prev, next) {
        _syncFromUser(next);
      },
    );
  }

  Future<void> _syncFromUser(AppUser? user) async {
    if (user == null) {
      _activeUserId = null;
      if (mounted) {
        state = state.copyWith(
          savingsTarget: 5000000,
          isReminderActive: false,
          reminderTime: '08:00',
        );
      }
      await NotificationService().scheduleDailyReminder(
        isEnabled: false,
        timeStr: '08:00',
      );
      return;
    }

    _activeUserId = user.id;
    final target = user.targetSavings > 0 ? user.targetSavings : 5000000;
    final reminderActive = user.reminderEnabled;
    final reminderTime = user.reminderTime.isNotEmpty ? user.reminderTime : '08:00';

    if (mounted) {
      state = state.copyWith(
        savingsTarget: target,
        isReminderActive: reminderActive,
        reminderTime: reminderTime,
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_targetKey(user.id), target);
      await prefs.setBool(_reminderActiveKey(user.id), reminderActive);
      await prefs.setString(_reminderTimeKey(user.id), reminderTime);
    } catch (_) {}

    await NotificationService().scheduleDailyReminder(
      isEnabled: reminderActive,
      timeStr: reminderTime,
    );
  }

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final theme = prefs.getString('smartfi_theme_mode') ?? 'light';
      final clickMuted = prefs.getBool('smartfi_mute_click') ?? false;
      final aiMuted = prefs.getBool('smartfi_mute_ai') ?? false;

      final currentUser = _ref.read(authStateProvider).asData?.value;
      if (currentUser != null) {
        _activeUserId = currentUser.id;
        final target = currentUser.targetSavings > 0
            ? currentUser.targetSavings
            : (prefs.getInt(_targetKey(currentUser.id)) ?? 5000000);
        final reminderActive = currentUser.reminderEnabled;
        final reminderTime = currentUser.reminderTime.isNotEmpty
            ? currentUser.reminderTime
            : (prefs.getString(_reminderTimeKey(currentUser.id)) ?? '08:00');

        if (!mounted) return;
        state = SettingsState(
          savingsTarget: target,
          themeMode: theme,
          isClickMuted: clickMuted,
          isAiMuted: aiMuted,
          isReminderActive: reminderActive,
          reminderTime: reminderTime,
        );

        await NotificationService().scheduleDailyReminder(
          isEnabled: reminderActive,
          timeStr: reminderTime,
        );
      } else {
        if (!mounted) return;
        state = SettingsState(
          themeMode: theme,
          isClickMuted: clickMuted,
          isAiMuted: aiMuted,
        );
      }
    } catch (_) {}
  }

  Future<void> setSavingsTarget(int target) async {
    state = state.copyWith(savingsTarget: target);
    final uid = _activeUserId ?? _ref.read(authStateProvider).asData?.value?.id;
    if (uid != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_targetKey(uid), target);
      await _ref.read(authRepositoryProvider).updateProfile(targetSavings: target);
    }
  }

  Future<void> setThemeMode(String mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('smartfi_theme_mode', mode);
  }

  Future<void> toggleClickMute() async {
    final newVal = !state.isClickMuted;
    state = state.copyWith(isClickMuted: newVal);
    await AudioService().setClickMuted(newVal);
  }

  Future<void> toggleAiMute() async {
    final newVal = !state.isAiMuted;
    state = state.copyWith(isAiMuted: newVal);
    await AudioService().setAiMuted(newVal);
  }

  Future<void> setReminder({required bool isActive, required String time}) async {
    state = state.copyWith(isReminderActive: isActive, reminderTime: time);
    final uid = _activeUserId ?? _ref.read(authStateProvider).asData?.value?.id;
    if (uid != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_reminderActiveKey(uid), isActive);
      await prefs.setString(_reminderTimeKey(uid), time);
      await _ref.read(authRepositoryProvider).updateProfile(
            reminderEnabled: isActive,
            reminderTime: time,
          );
    }
    await NotificationService().scheduleDailyReminder(
      isEnabled: isActive,
      timeStr: time,
    );
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});

