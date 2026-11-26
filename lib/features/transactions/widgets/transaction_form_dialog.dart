import 'package:flutter/material.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/theme/neo_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../shared/widgets/neo_button.dart';
import '../../../shared/widgets/neo_input.dart';
import '../../../shared/widgets/neo_modal.dart';

class TransactionFormDialog {
  TransactionFormDialog._();

  static Future<void> show({
    required BuildContext context,
    required String userId,
    required List<CategoryModel> categories,
    TransactionModel? editingTx,
    int? currentBalance,
    required Future<void> Function(TransactionModel tx) onSave,
  }) {
    return NeoModal.show(
      context: context,
      title: editingTx == null ? 'Tambah Transaksi' : 'Ubah Transaksi',
      child: _TransactionFormContent(
        userId: userId,
        categories: categories,
        editingTx: editingTx,
        currentBalance: currentBalance,
        onSave: onSave,
      ),
    );
  }
}

class _TransactionFormContent extends StatefulWidget {
  final String userId;
  final List<CategoryModel> categories;
  final TransactionModel? editingTx;
  final int? currentBalance;
  final Future<void> Function(TransactionModel tx) onSave;

  const _TransactionFormContent({
    required this.userId,
    required this.categories,
    this.editingTx,
    this.currentBalance,
    required this.onSave,
  });

  @override
  State<_TransactionFormContent> createState() => _TransactionFormContentState();
}

class _TransactionFormContentState extends State<_TransactionFormContent> {
  late String _type;
  late String _categoryName;
  late TextEditingController _nominalController;
  late TextEditingController _descController;
  late DateTime _selectedDate;
  bool _isSaving = false;
  String? _nominalError;

  bool get _isSystemAdjustment =>
      widget.editingTx != null &&
      widget.editingTx!.categoryId == null &&
      (widget.editingTx!.categoryName == 'Saldo Awal' ||
          widget.editingTx!.categoryName == 'Penyesuaian Saldo');

  bool _isPreservedOriginalCategory(String type, String currentCategory) {
    return widget.editingTx != null &&
        widget.editingTx!.type == type &&
        currentCategory == widget.editingTx!.categoryName;
  }

  String _resolveCategory(String type, String currentCategory) {
    if (_isPreservedOriginalCategory(type, currentCategory)) {
      return currentCategory;
    }
    final available = widget.categories
        .where((c) => c.type == type)
        .map((c) => c.name)
        .toList();
    if (available.contains(currentCategory)) return currentCategory;
    if (available.isNotEmpty) return available.first;
    return type == 'income' ? 'Gaji' : 'Makanan';
  }

  @override
  void initState() {
    super.initState();
    _type = widget.editingTx?.type ?? 'expense';
    _categoryName = _resolveCategory(
      _type,
      widget.editingTx?.categoryName ?? 'Makanan',
    );
    _nominalController = TextEditingController(
      text: widget.editingTx != null
          ? CurrencyFormatter.formatNumber(widget.editingTx!.nominal)
          : '',
    );
    _descController = TextEditingController(
      text: widget.editingTx?.description ?? '',
    );
    _selectedDate = widget.editingTx?.transactionDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _nominalController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onNominalChanged(String val) {
    if (_nominalError != null) {
      setState(() => _nominalError = null);
    }
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

  Future<void> _submit() async {
    final clean = _nominalController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final nominal = int.tryParse(clean) ?? 0;

    if (nominal <= 0) {
      setState(() => _nominalError = 'Nominal harus lebih dari Rp 0');
      return;
    }

    if (_type == 'expense' && widget.currentBalance != null) {
      int availableBalance = widget.currentBalance!;
      if (widget.editingTx != null) {
        if (widget.editingTx!.isExpense) {
          availableBalance += widget.editingTx!.nominal;
        } else {
          availableBalance -= widget.editingTx!.nominal;
        }
      }
      if (nominal > availableBalance) {
        final safeAvail = availableBalance < 0 ? 0 : availableBalance;
        setState(() {
          _nominalError =
              'Saldo tidak mencukupi! Maksimal pengeluaran ${CurrencyFormatter.formatRupiah(safeAvail)}.';
        });
        return;
      }
    }

    setState(() {
      _nominalError = null;
      _isSaving = true;
    });

    try {
      final fallbackCategories = (widget.categories.isNotEmpty
              ? widget.categories
              : CategoryModel.defaultCategories)
          .where((c) => c.type == _type)
          .toList();

      String? categoryId;
      if (_isSystemAdjustment && _categoryName == widget.editingTx!.categoryName) {
        categoryId = null;
      } else {
        final matches = fallbackCategories.where((c) => c.name == _categoryName);
        if (matches.isNotEmpty) {
          categoryId = matches.first.id;
        } else if (_isPreservedOriginalCategory(_type, _categoryName)) {
          // Pertahankan referensi lama jika kategori kustom sebelumnya sudah dihapus
          categoryId = widget.editingTx!.categoryId;
        } else if (fallbackCategories.isNotEmpty) {
          categoryId = fallbackCategories.first.id;
        }
      }

      final tx = TransactionModel(
        id: widget.editingTx?.id ?? 'tx_${DateTime.now().millisecondsSinceEpoch}',
        userId: widget.userId,
        type: _type,
        nominal: nominal,
        description: _descController.text.trim().isEmpty
            ? (_type == 'income' ? 'Pemasukan' : 'Pengeluaran')
            : _descController.text.trim(),
        categoryId: categoryId,
        categoryName: _categoryName,
        transactionDate: _selectedDate,
        createdAt: widget.editingTx?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await widget.onSave(tx);
      if (mounted) Navigator.of(context).pop();
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
    final filteredCategories = widget.categories
        .where((c) => c.type == _type)
        .map((c) => c.name)
        .toList();
    if (widget.editingTx != null &&
        _type == widget.editingTx!.type &&
        widget.editingTx!.categoryName.isNotEmpty &&
        !filteredCategories.contains(widget.editingTx!.categoryName)) {
      filteredCategories.insert(0, widget.editingTx!.categoryName);
    }

    final textCol = NeoColors.text(context);
    final surfaceCol = NeoColors.surface(context);
    final borderCol = NeoColors.border(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pilihan Tipe
        Text(
          'TIPE TRANSAKSI',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5, color: textCol),
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
                    _nominalError = null;
                    _categoryName = _resolveCategory('expense', _categoryName);
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
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  AudioService().playClickSound();
                  setState(() {
                    _type = 'income';
                    _nominalError = null;
                    _categoryName = _resolveCategory('income', _categoryName);
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

        // Kategori Dropdown
        Text(
          'KATEGORI',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5, color: textCol),
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
              value: filteredCategories.contains(_categoryName)
                  ? _categoryName
                  : (filteredCategories.isNotEmpty ? filteredCategories.first : null),
              items: filteredCategories.map((name) {
                return DropdownMenuItem<String>(
                  value: name,
                  child: Text(
                    name,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textCol),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _categoryName = val);
              },
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Nominal
        NeoInput(
          label: 'Nominal (Rp)',
          controller: _nominalController,
          keyboardType: TextInputType.number,
          hintText: '50.000',
          errorText: _nominalError,
          onChanged: _onNominalChanged,
        ),
        const SizedBox(height: 14),

        // Deskripsi
        NeoInput(
          label: 'Deskripsi Transaksi',
          controller: _descController,
          hintText: 'Contoh: Belanja mingguan...',
        ),
        const SizedBox(height: 14),

        // Tanggal Transaksi Picker
        Text(
          'TANGGAL TRANSAKSI',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5, color: textCol),
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
        const SizedBox(height: 20),

        NeoButton(
          text: widget.editingTx == null ? 'Simpan Transaksi' : 'Perbarui Transaksi',
          variant: NeoButtonVariant.primary,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }
}

