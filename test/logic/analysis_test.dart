import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_money/logic/analysis.dart';
import 'package:mobile_money/models/expense.dart';

Expense e({required int payment, required int category, required int amount}) =>
    Expense(
        date: '2025-09-01',
        paymentMethodId: payment,
        categoryId: category,
        amount: amount);

void main() {
  final names = {1: '식사', 2: '카페', 3: '간식'};

  test('같은 항목은 합산되고 금액 큰 순으로 정렬된다', () {
    final result = aggregateTotals(
      [
        e(payment: 1, category: 1, amount: 12000),
        e(payment: 1, category: 2, amount: 4500),
        e(payment: 1, category: 1, amount: 8000),
      ],
      (x) => x.categoryId,
      names,
    );
    expect(result.length, 2);
    expect(result[0].name, '식사');
    expect(result[0].total, 20000);
    expect(result[1].name, '카페');
    expect(result[1].total, 4500);
  });

  test('거래가 없는 항목은 나오지 않는다', () {
    final result = aggregateTotals(
      [e(payment: 1, category: 1, amount: 1000)],
      (x) => x.categoryId,
      names, // 카페, 간식은 등록돼 있지만 거래 없음
    );
    expect(result.map((r) => r.name).toList(), ['식사']);
  });

  test('빈 목록이면 빈 결과', () {
    expect(aggregateTotals([], (x) => x.categoryId, names), isEmpty);
  });
}
