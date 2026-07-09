import 'package:flutter/material.dart';
import '../logic/analysis.dart';
import '../logic/ledger_rows.dart';
import '../models/expense.dart';

/// 소비 패턴 분석 (그래프 탭에서 분리)
class AnalysisPatternTab extends StatelessWidget {
  const AnalysisPatternTab({
    super.key,
    required this.expenses,
    required this.categoryEntries,
    required this.paymentEntries,
    required this.categoryNames,
  });

  final List<Expense> expenses;
  final List<AnalysisEntry> categoryEntries; // 금액 큰 순
  final List<AnalysisEntry> paymentEntries;
  final Map<int, String> categoryNames;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return const Center(child: Text('이번 달 지출이 없습니다'));
    }
    final total = expenses.fold(0, (sum, e) => sum + e.amount);
    final daily = dailyTotals(expenses);
    final biggest = maxExpense(expenses)!;
    final busiest = maxDay(daily)!;
    final dailyAverage = total ~/ daily.length;

    return ListView(padding: const EdgeInsets.all(16), children: [
      _statTile(
          '가장 큰 지출',
          '${biggest.detail.isEmpty ? categoryNames[biggest.categoryId] ?? '' : biggest.detail} · ${formatSheetDate(biggest.date)}',
          formatWon(biggest.amount)),
      _statTile('가장 지출이 많았던 날', formatSheetDate(busiest.key),
          formatWon(busiest.value)),
      if (categoryEntries.isNotEmpty)
        _statTile(
            '가장 많이 쓴 분류',
            '${categoryEntries.first.name} (${(categoryEntries.first.total * 100 / total).toStringAsFixed(1)}%)',
            formatWon(categoryEntries.first.total)),
      if (paymentEntries.isNotEmpty)
        _statTile(
            '가장 많이 쓴 결제 수단',
            '${paymentEntries.first.name} (${(paymentEntries.first.total * 100 / total).toStringAsFixed(1)}%)',
            formatWon(paymentEntries.first.total)),
      _statTile('하루 평균 지출 (지출 있는 날 기준)', '${daily.length}일 지출',
          formatWon(dailyAverage)),
      _statTile('거래 건수', '', '${expenses.length}건'),
    ]);
  }

  Widget _statTile(String title, String subtitle, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 12)),
            if (subtitle.isNotEmpty)
              Text(subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ]),
        ),
        Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
