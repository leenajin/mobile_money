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

  test('일별 합계', () {
    final daily = dailyTotals([
      Expense(date: '2025-09-01', paymentMethodId: 1, categoryId: 1, amount: 1000),
      Expense(date: '2025-09-01', paymentMethodId: 1, categoryId: 2, amount: 2000),
      Expense(date: '2025-09-03', paymentMethodId: 1, categoryId: 1, amount: 500),
    ]);
    expect(daily, {'2025-09-01': 3000, '2025-09-03': 500});
  });

  test('가장 큰 지출과 가장 지출 많은 날', () {
    final expenses = [
      Expense(date: '2025-09-01', paymentMethodId: 1, categoryId: 1, amount: 1000),
      Expense(date: '2025-09-02', paymentMethodId: 1, categoryId: 1, amount: 5000, detail: '회식'),
      Expense(date: '2025-09-01', paymentMethodId: 1, categoryId: 2, amount: 4500),
    ];
    expect(maxExpense(expenses)!.detail, '회식');
    final md = maxDay(dailyTotals(expenses))!;
    expect(md.key, '2025-09-01'); // 1000+4500=5500 > 5000
    expect(md.value, 5500);
    expect(maxExpense([]), isNull);
    expect(maxDay({}), isNull);
  });

  test('파이 조각: 8개 초과면 상위 7개 + 그 외로 묶는다', () {
    final entries = [
      for (var i = 10; i >= 1; i--) AnalysisEntry('항목$i', i * 1000),
    ];
    final slices = pieSlices(entries);
    expect(slices.length, 8);
    expect(slices.last.name, '그 외');
    expect(slices.last.total, 3000 + 2000 + 1000);
    // 8개 이하면 그대로
    expect(pieSlices(entries.take(5).toList()).length, 5);
  });
}
