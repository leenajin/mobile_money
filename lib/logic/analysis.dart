import '../models/expense.dart';

class AnalysisEntry {
  final String name;
  final int total;
  final int? id; // 원본 분류/결제수단 id ('그 외' 등 합성 항목은 null)
  const AnalysisEntry(this.name, this.total, {this.id});
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
        AnalysisEntry(names[entry.key] ?? '', entry.value, id: entry.key),
  ]..sort((a, b) => b.total.compareTo(a.total));
  return entries;
}

/// 날짜('yyyy-MM-dd') → 그날 지출 합계
Map<String, int> dailyTotals(List<Expense> expenses) {
  final totals = <String, int>{};
  for (final e in expenses) {
    totals[e.date] = (totals[e.date] ?? 0) + e.amount;
  }
  return totals;
}

/// 금액이 가장 큰 단일 지출 (없으면 null)
Expense? maxExpense(List<Expense> expenses) {
  Expense? max;
  for (final e in expenses) {
    if (max == null || e.amount > max.amount) max = e;
  }
  return max;
}

/// 지출 합계가 가장 큰 날 (없으면 null)
MapEntry<String, int>? maxDay(Map<String, int> daily) {
  MapEntry<String, int>? max;
  for (final entry in daily.entries) {
    if (max == null || entry.value > max.value) max = entry;
  }
  return max;
}

/// 원형 그래프 조각: 상위 maxSlices-1개 + 나머지는 '그 외'로 묶는다.
List<AnalysisEntry> pieSlices(List<AnalysisEntry> entries,
    {int maxSlices = 8}) {
  if (entries.length <= maxSlices) return entries;
  final top = entries.take(maxSlices - 1).toList();
  final restTotal =
      entries.skip(maxSlices - 1).fold(0, (sum, e) => sum + e.total);
  return [...top, AnalysisEntry('그 외', restTotal)];
}
