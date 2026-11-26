import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/category_model.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/dummy/dummy_category_repository.dart';
import '../../../data/repositories/firebase/firebase_category_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../transactions/providers/transaction_provider.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  if (Firebase.apps.isNotEmpty) {
    return FirebaseCategoryRepository();
  }
  return DummyCategoryRepository();
});

class CategoriesNotifier extends StateNotifier<AsyncValue<List<CategoryModel>>> {
  final CategoryRepository _repository;
  final String? _userId;
  final Ref _ref;
  StreamSubscription<List<CategoryModel>>? _streamSub;

  CategoriesNotifier(this._repository, this._userId, this._ref)
      : super(_userId == null
            ? const AsyncValue.data([])
            : const AsyncValue.loading()) {
    if (_userId != null) {
      _subscribeOrLoad(_userId);
    }
  }

  void _subscribeOrLoad(String uid) {
    final stream = _repository.watchCategories(uid);
    if (stream != null) {
      _streamSub = stream.listen(
        (list) {
          if (mounted) state = AsyncValue.data(list);
        },
        onError: (Object err, StackTrace st) {
          if (mounted && !state.hasValue) {
            state = AsyncValue.error(err, st);
          }
        },
      );
    } else {
      loadCategories();
    }
  }

  Future<void> loadCategories({bool showLoading = true}) async {
    final uid = _userId;
    if (uid == null) {
      if (mounted) state = const AsyncValue.data([]);
      return;
    }

    if (showLoading && !state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final list = await _repository.getCategories(uid);
      if (mounted) state = AsyncValue.data(list);
    } catch (e, st) {
      if (mounted && !state.hasValue) {
        state = AsyncValue.error(e, st);
      } else {
        rethrow;
      }
    }
  }

  Future<void> addCategory(CategoryModel category) async {
    final previous = state.asData?.value ?? const <CategoryModel>[];
    final optimistic = [...previous, category];
    if (mounted) state = AsyncValue.data(optimistic);

    try {
      final saved = await _repository.addCategory(category);
      if (mounted) {
        final current = state.asData?.value ?? optimistic;
        state = AsyncValue.data([
          ...current.where((c) => c.id != category.id && c.id != saved.id),
          saved,
        ]);
      }
    } catch (e) {
      if (mounted) state = AsyncValue.data(previous);
      rethrow;
    }
  }

  Future<void> updateCategory(CategoryModel category) async {
    final previous = state.asData?.value ?? const <CategoryModel>[];
    final optimistic = previous
        .map((c) => c.id == category.id ? category : c)
        .toList();
    if (mounted) state = AsyncValue.data(optimistic);

    // Segera perbarui nama kategori pada transaksi di memori agar seluruh layar sinkron instan
    _ref
        .read(transactionsProvider.notifier)
        .renameCategoryLocally(category.id, category.name);

    try {
      await _repository.updateCategory(category);
    } catch (e) {
      if (mounted) state = AsyncValue.data(previous);
      rethrow;
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    final previous = state.asData?.value ?? const <CategoryModel>[];
    final optimistic = previous.where((c) => c.id != categoryId).toList();
    if (mounted) state = AsyncValue.data(optimistic);

    try {
      await _repository.deleteCategory(categoryId);
    } catch (e) {
      if (mounted) state = AsyncValue.data(previous);
      rethrow;
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }
}

final categoriesProvider = StateNotifierProvider<CategoriesNotifier, AsyncValue<List<CategoryModel>>>((ref) {
  final repo = ref.watch(categoryRepositoryProvider);
  final userId = ref.watch(authStateProvider.select((s) => s.asData?.value?.id));

  return CategoriesNotifier(repo, userId, ref);
});
