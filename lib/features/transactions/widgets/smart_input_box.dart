import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/theme/neo_colors.dart';
import '../../../data/models/category_model.dart';
import '../../../shared/widgets/neo_button.dart';
import '../../../shared/widgets/neo_card.dart';
import '../../ai_advisor/providers/ai_provider.dart';
import '../services/smart_input_parser.dart';
import 'smart_preview_card.dart';

class SmartInputBox extends ConsumerStatefulWidget {
  final List<CategoryModel> categories;
  final Future<void> Function({
    required String type,
    required String category,
    required int nominal,
    required String description,
    required DateTime transactionDate,
  }) onSaveTransaction;

  const SmartInputBox({
    super.key,
    required this.categories,
    required this.onSaveTransaction,
  });

  @override
  ConsumerState<SmartInputBox> createState() => _SmartInputBoxState();
}

class _SmartInputBoxState extends ConsumerState<SmartInputBox> {
  final _textController = TextEditingController();
  SmartInputResult? _previewResult;
  bool _isProcessing = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleProcessAI() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isProcessing) return;

    setState(() => _isProcessing = true);
    SmartInputResult result;
    var usedFallback = false;

    try {
      final useRealAi = ref.read(useRealAiApiProvider);
      if (useRealAi) {
        final aiRepo = ref.read(aiRepositoryProvider);
        final catNames = widget.categories.map((c) => c.name).toList();
        final raw = await aiRepo.parseSmartInput(
          prompt: text,
          categories: catNames.isNotEmpty ? catNames : ['Makanan', 'Transportasi', 'Hiburan', 'Gaji'],
        );

        final parsedType = (raw['type']?.toString().toLowerCase() == 'income')
            ? 'income'
            : 'expense';
        final rawNominal = raw['nominal'];
        final parsedNominal = (rawNominal is num)
            ? rawNominal.toInt()
            : int.tryParse(rawNominal?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '') ?? 0;
        final parsedCategory = raw['category']?.toString().trim() ?? '';
        final parsedDesc = raw['description']?.toString().trim() ?? '';
        final fallbackParsed = (parsedCategory.isEmpty || parsedNominal <= 0)
            ? SmartInputParser.parse(text, widget.categories)
            : null;

        result = SmartInputResult(
          type: parsedType,
          category: parsedCategory.isNotEmpty
              ? parsedCategory
              : fallbackParsed!.category,
          nominal: parsedNominal > 0
              ? parsedNominal
              : fallbackParsed!.nominal,
          description: parsedDesc.isNotEmpty ? parsedDesc : text,
        );
      } else {
        await Future.delayed(const Duration(milliseconds: 250));
        result = SmartInputParser.parse(text, widget.categories);
      }
    } catch (_) {
      usedFallback = true;
      result = SmartInputParser.parse(text, widget.categories);
    }

    AudioService().playChatSound();

    if (mounted) {
      setState(() {
        _previewResult = result;
        _isProcessing = false;
      });
      if (usedFallback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI online tidak terjangkau, diproses dengan mode offline.'),
            backgroundColor: NeoColors.warningYellow,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textCol = NeoColors.text(context);
    final mutedCol = NeoColors.mutedText(context);
    final borderCol = NeoColors.border(context);

    return NeoCard(
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
                child: const Icon(Icons.smart_toy, size: 18, color: NeoColors.black),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SMART INPUT AI',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.5,
                    color: textCol,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tuliskan transaksi Anda secara alami, biarkan AI yang mencatat.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: mutedCol,
            ),
          ),
          const SizedBox(height: 12),

          // Textarea Input (warna adaptif light/dark agar teks selalu terbaca)
          Container(
            decoration: BoxDecoration(
              color: NeoColors.surfaceSecondary(context),
              border: Border.all(color: borderCol, width: 2.0),
              boxShadow: NeoColors.hardShadow(offset: 2.0),
            ),
            child: TextField(
              controller: _textController,
              maxLines: 3,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: textCol,
              ),
              decoration: InputDecoration(
                hintText: 'Contoh: Makan siang di warteg habis 25 ribu...',
                hintStyle: TextStyle(
                  color: mutedCol.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                contentPadding: const EdgeInsets.all(12),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tombol Proses
          NeoButton(
            text: 'Proses Dengan AI',
            isLoading: _isProcessing,
            onPressed: _handleProcessAI,
            variant: NeoButtonVariant.primary,
            icon: const Icon(Icons.psychology, color: NeoColors.white),
          ),

          // Tampilan Preview
          if (_previewResult != null) ...[
            const SizedBox(height: 16),
            SmartPreviewCard(
              initialResult: _previewResult!,
              categories: widget.categories,
              onSave: ({
                required String type,
                required String category,
                required int nominal,
                required String description,
                required DateTime transactionDate,
              }) async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                await widget.onSaveTransaction(
                  type: type,
                  category: category,
                  nominal: nominal,
                  description: description,
                  transactionDate: transactionDate,
                );
                if (mounted) {
                  setState(() {
                    _previewResult = null;
                    _textController.clear();
                  });
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Transaksi berhasil dicatat secara cerdas!'),
                      backgroundColor: NeoColors.successGreen,
                    ),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

