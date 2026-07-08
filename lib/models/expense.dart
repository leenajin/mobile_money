class Expense {
  final int? id;
  final String date; // yyyy-MM-dd
  final int paymentMethodId;
  final int categoryId;
  final String detail;
  final int amount; // 원 단위
  final String? memo;

  const Expense({
    this.id,
    required this.date,
    required this.paymentMethodId,
    required this.categoryId,
    this.detail = '',
    required this.amount,
    this.memo,
  });

  Expense copyWith({
    int? id,
    String? date,
    int? paymentMethodId,
    int? categoryId,
    String? detail,
    int? amount,
    String? memo,
  }) =>
      Expense(
        id: id ?? this.id,
        date: date ?? this.date,
        paymentMethodId: paymentMethodId ?? this.paymentMethodId,
        categoryId: categoryId ?? this.categoryId,
        detail: detail ?? this.detail,
        amount: amount ?? this.amount,
        memo: memo ?? this.memo,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'date': date,
        'payment_method_id': paymentMethodId,
        'category_id': categoryId,
        'detail': detail,
        'amount': amount,
        'memo': memo,
      };

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
        id: m['id'] as int?,
        date: m['date'] as String,
        paymentMethodId: m['payment_method_id'] as int,
        categoryId: m['category_id'] as int,
        detail: (m['detail'] as String?) ?? '',
        amount: m['amount'] as int,
        memo: m['memo'] as String?,
      );
}
