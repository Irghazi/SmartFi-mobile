/// Guardrail topik & konteks untuk Mentor AI SmartFi (berlaku untuk Real AI & Mode Offline).
/// Lapisan 1: Pre-filter input (tolak kode/pemrograman, prompt injection, dan topik non-keuangan).
/// Lapisan 3: Post-filter output (cegah kebocoran blok kode dari LLM + bersihkan emoji).
class AiTopicGuard {
  AiTopicGuard._();

  static const String codeRefusalMessage =
      'Maaf ya, aku SmartFi, mentor keuangan pribadimu. Aku tidak bisa membuat kode pemrograman, script, atau program seperti kalkulator. Aku khusus membantu analisis saldo, pengeluaran, anggaran, dan target tabunganmu di SmartFi. Ada hal keuangan yang ingin kamu diskusikan?';

  static const String injectionRefusalMessage =
      'Maaf ya, aku tetap berperan sebagai SmartFi, mentor keuangan pribadimu, dan tidak bisa mengubah aturan atau topik di luar keuangan. Yuk, tanyakan seputar saldo, pengeluaran, anggaran, atau saran hemat!';

  static const String offTopicRefusalMessage =
      'Maaf ya, topik tersebut di luar cakupan SmartFi. Aku khusus dirancang untuk mendampingi urusan keuangan pribadimu, seperti analisis saldo, pengeluaran harian, anggaran, investasi dasar, dan target menabung. Ada yang ingin kamu tanyakan soal keuanganmu?';

  static final List<RegExp> _injectionPatterns = [
    RegExp(r'\b(abaikan|lupakan|hiraukan|hapus)\s+(semua\s+)?(instruksi|aturan|perintah|prompt)\b', caseSensitive: false),
    RegExp(r'\b(ignore|forget|disregard|override)\s+(all\s+)?(previous|prior|above|system)\s+(instructions|rules|prompts?)\b', caseSensitive: false),
    RegExp(r'\b(act\s+as|pretend\s+to\s+be|you\s+are\s+now|berperan\s+sebagai|anggap\s+dirimu|ubah\s+peran)\b', caseSensitive: false),
    RegExp(r'\b(jailbreak|developer\s+mode|dan\s+mode|bypass\s+aturan|system\s+prompt|bocorkan\s+prompt|tampilkan\s+prompt)\b', caseSensitive: false),
  ];

  static final List<RegExp> _codeKeywordPatterns = [
    RegExp(r'\b(coding|koding|ngoding|pemrograman|programming|source\s*code|pseudocode)\b', caseSensitive: false),
    RegExp(r'\b(python|javascript|typescript|golang|kotlin|csharp|flutter|reactjs|nextjs|nodejs|laravel|django|html|css|sql|php|cpp|c\+\+)\b', caseSensitive: false),
    RegExp(r'\b(kode\s+program|kode\s+sumber|kode\s+kalkulator|program\s+kalkulator|aplikasi\s+kalkulator|script|skrip|snippet|compiler|debugging)\b', caseSensitive: false),
    RegExp(
      r'\b(buat|buatkan|bikin|bikinkan|tulis|tuliskan|kasih|berikan|contoh)\b.{0,30}\b(kode|code|kalkulator|program|aplikasi|website|web|script|skrip|fungsi|function|class|algoritma)\b',
      caseSensitive: false,
    ),
  ];

  static final List<RegExp> _explicitOffTopicPatterns = [
    RegExp(r'\b(resep\s+(masak\w*|makan\w*|kue|minuman|nasi|ayam|soto|bakso)|cara\s+memasak|masak\s+nasi)\b', caseSensitive: false),
    RegExp(r'\b(puisi|pantun|cerpen|dongeng|novel|lirik\s+lagu|chord\s+gitar)\b', caseSensitive: false),
    RegExp(r'\b(zodiak|horoskop|ramalan\s+bintang|arti\s+mimpi)\b', caseSensitive: false),
    RegExp(r'\b(siapa\s+presiden|ibu\s*kota|sejarah\s+perang|soal\s+fisika|soal\s+kimia|soal\s+biologi)\b', caseSensitive: false),
    RegExp(r'\b(sinopsis\s+film|rekomendasi\s+film|spoiler\s+anime|cheat\s+game)\b', caseSensitive: false),
    RegExp(r'\b(diagnosa\s+penyakit|resep\s+dokter|obat\s+penyakit)\b', caseSensitive: false),
    RegExp(r'\b(buatkan\s+esai|buatkan\s+makalah|buatkan\s+cerita|buatkan\s+artikel|tebak-tebakan|jokes)\b', caseSensitive: false),
  ];

  static final List<RegExp> _financeOrAppPatterns = [
    RegExp(
      r'\b(saldo|uang|keuangan|finansial|anggaran|budget|pengeluaran|pemasukan|transaksi|tabungan|nabung|menabung|hemat|boros|anomali|kategori|gaji|bonus|thr|tagihan|utang|hutang|cicilan|kredit|investasi|saham|reksadana|deposito|emas|dana\s+darurat|inflasi|pajak|modal|untung|rugi|profit|laporan|analisis|analisa|prediksi|target|rupiah|rp|smartfi|catat|makan|makanan|transportasi|hiburan|belanja|biaya|harga|bayar|beli|jual|dompet|rekening|cashflow|arus\s+kas|saran|tips|evaluasi|ringkasan|terbesar|terbanyak)\b',
      caseSensitive: false,
    ),
  ];

  static final List<RegExp> _greetingPatterns = [
    RegExp(
      r'^(halo|hai|hi|hello|hey|pagi|siang|sore|malam|selamat\s+(pagi|siang|sore|malam)|assalamualaikum|apa\s+kabar|terima\s+kasih|makasih|thanks|thank\s+you|ok|oke|sip|siap)(\s+(smartfi|ai|mentor|kak|bro|min))?$',
      caseSensitive: false,
    ),
  ];

  static final List<RegExp> _leakedCodeOutputPatterns = [
    RegExp(r'```'),
    RegExp(
      r'^\s*(def\s+\w+\s*\(|class\s+\w+\s*[:({]|function\s+\w*\s*\(|const\s+\w+\s*=|let\s+\w+\s*=|var\s+\w+\s*=|import\s+[\w\x27"]|#include\s*<|<!DOCTYPE\s+html|<html|<script|public\s+static\s+void|SELECT\s+.+\s+FROM\s+)',
      caseSensitive: false,
      multiLine: true,
    ),
    RegExp(r'\b(console\.log|System\.out\.println|document\.getElementById)\s*\('),
  ];

  static String _normalizeForGreeting(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Apakah pesan adalah sapaan singkat atau ucapan terima kasih
  static bool isGreeting(String message) {
    final normalized = _normalizeForGreeting(message);
    if (normalized.isEmpty) return false;
    return _greetingPatterns.any((p) => p.hasMatch(normalized));
  }

  /// Apakah pesan mengandung kata kunci topik keuangan atau konteks aplikasi SmartFi
  static bool isLikelyFinanceOrAppTopic(String message) {
    return _financeOrAppPatterns.any((p) => p.hasMatch(message));
  }

  /// Pre-filter input pengguna sebelum dikirim ke LLM atau Dummy AI.
  /// Mengembalikan pesan penolakan jika melanggar aturan, atau `null` jika aman diproses.
  static String? validateUserInput(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return null;

    // 1. Cek upaya prompt injection / pengubahan peran
    if (_injectionPatterns.any((p) => p.hasMatch(trimmed))) {
      return injectionRefusalMessage;
    }

    // 2. Cek permintaan kode pemrograman / pembuatan kalkulator (tetap ditolak meski dibingkai keuangan)
    if (_codeKeywordPatterns.any((p) => p.hasMatch(trimmed))) {
      return codeRefusalMessage;
    }

    // 3. Izinkan sapaan natural
    if (isGreeting(trimmed)) {
      return null;
    }

    // 4. Cek topik non-keuangan yang eksplisit
    if (_explicitOffTopicPatterns.any((p) => p.hasMatch(trimmed))) {
      return offTopicRefusalMessage;
    }

    return null;
  }

  /// Post-filter output dari LLM: hapus emoji/simbol terlarang & blokir kebocoran kode
  static String sanitizeAndGuardOutput(String rawText) {
    if (_leakedCodeOutputPatterns.any((p) => p.hasMatch(rawText))) {
      return codeRefusalMessage;
    }

    return rawText
        .replaceAll(
          RegExp(
            r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\uFFFD\u2500-\u25FF\u200B-\u200D\uFEFF\u25AF]',
            unicode: true,
          ),
          '',
        )
        .trim();
  }
}
