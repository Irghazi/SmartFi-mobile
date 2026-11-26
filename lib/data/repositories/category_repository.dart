import '../models/category_model.dart';

abstract class CategoryRepository {
  Future<List<CategoryModel>> getCategories(String userId);

  /// Stream real-time kategori (opsional, diimplementasikan oleh Cloud Firestore)
  Stream<List<CategoryModel>>? watchCategories(String userId) => null;

  Future<CategoryModel> addCategory(CategoryModel category);
  Future<void> updateCategory(CategoryModel category);
  Future<void> deleteCategory(String categoryId);
}
