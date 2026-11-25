import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String userId;
  final String type; // 'income' | 'expense'
  final int nominal;
  final String description;
  final String? categoryId;
  final String categoryName;
  final DateTime transactionDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.nominal,
    required this.description,
    this.categoryId,
    required this.categoryName,
    required this.transactionDate,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';

  TransactionModel copyWith({
    String? id,
    String? userId,
    String? type,
    int? nominal,
    String? description,
    String? categoryId,
    String? categoryName,
    DateTime? transactionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      nominal: nominal ?? this.nominal,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'nominal': nominal,
      'description': description,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'transactionDate': transactionDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value, [DateTime? defaultVal]) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? (defaultVal ?? DateTime.now());
      if (value is DateTime) return value;
      return defaultVal ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      if (value is DateTime) return value;
      return null;
    }

    // Menangani kompatibilitas nominal atau amount dari schema web
    final rawNominal = json['nominal'] ?? json['amount'];
    final nominalVal = (rawNominal is num)
        ? rawNominal.toInt()
        : int.tryParse(rawNominal?.toString() ?? '0') ?? 0;

    final rawTxDate = json['transactionDate'] ?? json['transaction_date'] ?? json['created_at'];
    final txDate = parseDate(rawTxDate);

    final rawCreatedAt = json['createdAt'] ?? json['created_at'];
    final createdAt = parseDate(rawCreatedAt);

    return TransactionModel(
      id: json['id'] as String? ?? 'tx_${DateTime.now().millisecondsSinceEpoch}',
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      type: json['type'] as String? ?? 'expense',
      nominal: nominalVal,
      description: json['description'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? json['category_id'] as String?,
      categoryName: json['categoryName'] as String? ?? json['category'] as String? ?? 'Lainnya',
      transactionDate: txDate,
      createdAt: createdAt,
      updatedAt: parseNullableDate(json['updatedAt']),
    );
  }
}

