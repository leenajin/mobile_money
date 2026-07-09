import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _gridColor = Color(0xFFD0D0D0);

/// 일별 지출 히트맵 램프 (dataviz 순차 팔레트: 파랑 한 색, 밝음→어두움)
const _heatRamp = [
  Color(0xFFCDE2FB), // 100
  Color(0xFF86B6EF), // 250
  Color(0xFF3987E5), // 400
  Color(0xFF1C5CAB), // 550
  Color(0xFF0D366B), // 700
];

class AnalysisCalendarTab extends StatelessWidget {
  const AnalysisCalendarTab({
    super.key,
    required this.yearMonth, // 'yyyy-MM'
    required this.daily, // 'yyyy-MM-dd' -> 합계
    this.onDayTap, // 지출 있는 날짜를 탭하면 호출 ('yyyy-MM-dd')
  });

  final String yearMonth;
  final Map<String, int> daily;
  final void Function(String date)? onDayTap;

  @override
  Widget build(BuildContext context) {
    final year = int.parse(yearMonth.substring(0, 4));
    final month = int.parse(yearMonth.substring(5, 7));
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leadingBlanks = DateTime(year, month, 1).weekday % 7; // 일요일=0
    final maxTotal =
        daily.values.isEmpty ? 0 : daily.values.reduce((a, b) => a > b ? a : b);
    final won = NumberFormat('#,###');

    Widget dayCell(int day) {
      final date = '$yearMonth-${day.toString().padLeft(2, '0')}';
      final total = daily[date];
      Color? bg;
      var textColor = Colors.black87;
      if (total != null && maxTotal > 0) {
        final step =
            ((total / maxTotal) * (_heatRamp.length - 1)).round();
        bg = _heatRamp[step];
        if (step >= 2) textColor = Colors.white; // 어두운 칸은 흰 글씨
      }
      final cell = Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: _gridColor, width: 0.5),
        ),
        padding: const EdgeInsets.all(2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$day', style: TextStyle(fontSize: 9, color: textColor)),
          const Spacer(),
          if (total != null)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(won.format(total),
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
            ),
        ]),
      );
      // 지출이 있는 날만 탭 가능 — 메인 장부의 해당 날짜로 이동
      if (total == null || onDayTap == null) return cell;
      return InkWell(onTap: () => onDayTap!(date), child: cell);
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(children: [
        Row(children: [
          for (final w in ['일', '월', '화', '수', '목', '금', '토'])
            Expanded(
              child: Center(
                child: Text(w,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: w == '일'
                            ? Colors.red[400]
                            : (w == '토' ? Colors.blue[400] : null))),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final rowCount = ((leadingBlanks + daysInMonth) / 7).ceil();
            final cellHeight = constraints.maxHeight / rowCount;
            final cells = [
              for (var i = 0; i < leadingBlanks; i++) const SizedBox(),
              for (var day = 1; day <= daysInMonth; day++) dayCell(day),
            ];
            while (cells.length % 7 != 0) {
              cells.add(const SizedBox());
            }
            return Column(children: [
              for (var r = 0; r < rowCount; r++)
                SizedBox(
                  height: cellHeight,
                  child: Row(children: [
                    for (var c = 0; c < 7; c++)
                      Expanded(child: cells[r * 7 + c]),
                  ]),
                ),
            ]);
          }),
        ),
      ]),
    );
  }
}
