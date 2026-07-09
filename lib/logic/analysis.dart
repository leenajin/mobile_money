import '../models/expense.dart';

class AnalysisEntry {
  final String name;
  final int total;
  const AnalysisEntry(this.name, this.total);
}

/// 거래 목록을 idOf 기준으로 묶어 금액 합계를 구한다.
/// 합계가 1원 이상인 항목만, 금액 큰 순으로 반환한다.
List<AnalysisEntry> aggregateTotals(List<Expense> expenses,
    int Function(Expense) idOf, Map<int, String> names) {
  final sums = <int, int>{};
  for (final e in expenses) {
    sums[idOf(e)] = (sums[idOf(e)] ?? 0) + e.amount;
  }
  final entries = [
    for (final entry in sums.entries)
      if (entry.value >= 1)
        AnalysisEntry(names[entry.key] ?? '', entry.value),
  ]..sort((a, b) => b.total.compareTo(a.total));
  return entries;
}
