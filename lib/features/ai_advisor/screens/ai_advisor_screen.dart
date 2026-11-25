import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/ai_config.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/theme/neo_colors.dart';
import '../../../shared/widgets/blueprint_background.dart';
import '../../../shared/widgets/neo_button.dart';
import '../../../shared/widgets/neo_modal.dart';
import '../models/chat_message.dart';
import '../providers/ai_provider.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/suggestion_pills.dart';

/// Layar Mentor / Penasihat Keuangan AI SmartFi
class AiAdvisorScreen extends ConsumerStatefulWidget {
  const AiAdvisorScreen({super.key});

  @override
  ConsumerState<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends ConsumerState<AiAdvisorScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend([String? presetText]) async {
    final text = presetText ?? _inputController.text.trim();
    if (text.isEmpty) return;

    if (presetText == null) {
      _inputController.clear();
    }

    _scrollToBottom();
    final notifier = ref.read(chatProvider.notifier);

    // Kirim pesan ke provider AI
    await notifier.sendMessage(text);
    _scrollToBottom();

    // Mainkan efek suara chat
    AudioService().playChatSound();
  }

  Future<void> _handleConfirmClear() async {
    final shouldClear = await NeoModal.show<bool>(
      context: context,
      title: 'Hapus Obrolan',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Apakah Anda yakin ingin menghapus semua riwayat obrolan dengan Penasihat AI?',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: NeoButton(
                  text: 'Batal',
                  variant: NeoButtonVariant.outline,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NeoButton(
                  text: 'Hapus',
                  variant: NeoButtonVariant.danger,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      await ref.read(chatProvider.notifier).clearHistory();
    }
  }

  void _showApiSourceDialog() {
    final isReal = ref.read(useRealAiApiProvider) && AiConfig.hasApiKey;
    final surfaceCol = NeoColors.surface(context);
    final borderCol = NeoColors.border(context);
    final textCol = NeoColors.text(context);
    final mutedCol = NeoColors.mutedText(context);

    NeoModal.show(
      context: context,
      title: 'Sumber API AI',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Pilih sumber kecerdasan AI untuk konsultasi finansial:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: textCol),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () {
              if (!AiConfig.hasApiKey) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'API Key belum dikonfigurasi di env.json. Menjalankan mode OFFLINE.',
                    ),
                    backgroundColor: NeoColors.warningYellow,
                  ),
                );
                return;
              }
              ref.read(useRealAiApiProvider.notifier).state = true;
              Navigator.of(context).pop();
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isReal ? NeoColors.yellowAccent : surfaceCol,
                border: Border.all(color: isReal ? NeoColors.black : borderCol, width: 2),
                boxShadow: NeoColors.hardShadow(offset: 2),
              ),
              child: Row(
                children: [
                  Icon(
                    isReal ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isReal ? NeoColors.black : textCol,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'API BANGUNWEB (REAL ONLINE)',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: isReal ? NeoColors.textDark : textCol,
                          ),
                        ),
                        Text(
                          AiConfig.hasApiKey
                              ? 'Menggunakan endpoint OpenAI via BangunWeb'
                              : 'API Key belum diatur pada env.json',
                          style: TextStyle(
                            fontSize: 10,
                            color: !AiConfig.hasApiKey
                                ? NeoColors.dangerRed
                                : (isReal ? NeoColors.textMuted : mutedCol),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () {
              ref.read(useRealAiApiProvider.notifier).state = false;
              Navigator.of(context).pop();
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: !isReal ? NeoColors.yellowAccent : surfaceCol,
                border: Border.all(color: !isReal ? NeoColors.black : borderCol, width: 2),
                boxShadow: NeoColors.hardShadow(offset: 2),
              ),
              child: Row(
                children: [
                  Icon(
                    !isReal ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: !isReal ? NeoColors.black : textCol,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DUMMY REPOSITORY (OFFLINE)',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: !isReal ? NeoColors.textDark : textCol,
                          ),
                        ),
                        Text(
                          'Bekerja tanpa koneksi internet dengan kalkulasi lokal',
                          style: TextStyle(
                            fontSize: 10,
                            color: !isReal ? NeoColors.textMuted : mutedCol,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final messages = chatState.messages;
    final isLoading = chatState.isLoading;
    final isRealApi = ref.watch(useRealAiApiProvider) && AiConfig.hasApiKey;

    final surfaceCol = NeoColors.surface(context);
    final borderCol = NeoColors.border(context);
    final textCol = NeoColors.text(context);
    final mutedCol = NeoColors.mutedText(context);

    // Auto scroll saat pesan berubah
    ref.listen(chatProvider, (_, __) => _scrollToBottom());

    return BlueprintBackground(
      child: Column(
        children: [
          // Toolbar Ringkas Mentor AI (tanpa judul duplikat dengan NeoAppBar)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: surfaceCol,
              border: Border(
                bottom: BorderSide(color: borderCol, width: 3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: NeoColors.white,
                    border: Border.all(color: NeoColors.black, width: 2),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'MENTOR FINANSIAL PRIBADI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                      color: mutedCol,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Badge Mode API
                InkWell(
                  onTap: _showApiSourceDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: isRealApi ? NeoColors.successGreenLight : NeoColors.yellowAccent,
                      border: Border.all(color: NeoColors.black, width: 2),
                      boxShadow: NeoColors.hardShadow(offset: 2),
                    ),
                    child: Text(
                      isRealApi ? 'REAL AI' : 'OFFLINE',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: NeoColors.textDark,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Tombol Muat Ulang Permintaan Terakhir
                InkWell(
                  onTap: messages.length <= 1 || isLoading
                      ? null
                      : () => ref.read(chatProvider.notifier).regenerateLastResponse(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: messages.length <= 1 || isLoading
                          ? NeoColors.disabledSurface(context)
                          : surfaceCol,
                      border: Border.all(color: borderCol, width: 2),
                      boxShadow: NeoColors.hardShadow(offset: 2),
                    ),
                    child: Icon(Icons.refresh, size: 17, color: textCol),
                  ),
                ),
                const SizedBox(width: 8),
                // Tombol Hapus Obrolan
                InkWell(
                  onTap: isLoading ? null : _handleConfirmClear,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: NeoColors.dangerRed,
                      border: Border.all(color: NeoColors.black, width: 2),
                      boxShadow: NeoColors.hardShadow(offset: 2),
                    ),
                    child: const Icon(Icons.delete_outline, size: 17, color: NeoColors.white),
                  ),
                ),
              ],
            ),
          ),

          // Area Daftar Chat
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(14),
              itemCount: messages.length + (isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < messages.length) {
                  final msg = messages[index];
                  final isLast = index == messages.length - 1;
                  return ChatMessageBubble(
                    message: msg,
                    isLastAiMessage: isLast && msg.isAi,
                    isAiLoading: isLoading,
                    onRegenerate: () =>
                        ref.read(chatProvider.notifier).regenerateLastResponse(),
                  );
                } else {
                  return ChatMessageBubble(
                    message: ChatMessage(
                      id: 'typing_temp',
                      role: 'ai',
                      content: '',
                      createdAt: DateTime.now(),
                    ),
                    isAiLoading: true,
                  );
                }
              },
            ),
          ),

          // Area Bawah: Suggestion Pills + Input Box
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: surfaceCol,
              border: Border(
                top: BorderSide(color: borderCol, width: 3),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Suggestion Pills
                  SuggestionPills(
                    disabled: isLoading,
                    onSelected: (text) => _handleSend(text),
                  ),
                  const SizedBox(height: 10),

                  // Input Box + Send Button
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: NeoColors.surfaceSecondary(context),
                            border: Border.all(color: borderCol, width: 3),
                            boxShadow: NeoColors.hardShadow(offset: 3),
                          ),
                          child: TextField(
                            controller: _inputController,
                            focusNode: _focusNode,
                            enabled: !isLoading,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textCol,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Ketik pertanyaan Anda...',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: mutedCol,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (val) => _handleSend(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: isLoading ? null : () => _handleSend(),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isLoading
                                ? NeoColors.disabledSurface(context)
                                : NeoColors.primaryBlue,
                            border: Border.all(color: NeoColors.black, width: 3),
                            boxShadow: NeoColors.hardShadow(
                              offset: isLoading ? 0 : 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.send,
                            size: 20,
                            color: NeoColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Disclaimer
                  Text(
                    'SmartFi AI dapat membuat kesalahan. Harap verifikasi informasi penting.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                      color: mutedCol,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
