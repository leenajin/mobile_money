import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../logic/analysis.dart';
import '../logic/ledger_rows.dart';
import '../models/expense.dart';

/// 검증된 카테고리 팔레트 (dataviz 기본, 고정 순서)
const chartPalette = [
  Color(0xFF2A78D6), // blue
  Color(0xFF1BAF7A), // aqua
  Color(0xFFEDA100), // yellow
  Color(0xFF008300), // green
  Color(0xFF4A3AA7), // violet
  Color(0xFFE34948), // red
  Color(0xFFE87BA4), // magenta
  Color(0xFFEB6834), // orange
];
const _otherColor = Color(0xFF9E9E9E); // '그 외' 전용 회색

class AnalysisGraphTab extends StatelessWidget {
  const AnalysisGraphTab({
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

  Color _sliceColor(int index, List<AnalysisEntry> slices) {
    if (slices[index].name == '그 외') return _otherColor;
    return chartPalette[index % chartPalette.length];
  }

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return const Center(child: Text('이번 달 지출이 없습니다'));
    }
    final total = expenses.fold(0, (sum, e) => sum + e.amount);
    final slices = pieSlices(categoryEntries);
    final daily = dailyTotals(expenses);
    final biggest = maxExpense(expenses)!;
    final busiest = maxDay(daily)!;
    final dailyAverage = total ~/ daily.length;

    return ListView(padding: const EdgeInsets.all(16), children: [
      // 분류별 사용률 도넛 (중앙 = 총 지출)
      SizedBox(
        height: 200,
        child: Stack(alignment: Alignment.center, children: [
          PieChart(PieChartData(
            centerSpaceRadius: 60,
            sectionsSpace: 2, // 조각 사이 2px 간격
            sections: [
              for (var i = 0; i < slices.length; i++)
                PieChartSectionData(
                  value: slices[i].total.toDouble(),
                  color: _sliceColor(i, slices),
                  radius: 36,
                  showTitle: false,
                ),
            ],
          )),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('총 지출',
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            Text(formatWon(total),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      // 범례: 색 점 + 이름 + 비율 + 금액
      for (var i = 0; i < slices.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: _sliceColor(i, slices), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(slices[i].name,
                    style: const TextStyle(fontSize: 12))),
            Text('${(slices[i].total * 100 / total).toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(width: 12),
            SizedBox(
              width: 90,
              child: Text(formatWon(slices[i].total),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12)),
            ),
          ]),
        ),
      const Divider(height: 32),
      // 소비 패턴 분석
      Text('소비 패턴',
          style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
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
            '가장 많이 쓴 지출처',
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
