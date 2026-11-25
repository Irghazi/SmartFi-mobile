import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/theme/neo_colors.dart';
import '../../../data/models/category_model.dart';
import '../../../shared/widgets/blueprint_background.dart';
import '../../../shared/widgets/neo_app_bar.dart';
import '../../../shared/widgets/neo_badge.dart';
import '../../../shared/widgets/neo_button.dart';
import '../../../shared/widgets/neo_card.dart';
import '../../../shared/widgets/neo_modal.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/category_provider.dart';
import '../widgets/category_form_modal.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  void _confirmDeleteCategory(BuildContext context, WidgetRef ref, CategoryModel category) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    NeoModal.show(
      context: context,
      title: 'Hapus Kategori',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Apakah Anda yakin ingin menghapus kategori "${category.name}"? Riwayat transaksi lama dengan kategori ini akan tetap tersimpan.',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: NeoButton(
                  text: 'Batal',
                  variant: NeoButtonVariant.outline,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeoButton(
                  text: 'Hapus',
                  variant: NeoButtonVariant.danger,
                  onPressed: () async {
                    Navigator.of(context).pop();
                    try {
                      await ref.read(categoriesProvider.notifier).deleteCategory(category.id);
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text('Kategori "${category.name}" dihapus')),
                      );
                    } catch (e) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text('Gagal menghapus kategori: ${e.toString().replaceFirst('Exception: ', '')}'),
                          backgroundColor: NeoColors.dangerRed,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context,
    WidgetRef ref,
    String? userId,
    CategoryModel cat,
  ) {
    final iconData = CategoryIcons.getIcon(cat.iconName);
    final bgColor = CategoryIcons.parseColor(cat.colorHex);

    return NeoCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Baris Atas: Ikon + Tombol Aksi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border.all(color: NeoColors.black, width: 2),
                  boxShadow: NeoColors.hardShadow(offset: 2),
                ),
                child: Icon(iconData, size: 20, color: NeoColors.black),
              ),
              if (!cat.isDefault && userId != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        AudioService().playClickSound();
                        CategoryFormModal.show(
                          context: context,
                          userId: userId,
                          editingCategory: cat,
                          onSave: (updated) async {
                            await ref.read(categoriesProvider.notifier).updateCategory(updated);
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: NeoColors.yellowAccent,
                          border: Border.all(color: NeoColors.black, width: 2),
                          boxShadow: NeoColors.hardShadow(offset: 1.5),
                        ),
                        child: const Icon(Icons.edit, size: 14, color: NeoColors.black),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        AudioService().playClickSound();
                        _confirmDeleteCategory(context, ref, cat);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: NeoColors.dangerRedLight,
                          border: Border.all(color: NeoColors.black, width: 2),
                          boxShadow: NeoColors.hardShadow(offset: 1.5),
                        ),
                        child: const Icon(Icons.delete_outline, size: 14, color: NeoColors.black),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Nama Kategori & Badge Tipe
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cat.name.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              NeoBadge(
                text: cat.isExpense ? 'Pengeluaran' : 'Pemasukan',
                backgroundColor: cat.isExpense ? NeoColors.dangerRedLight : NeoColors.successGreenLight,
                fontSize: 9,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);
    final userId = userAsync.asData?.value?.id;

    final categoriesAsync = ref.watch(categoriesProvider);
    final textCol = NeoColors.text(context);
    final mutedCol = NeoColors.mutedText(context);
    final borderCol = NeoColors.border(context);

    return Scaffold(
      appBar: NeoAppBar(
        title: 'Manajemen Kategori',
        leading: GestureDetector(
          onTap: () {
            AudioService().playClickSound();
            Navigator.of(context).pop();
          },
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: NeoColors.surfaceSecondary(context),
              border: Border.all(color: borderCol, width: 2.0),
              boxShadow: NeoColors.hardShadow(offset: 2.0),
            ),
            child: Icon(Icons.arrow_back, color: textCol, size: 20),
          ),
        ),
      ),
      body: BlueprintBackground(
        child: RefreshIndicator(
          color: NeoColors.primaryBlue,
          backgroundColor: NeoColors.surface(context),
          onRefresh: () async {
            await ref.read(categoriesProvider.notifier).loadCategories(showLoading: false);
          },
          child: categoriesAsync.when(
            loading: () => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.65,
                  child: Center(
                    child: CircularProgressIndicator(color: textCol),
                  ),
                ),
              ],
            ),
            error: (err, _) => ListView(
              padding: const EdgeInsets.all(24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                Icon(Icons.cloud_off, size: 48, color: mutedCol),
                const SizedBox(height: 12),
                Text(
                  'Terjadi kesalahan saat memuat kategori.\n($err)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700, color: textCol),
                ),
                const SizedBox(height: 16),
                NeoButton(
                  text: 'Coba Lagi',
                  isFullWidth: false,
                  onPressed: () => ref.read(categoriesProvider.notifier).loadCategories(),
                ),
              ],
            ),
            data: (categories) {
              final rows = <Widget>[];
              for (int i = 0; i < categories.length; i += 2) {
                final first = categories[i];
                final second = (i + 1 < categories.length) ? categories[i + 1] : null;
                rows.add(
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildCategoryTile(context, ref, userId, first)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: second != null
                                ? _buildCategoryTile(context, ref, userId, second)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16.0),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // Header Card
                  NeoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: NeoColors.yellowAccent,
                                border: Border.all(color: NeoColors.black, width: 2),
                                boxShadow: NeoColors.hardShadow(offset: 2),
                              ),
                              child: const Icon(Icons.grid_view, size: 24, color: NeoColors.black),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'MANAJEMEN KATEGORI',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    'Kelola kategori transaksi sesuai kebutuhanmu.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: mutedCol,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        NeoButton(
                          text: 'Tambah Kategori Baru',
                          variant: NeoButtonVariant.primary,
                          icon: const Icon(Icons.add, color: NeoColors.white),
                          onPressed: userId == null
                              ? null
                              : () {
                                  CategoryFormModal.show(
                                    context: context,
                                    userId: userId,
                                    onSave: (newCat) async {
                                      await ref.read(categoriesProvider.notifier).addCategory(newCat);
                                    },
                                  );
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (categories.isEmpty)
                    NeoCard(
                      child: Center(
                        child: Text(
                          'Belum ada kategori tersedia.',
                          style: TextStyle(fontWeight: FontWeight.w800, color: mutedCol),
                        ),
                      ),
                    )
                  else
                    ...rows,
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
