import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_money/logic/ledger_rows.dart';
import 'package:mobile_money/models/expense.dart';

Expense e(String date) =>
    Expense(date: date, paymentMethodId: 1, categoryId: 1, amount: 1000);

void main() {
  test('같은 날짜가 이어지면 첫 행만 날짜를 표시한다', () {
    final rows = buildLedgerRows([
      e('2025-09-01'), e('2025-09-01'), e('2025-09-02'),
      e('2025-09-02'), e('2025-09-04'),
    ]);
    expect(rows.map((r) => r.showDate).toList(),
        [true, false, true, false, true]);
  });

  test('빈 목록이면 빈 행', () {
    expect(buildLedgerRows([]), isEmpty);
  });

  test('통화/날짜/월 포맷', () {
    expect(formatWon(9400), '₩9,400');
    expect(formatWon(3000000), '₩3,000,000');
    expect(formatWon(0), '₩0');
    expect(formatSheetDate('2025-09-01'), '2025. 9. 1');
    expect(formatSheetDate('2025-12-25'), '2025. 12. 25');
    expect(monthLabel('2025-09'), '2025.9');
  });
}
