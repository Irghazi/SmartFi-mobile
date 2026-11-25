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

  CategoriesNotifier(this._repository, this._userId, this._ref)
      : super(_userId == null
            ? const AsyncValue.data([])
            : const AsyncValue.loading()) {
    if (_userId != null) {
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
    await _repository.addCategory(category);
    await loadCategories(showLoading: false);
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _repository.updateCategory(category);
    await loadCategories(showLoading: false);
    await _ref.read(transactionsProvider.notifier).loadTransactions(showLoading: false);
  }

  Future<void> deleteCategory(String categoryId) async {
    await _repository.deleteCategory(categoryId);
    await loadCategories(showLoading: false);
  }
}

final categoriesProvider = StateNotifierProvider<CategoriesNotifier, AsyncValue<List<CategoryModel>>>((ref) {
  final repo = ref.watch(categoryRepositoryProvider);
  final userId = ref.watch(authStateProvider.select((s) => s.asData?.value?.id));

  return CategoriesNotifier(repo, userId, ref);
});
