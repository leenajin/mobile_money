import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
const _lineColor = Color(0xFF2A78D6); // 추이 선 (series-1 blue)

class AnalysisGraphTab extends StatefulWidget {
  const AnalysisGraphTab({
    super.key,
    required this.expenses,
    required this.categoryEntries,
    required this.paymentEntries,
    required this.monthTotals, // 'yyyy-MM' -> 합계 (오름차순 정렬 가정 아님)
  });

  final List<Expense> expenses;
  final List<AnalysisEntry> categoryEntries; // 금액 큰 순
  final List<AnalysisEntry> paymentEntries;
  final Map<String, int> monthTotals;

  @override
  State<AnalysisGraphTab> createState() => _AnalysisGraphTabState();
}

class _AnalysisGraphTabState extends State<AnalysisGraphTab> {
  bool byCategory = true; // true=분류별, false=결제 수단별

  Color _sliceColor(int index, List<AnalysisEntry> slices) {
    if (slices[index].name == '그 외') return _otherColor;
    return chartPalette[index % chartPalette.length];
  }

  @override
  Widget build(BuildContext context) {
    final expenses = widget.expenses;

    if (expenses.isEmpty) {
      return const Center(child: Text('이번 달 지출이 없습니다'));
    }
    final total = expenses.fold(0, (sum, e) => sum + e.amount);
    final slices =
        pieSlices(byCategory ? widget.categoryEntries : widget.paymentEntries);

    return ListView(padding: const EdgeInsets.all(16), children: [
      // 분류별/결제 수단별 전환 버튼
      Center(
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('분류별')),
            ButtonSegment(value: false, label: Text('결제 수단별')),
          ],
          selected: {byCategory},
          onSelectionChanged: (s) => setState(() => byCategory = s.first),
          style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12))),
        ),
      ),
      const SizedBox(height: 12),
      // 사용률 도넛 (중앙 = 총 지출)
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
      // 월별 소비금액 추이 (꺾은선)
      Text('월별 소비 추이', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 16),
      SizedBox(height: 180, child: _monthlyTrendChart()),
      const SizedBox(height: 8),
    ]);
  }

  Widget _monthlyTrendChart() {
    final months = widget.monthTotals.keys.toList()..sort();
    final spots = [
      for (var i = 0; i < months.length; i++)
        FlSpot(i.toDouble(), widget.monthTotals[months[i]]!.toDouble()),
    ];
    final maxY =
        spots.fold(0.0, (m, s) => s.y > m ? s.y : m) * 1.2 + 1; // 위 여백
    final compact = NumberFormat.compact(locale: 'ko');

    return LineChart(LineChartData(
      minY: 0,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (v) =>
            const FlLine(color: Color(0xFFE8E8E8), strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (v, meta) => Text(compact.format(v.toInt()),
                style: const TextStyle(fontSize: 9, color: Colors.grey)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (v, meta) {
              final i = v.toInt();
              if (i < 0 || i >= months.length || v != i.toDouble()) {
                return const SizedBox();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(monthLabel(months[i]),
                    style: const TextStyle(fontSize: 9, color: Colors.grey)),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touched) => [
            for (final t in touched)
              LineTooltipItem(
                  '${monthLabel(months[t.x.toInt()])}\n${formatWon(t.y.toInt())}',
                  const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false, // 꺾은선
          color: _lineColor,
          barWidth: 2,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, pct, bar, i) => FlDotCirclePainter(
                radius: 4, color: _lineColor, strokeColor: Colors.white),
          ),
        ),
      ],
    ));
  }
}
