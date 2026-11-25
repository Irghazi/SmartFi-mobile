import 'package:flutter/material.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/theme/neo_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/category_model.dart';
import '../../../shared/widgets/neo_button.dart';
import '../../../shared/widgets/neo_card.dart';
import '../../../shared/widgets/neo_input.dart';
import '../services/smart_input_parser.dart';

class SmartPreviewCard extends StatefulWidget {
  final SmartInputResult initialResult;
  final List<CategoryModel> categories;
  final Future<void> Function({
    required String type,
    required String category,
    required int nominal,
    required String description,
    required DateTime transactionDate,
  }) onSave;

  const SmartPreviewCard({
    super.key,
    required this.initialResult,
    required this.categories,
    required this.onSave,
  });

  @override
  State<SmartPreviewCard> createState() => _SmartPreviewCardState();
}

class _SmartPreviewCardState extends State<SmartPreviewCard> {
  late String _type;
  late String _selectedCategory;
  late TextEditingController _nominalController;
  late TextEditingController _descController;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  String _resolveCategory(String type, String currentCategory) {
    final available = widget.categories
        .where((c) => c.type == type)
        .map((c) => c.name)
        .toList();
    for (final cat in available) {
      if (cat.toLowerCase() == currentCategory.toLowerCase()) return cat;
    }
    if (available.isNotEmpty) return available.first;
    return type == 'income' ? 'Gaji' : 'Makanan';
  }

  @override
  void initState() {
    super.initState();
    _type = widget.initialResult.type;
    _selectedCategory = _resolveCategory(_type, widget.initialResult.category);
    _nominalController = TextEditingController(
      text: widget.initialResult.nominal > 0
          ? CurrencyFormatter.formatNumber(widget.initialResult.nominal)
          : '',
    );
    _descController = TextEditingController(text: widget.initialResult.description);
  }

  @override
  void didUpdateWidget(covariant SmartPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialResult != widget.initialResult) {
      _type = widget.initialResult.type;
      _selectedCategory = _resolveCategory(_type, widget.initialResult.category);
      _nominalController.text = widget.initialResult.nominal > 0
          ? CurrencyFormatter.formatNumber(widget.initialResult.nominal)
          : '';
      _descController.text = widget.initialResult.description;
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _nominalController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onNominalChanged(String val) {
    final clean = val.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) {
      _nominalController.value = const TextEditingValue(text: '');
      return;
    }
    final parsed = int.tryParse(clean) ?? 0;
    final formatted = CurrencyFormatter.formatNumber(parsed);
    _nominalController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _handleSave() async {
    final clean = _nominalController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final nominal = int.tryParse(clean) ?? 0;

    if (nominal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal harus lebih dari Rp 0'),
          backgroundColor: NeoColors.warningYellow,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSave(
        type: _type,
        category: _selectedCategory,
        nominal: nominal,
        description: _descController.text.trim().isEmpty
            ? (_type == 'income' ? 'Pemasukan' : 'Pengeluaran')
            : _descController.text.trim(),
        transactionDate: _selectedDate,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan transaksi: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: NeoColors.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = NeoColors.isDark(context);
    final availableCategories = widget.categories
        .where((c) => c.type == _type)
        .map((c) => c.name)
        .toList();
    final borderCol = NeoColors.border(context);
    final textCol = NeoColors.text(context);
    final surfaceCol = NeoColors.surface(context);

    return NeoCard(
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
      borderColor: NeoColors.successGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: NeoColors.yellowAccent,
                  border: Border.all(color: NeoColors.black, width: 2),
                ),
                child: const Icon(Icons.auto_awesome, size: 16, color: NeoColors.black),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PRATINJAU HASIL AI',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.5,
                    color: textCol,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tipe Transaksi Selector
          Text(
            'TIPE TRANSAKSI',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: textCol,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    AudioService().playClickSound();
                    setState(() {
                      _type = 'expense';
                      _selectedCategory = _resolveCategory('expense', _selectedCategory);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _type == 'expense' ? NeoColors.dangerRed : surfaceCol,
                      border: Border.all(color: _type == 'expense' ? NeoColors.black : borderCol, width: 2),
                      boxShadow: _type == 'expense' ? NeoColors.hardShadow(offset: 2) : [],
                    ),
                    child: Center(
                      child: Text(
                        'PENGELUARAN',
                        style: TextStyle(
                          color: _type == 'expense' ? NeoColors.textLight : textCol,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    AudioService().playClickSound();
                    setState(() {
                      _type = 'income';
                      _selectedCategory = _resolveCategory('income', _selectedCategory);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _type == 'income' ? NeoColors.successGreen : surfaceCol,
                      border: Border.all(color: _type == 'income' ? NeoColors.black : borderCol, width: 2),
                      boxShadow: _type == 'income' ? NeoColors.hardShadow(offset: 2) : [],
                    ),
                    child: Center(
                      child: Text(
                        'PEMASUKAN',
                        style: TextStyle(
                          color: _type == 'income' ? NeoColors.textLight : textCol,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Kategori Dropdown / Selector
          Text(
            'KATEGORI',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: textCol,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: surfaceCol,
              border: Border.all(color: borderCol, width: 2),
              boxShadow: NeoColors.hardShadow(offset: 2),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: surfaceCol,
                iconEnabledColor: textCol,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: textCol,
                ),
                value: availableCategories.contains(_selectedCategory)
                    ? _selectedCategory
                    : (availableCategories.isNotEmpty ? availableCategories.first : null),
                items: availableCategories.map((name) {
                  return DropdownMenuItem<String>(
                    value: name,
                    child: Text(
                      name,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textCol),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Input Nominal
          NeoInput(
            label: 'Nominal (Rp)',
            controller: _nominalController,
            keyboardType: TextInputType.number,
            hintText: '25.000',
            onChanged: _onNominalChanged,
          ),
          const SizedBox(height: 14),

          // Input Deskripsi
          NeoInput(
            label: 'Deskripsi Transaksi',
            controller: _descController,
            hintText: 'Makan siang warteg...',
          ),
          const SizedBox(height: 14),

          // Tanggal Transaksi
          Text(
            'TANGGAL TRANSAKSI',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: textCol,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: surfaceCol,
                border: Border.all(color: borderCol, width: 2),
                boxShadow: NeoColors.hardShadow(offset: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormatter.formatTanggal(_selectedDate),
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textCol),
                  ),
                  Icon(Icons.calendar_today, size: 18, color: textCol),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Tombol Simpan
          NeoButton(
            text: 'Simpan Transaksi',
            variant: NeoButtonVariant.success,
            isLoading: _isSaving,
            onPressed: _handleSave,
            icon: const Icon(Icons.check_circle_outline, color: NeoColors.black),
          ),
        ],
      ),
    );
  }
}

