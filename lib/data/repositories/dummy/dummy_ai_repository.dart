import 'dart:convert';
import '../../../core/services/ai_topic_guard.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/category_model.dart';
import '../../../features/ai_advisor/models/chat_message.dart';
import '../../../features/transactions/services/smart_input_parser.dart';
import '../ai_repository.dart';

class DummyAiRepository implements AiRepository {
  @override
  Future<String> askMentor({
    required String message,
    required List<ChatMessage> history,
    required String financialContextJson,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    // 1. Pre-filter ketat (kode pemrograman, prompt injection, topik luar keuangan)
    final refusal = AiTopicGuard.validateUserInput(message);
    if (refusal != null) {
      return refusal;
    }

    // 2. Sapaan ramah tanpa membocorkan data keuangan
    if (AiTopicGuard.isGreeting(message)) {
      return 'Halo! Aku SmartFi, mentor keuangan pribadimu. Ada yang ingin kamu diskusikan tentang anggaran, saldo, atau pengeluaranmu hari ini?';
    }

    // 3. Tolak pertanyaan non-keuangan di mode offline agar tidak membalas analisis yang tidak nyambung
    if (!AiTopicGuard.isLikelyFinanceOrAppTopic(message)) {
      return AiTopicGuard.offTopicRefusalMessage;
    }

    final lower = message.toLowerCase();

    // Parse financial context
    int saldo = 0;
    int totalIncome = 0;
    int totalExpense = 0;
    int todayExpense = 0;
    int dailyAverage = 0;
    bool isAnomaly = false;
    String anomalyMessage = '';
    String topCategory = 'Makanan';
    int topCategoryAmount = 0;

    try {
      final contextData = jsonDecode(financialContextJson) as Map<String, dynamic>;
      saldo = (contextData['saldo_terkini'] as num?)?.toInt() ?? 0;
      totalIncome = (contextData['total_pemasukan'] as num?)?.toInt() ?? 0;
      totalExpense = (contextData['total_pengeluaran'] as num?)?.toInt() ?? 0;
      todayExpense = (contextData['pengeluaran_hari_ini'] as num?)?.toInt() ?? 0;
      dailyAverage = (contextData['rata_rata_pengeluaran_harian'] as num?)?.toInt() ?? 0;
      topCategory = contextData['kategori_terbesar'] as String? ?? 'Makanan';
      topCategoryAmount = (contextData['nominal_kategori_terbesar'] as num?)?.toInt() ?? 0;
      final anomalyObj = contextData['status_anomali_hari_ini'];
      if (anomalyObj is Map<String, dynamic>) {
        isAnomaly = anomalyObj['is_anomali'] == true;
        anomalyMessage = anomalyObj['pesan'] as String? ?? '';
      }
    } catch (_) {}

    final formattedSaldo = CurrencyFormatter.formatRupiah(saldo);
    final formattedIncome = CurrencyFormatter.formatRupiah(totalIncome);
    final formattedExpense = CurrencyFormatter.formatRupiah(totalExpense);
    final formattedTodayExpense = CurrencyFormatter.formatRupiah(todayExpense);
    final formattedDailyAvg = CurrencyFormatter.formatRupiah(dailyAverage);
    final formattedTopCatAmount = CurrencyFormatter.formatRupiah(topCategoryAmount);

    if (lower.contains('anomali') || lower.contains('hari ini') || lower.contains('boros')) {
      if (isAnomaly) {
        return '''
### Evaluasi Pengeluaran Hari Ini
$anomalyMessage

### Langkah Cepat Agar Tetap Aman
1. Tahan pengeluaran non-esensial selama 1 sampai 2 hari ke depan untuk menyeimbangkan anggaran mingguanmu.
2. Cek kembali kategori terbesar hari ini dan pisahkan mana kebutuhan wajib dan mana pengeluaran impulsif.
3. Aktifkan batas pengeluaran harian di menu Pengaturan agar kamu langsung mendapat peringatan sebelum melebihi anggaran.
''';
      }
      return '''
Pengeluaranmu hari ini tercatat sebesar **$formattedTodayExpense**${dailyAverage > 0 ? ' (rata-rata harianmu **$formattedDailyAvg**)' : ''}. Belum ada lonjakan anomali yang terdeteksi hari ini. Pertahankan disiplin pencatatanmu ya!
''';
    }

    if (lower.contains('terbesar') || lower.contains('pengeluaran terbesar') || lower.contains('terbanyak')) {
      return '''
Berdasarkan catatan keuanganmu, pengeluaran terbesarmu saat ini ada di kategori **$topCategory** sebesar **$formattedTopCatAmount**.

Saran dariku, coba tinjau kembali pos ini dan tetapkan batas mingguan agar sisa anggaranmu tetap aman hingga akhir bulan.
''';
    }

    if (lower.contains('hemat') || lower.contains('saran hemat') || lower.contains('tips')) {
      return '''
Berikut 3 saran hemat yang bisa kamu terapkan:

1. Buat daftar belanja sebelum bepergian untuk mencegah pengeluaran impulsif di luar kebutuhan pokok.
2. Kurangi pengeluaran pada kategori **$topCategory**, alokasikan batas harian yang realistis sesuai anggaranmu.
3. Sisihkan minimal 10% dari setiap pemasukan langsung ke rekening tabungan di awal bulan.
''';
    }

    return '''
### Analisis Singkat
Saat ini saldo aktifmu berada di angka **$formattedSaldo** (Pemasukan: **$formattedIncome**, Pengeluaran: **$formattedExpense**). Pengeluaran terbesarmu tercatat pada kategori **$topCategory** dengan total **$formattedTopCatAmount**.

### 3 Saran Praktis untuk Kamu
1. Batasi transaksi konsumtif pada kategori **$topCategory** agar rasio tabunganmu meningkat.
2. Catat segera setiap transaksi kecil di bawah **Rp 20.000** karena sering kali tidak terasa menumpuk.
3. Tetapkan target tabungan bulanan dan batas harian di Pengaturan agar progress finansialmu selalu terpantau.

### Prediksi Saldo Akhir Bulan
Dengan pola pengeluaran saat ini, arus kasmu diproyeksikan tetap stabil hingga akhir bulan jika kamu menjaga pengeluaran tambahan tetap terkendali.
''';
  }

  @override
  Future<Map<String, dynamic>> parseSmartInput({
    required String prompt,
    required List<String> categories,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final catModels = categories
        .map((c) => CategoryModel(
              id: c,
              userId: '',
              name: c,
              type: c.toLowerCase().contains('gaji') ? 'income' : 'expense',
              createdAt: DateTime.now(),
            ))
        .toList();

    final result = SmartInputParser.parse(prompt, catModels);
    return {
      'type': result.type,
      'category': result.category,
      'nominal': result.nominal,
      'description': result.description,
    };
  }
}
