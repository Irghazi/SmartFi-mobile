import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/ai_config.dart';
import '../../../core/services/spending_anomaly_detector.dart';
import '../../../data/repositories/ai_repository.dart';
import '../../../data/repositories/dummy/dummy_ai_repository.dart';
import '../../../data/repositories/openai/openai_ai_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../models/chat_message.dart';

/// Provider sakelar tunggal untuk berpindah antara AI dummy dan API OpenAI sungguhan
final useRealAiApiProvider = StateProvider<bool>((ref) {
  // Aktif otomatis jika API key tersedia di env.json
  return AiConfig.hasApiKey;
});

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  final useReal = ref.watch(useRealAiApiProvider);
  if (useReal && AiConfig.hasApiKey) {
    return OpenAiAiRepository();
  }
  return DummyAiRepository();
});

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? errorMessage;

  const ChatState({
    required this.messages,
    this.isLoading = false,
    this.errorMessage,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final AiRepository _aiRepository;
  final Ref _ref;
  final String _userId;
  int _msgSeq = 0;

  String get _storageKey => 'smartfi_ai_chat_history_$_userId';

  static List<ChatMessage> _createInitialGreeting() => [
        ChatMessage(
          id: 'msg_greet',
          role: 'ai',
          content:
              'Halo! Saya SmartFi, Mentor Keuangan Pribadimu. Apa yang ingin kamu ketahui? Kamu bisa bertanya tentang pengeluaran terbesar, saran hemat, atau ringkasan bulan ini.',
          createdAt: DateTime.now(),
        ),
      ];

  ChatNotifier(this._aiRepository, this._ref, this._userId)
      : super(ChatState(messages: _createInitialGreeting())) {
    loadChatHistory();
  }

  String _nextId([String prefix = 'msg']) {
    _msgSeq++;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_msgSeq';
  }

  Future<void> loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString(_storageKey);
      if (savedStr != null && savedStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(savedStr);
        final loaded = list
            .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
            .where((m) => !m.isError)
            .toList();
        if (loaded.isNotEmpty && mounted) {
          state = state.copyWith(messages: loaded);
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      state = state.copyWith(messages: _createInitialGreeting());
    }
  }

  Future<void> _saveHistory(List<ChatMessage> list) async {
    final prefs = await SharedPreferences.getInstance();
    // Jangan simpan pesan error sementara ke riwayat permanen
    final persistable = list.where((m) => !m.isError).toList();
    final jsonList = persistable.map((m) => m.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  Future<String> _buildFinancialContext() async {
    var txsAsync = _ref.read(transactionsProvider);
    var txs = txsAsync.asData?.value ?? [];

    if (txsAsync.isLoading && _userId != 'guest') {
      try {
        txs = await _ref
            .read(transactionRepositoryProvider)
            .getTransactions(_userId)
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    }

    final now = DateTime.now();
    final monthTxs = txs.where(
      (t) => t.transactionDate.month == now.month && t.transactionDate.year == now.year,
    );

    final income = txs.where((t) => t.isIncome).fold<int>(0, (sum, t) => sum + t.nominal);
    final expense = txs.where((t) => t.isExpense).fold<int>(0, (sum, t) => sum + t.nominal);
    final balance = income - expense;

    final incomeMonth = monthTxs.where((t) => t.isIncome).fold<int>(0, (sum, t) => sum + t.nominal);
    final expenseMonth = monthTxs.where((t) => t.isExpense).fold<int>(0, (sum, t) => sum + t.nominal);
    final settings = _ref.read(settingsProvider);
    final targetSavings = settings.savingsTarget;
    final anomaly = SpendingAnomalyDetector.detect(
      transactions: txs,
      dailyLimit: settings.dailySpendingLimit,
      now: now,
    );

    // Hitung kategori terbesar
    final catTotals = <String, int>{};
    for (final t in txs.where((t) => t.isExpense)) {
      catTotals[t.categoryName] = (catTotals[t.categoryName] ?? 0) + t.nominal;
    }

    String topCategory = 'Belum Ada';
    int topAmount = 0;
    catTotals.forEach((cat, amt) {
      if (amt > topAmount) {
        topAmount = amt;
        topCategory = cat;
      }
    });

    final recent15 = txs
        .take(15)
        .map((t) => {
              'tipe': t.type,
              'kategori': t.categoryName,
              'nominal': t.nominal,
              'deskripsi': t.description,
              'tanggal': t.transactionDate.toIso8601String().split('T').first,
            })
        .toList();

    return jsonEncode({
      'saldo_terkini': balance,
      'total_pemasukan': income,
      'total_pengeluaran': expense,
      'pemasukan_bulan_ini': incomeMonth,
      'pengeluaran_bulan_ini': expenseMonth,
      'pengeluaran_hari_ini': anomaly.todayExpense,
      'rata_rata_pengeluaran_harian': anomaly.baselineDailyAverage,
      'batas_pengeluaran_harian_kustom': settings.dailySpendingLimit,
      'status_anomali_hari_ini': {
        'is_anomali': anomaly.isAnomaly,
        'tingkat': anomaly.severity.name,
        'kategori_terbesar_hari_ini': anomaly.topCategoryToday,
        'nominal_kategori_terbesar_hari_ini': anomaly.topCategoryAmountToday,
        'pesan': anomaly.message,
      },
      'target_tabungan_bulanan': targetSavings,
      'kategori_terbesar': topCategory,
      'nominal_kategori_terbesar': topAmount,
      'transaksi_terbaru': recent15,
    });
  }

  String _cleanErrorText(Object e) {
    return e
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('HttpException: ', '')
        .replaceFirst('SocketException: ', '')
        .trim();
  }

  Future<String> _askOnlineWithTimeout({
    required String message,
    required List<ChatMessage> history,
    required String financialContextJson,
  }) async {
    return _aiRepository
        .askMentor(
          message: message,
          history: history,
          financialContextJson: financialContextJson,
        )
        .timeout(
          const Duration(seconds: 38),
          onTimeout: () => throw TimeoutException(
            'Permintaan ke server AI melebihi batas waktu. Periksa koneksi internetmu lalu ketuk Coba Lagi.',
          ),
        );
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isLoading) return;

    // Bersihkan error bubble sebelumnya sebelum mengirim pesan baru
    final baseHistory = state.messages.where((m) => !m.isError).toList();

    final userMsg = ChatMessage(
      id: _nextId(),
      role: 'user',
      content: trimmed,
      createdAt: DateTime.now(),
    );

    final currentMessages = [...baseHistory, userMsg];
    state = state.copyWith(
      messages: currentMessages,
      isLoading: true,
      errorMessage: null,
    );
    await _saveHistory(currentMessages);

    try {
      final contextJson = await _buildFinancialContext();
      final reply = await _askOnlineWithTimeout(
        message: trimmed,
        history: currentMessages,
        financialContextJson: contextJson,
      );

      final aiMsg = ChatMessage(
        id: _nextId(),
        role: 'ai',
        content: reply,
        createdAt: DateTime.now(),
      );

      final updated = [...currentMessages, aiMsg];
      if (mounted) {
        state = state.copyWith(messages: updated, isLoading: false);
      }
      await _saveHistory(updated);
    } catch (e) {
      final friendlyError = _cleanErrorText(e);
      final aiErrorMsg = ChatMessage(
        id: _nextId('msg_err'),
        role: 'ai',
        content: friendlyError.isNotEmpty
            ? friendlyError
            : 'Terjadi kesalahan saat menghubungi server AI. Mohon coba sesaat lagi.',
        createdAt: DateTime.now(),
        isError: true,
      );
      final updated = [...currentMessages, aiErrorMsg];
      if (mounted) {
        state = state.copyWith(
          messages: updated,
          isLoading: false,
          errorMessage: friendlyError,
        );
      }
    }
  }

  Future<void> regenerateLastResponse() async {
    if (state.isLoading || state.messages.isEmpty) return;

    int lastUserIndex = -1;
    for (int i = state.messages.length - 1; i >= 0; i--) {
      if (state.messages[i].isUser) {
        lastUserIndex = i;
        break;
      }
    }

    if (lastUserIndex == -1) return;

    final userMsgText = state.messages[lastUserIndex].content;
    final truncatedList = state.messages
        .sublist(0, lastUserIndex + 1)
        .where((m) => !m.isError)
        .toList();

    state = state.copyWith(messages: truncatedList, isLoading: true, errorMessage: null);

    try {
      final contextJson = await _buildFinancialContext();
      final reply = await _askOnlineWithTimeout(
        message: userMsgText,
        history: truncatedList,
        financialContextJson: contextJson,
      );

      final aiMsg = ChatMessage(
        id: _nextId(),
        role: 'ai',
        content: reply,
        createdAt: DateTime.now(),
      );

      final updated = [...truncatedList, aiMsg];
      if (mounted) {
        state = state.copyWith(messages: updated, isLoading: false);
      }
      await _saveHistory(updated);
    } catch (e) {
      final friendlyError = _cleanErrorText(e);
      final aiErrorMsg = ChatMessage(
        id: _nextId('msg_err'),
        role: 'ai',
        content: friendlyError.isNotEmpty
            ? friendlyError
            : 'Terjadi kesalahan saat menghubungi server AI. Mohon coba sesaat lagi.',
        createdAt: DateTime.now(),
        isError: true,
      );
      final updated = [...truncatedList, aiErrorMsg];
      if (mounted) {
        state = state.copyWith(
          messages: updated,
          isLoading: false,
          errorMessage: friendlyError,
        );
      }
    }
  }

  Future<void> clearHistory() async {
    state = ChatState(messages: _createInitialGreeting());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final repo = ref.watch(aiRepositoryProvider);
  final userId = ref.watch(authStateProvider.select((s) => s.asData?.value?.id)) ?? 'guest';
  return ChatNotifier(repo, ref, userId);
});

