import '../../../data/models/category_model.dart';

class SmartInputResult {
  final String type; // 'income' | 'expense'
  final String category;
  final int nominal;
  final String description;

  const SmartInputResult({
    required this.type,
    required this.category,
    required this.nominal,
    required this.description,
  });
}

class SmartInputParser {
  SmartInputParser._();

  static SmartInputResult parse(String text, List<CategoryModel> userCategories) {
    final lower = text.toLowerCase().trim();

    // 1. Ekstrak Nominal
    int nominal = _extractNominal(lower);

    // 2. Ekstrak Tipe (Income vs Expense)
    String type = _extractType(lower);

    // 3. Ekstrak Kategori
    String category = _extractCategory(lower, type, userCategories);

    // 4. Buat Deskripsi
    String description = text.trim();
    if (description.isEmpty) {
      description = type == 'income' ? 'Pemasukan' : 'Pengeluaran';
    }

    return SmartInputResult(
      type: type,
      category: category,
      nominal: nominal,
      description: description,
    );
  }

  static int _extractNominal(String text) {
    // Pola 1.5 juta / 1,5 jt / 2 juta
    final jutaRegex = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:juta|jt)', caseSensitive: false);
    final jutaMatch = jutaRegex.firstMatch(text);
    if (jutaMatch != null) {
      final numStr = jutaMatch.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(numStr) ?? 0;
      return (val * 1000000).round();
    }

    // Pola 25 ribu / 25rb / 25k
    final ribuRegex = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:ribu|rb|k)', caseSensitive: false);
    final ribuMatch = ribuRegex.firstMatch(text);
    if (ribuMatch != null) {
      final numStr = ribuMatch.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(numStr) ?? 0;
      return (val * 1000).round();
    }

    // Pola angka dengan awalan Rp (bisa 3 digit seperti Rp 500) atau angka >= 4 digit / bertitik
    final rpNumberRegex = RegExp(r'rp\.?\s*(\d{1,3}(?:\.\d{3})*|\d+)', caseSensitive: false);
    final rpMatch = rpNumberRegex.firstMatch(text);
    if (rpMatch != null) {
      final clean = rpMatch.group(1)!.replaceAll('.', '');
      return int.tryParse(clean) ?? 0;
    }

    // Pola angka berpemisah ribuan lebih diprioritaskan agar tahun 4-digit tidak mengalahkan nominal: misal "2026 50.000"
    final dottedRegex = RegExp(r'\b(\d{1,3}(?:[.,]\d{3})+)\b', caseSensitive: false);
    final dottedMatch = dottedRegex.firstMatch(text);
    if (dottedMatch != null) {
      final clean = dottedMatch.group(1)!.replaceAll(RegExp(r'[.,]'), '');
      return int.tryParse(clean) ?? 0;
    }

    // Pola angka murni minimal 3 digit: misal 50000 atau 500
    final rawNumberRegex = RegExp(r'\b(\d{3,})\b', caseSensitive: false);
    final rawMatch = rawNumberRegex.firstMatch(text);
    if (rawMatch != null) {
      return int.tryParse(rawMatch.group(1)!) ?? 0;
    }

    return 0;
  }

  static bool _containsKeyword(String text, String keyword) {
    final pattern = RegExp(
      r'(?:^|\b)' + RegExp.escape(keyword) + r'(?:\b|$)',
      caseSensitive: false,
    );
    return pattern.hasMatch(text);
  }

  static String _extractType(String text) {
    final expenseStrongKeywords = [
      'beli', 'bayar', 'belanja', 'jajan', 'makan', 'minum', 'ongkir', 'bensin',
      'parkir', 'tagihan', 'cicilan', 'obat', 'dokter', 'keluar', 'habis', 'sewa',
    ];
    for (final kw in expenseStrongKeywords) {
      if (_containsKeyword(text, kw)) {
        // Pengecualian eksplisit jika memang transfer/uang masuk gaji
        if (_containsKeyword(text, 'gaji') ||
            _containsKeyword(text, 'bonus') ||
            _containsKeyword(text, 'thr') ||
            _containsKeyword(text, 'honor') ||
            _containsKeyword(text, 'cashback')) {
          return 'income';
        }
        return 'expense';
      }
    }

    final incomeKeywords = [
      'gaji', 'bonus', 'terima', 'dapat', 'penjualan', 'profit',
      'cair', 'thr', 'honor', 'transfer masuk', 'uang masuk', 'pemasukan',
      'upah', 'dividen', 'cashback', 'gajian',
    ];

    for (final kw in incomeKeywords) {
      if (_containsKeyword(text, kw)) {
        return 'income';
      }
    }
    return 'expense';
  }

  static String _extractCategory(String text, String type, List<CategoryModel> categories) {
    final matchingTypeCats = categories.where((c) => c.type == type).toList();

    // 1. Cek kecocokan langsung terhadap nama kategori milik pengguna (sesuai tipe)
    for (final cat in matchingTypeCats) {
      if (_containsKeyword(text, cat.name.toLowerCase())) {
        return cat.name;
      }
    }

    if (type == 'income') {
      return matchingTypeCats.isNotEmpty ? matchingTypeCats.first.name : 'Gaji';
    }

    // 2. Pemetaan kata kunci ke kandidat kategori pengeluaran (berurutan prioritas)
    final keywordCandidates = <String, List<String>>{
      'Transportasi': ['bensin', 'bbm', 'pertalite', 'pertamax', 'ojol', 'gojek', 'grab', 'taksi', 'kereta', 'krl', 'bus', 'tol', 'parkir', 'service motor', 'tambal ban', 'transport'],
      'Hiburan': ['nonton', 'bioskop', 'film', 'game', 'netflix', 'spotify', 'karaoke', 'liburan', 'wisata', 'healing', 'hiburan'],
      'Tagihan': ['listrik', 'pln', 'pdam', 'pulsa', 'kuota', 'wifi', 'indihome', 'internet', 'kos', 'bpjs', 'tagihan', 'sewa'],
      'Belanja': ['belanja', 'minimarket', 'indomaret', 'alfamart', 'mall', 'baju', 'sepatu', 'shopee', 'tokopedia', 'lazada', 'tiktok shop', 'pasar'],
      'Kesehatan': ['obat', 'dokter', 'apotek', 'rumah sakit', 'klinik', 'vitamin', 'medis'],
      'Makanan': ['makan', 'minum', 'siang', 'malam', 'sarapan', 'warteg', 'resto', 'cafe', 'kopi', 'jajan', 'ayam', 'nasi', 'grabfood', 'gofood', 'kuliner', 'bakso', 'mie', 'snack'],
    };

    for (final entry in keywordCandidates.entries) {
      final matchedKw = entry.value.any((kw) => _containsKeyword(text, kw));
      if (matchedKw) {
        final existing = matchingTypeCats.where(
          (c) => c.name.toLowerCase() == entry.key.toLowerCase(),
        );
        if (existing.isNotEmpty) return existing.first.name;
      }
    }

    // Default ke kategori pengeluaran pertama jika ada
    if (matchingTypeCats.isNotEmpty) return matchingTypeCats.first.name;

    return 'Makanan';
  }
}

