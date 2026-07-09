import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/analysis.dart';
import '../logic/app_state.dart';
import '../logic/ledger_rows.dart';
import '../widgets/month_tab_bar.dart';
import 'analysis_calendar_tab.dart';
import 'analysis_graph_tab.dart';

const _headerColor = Color(0xFFFFF3C4);
const _gridColor = Color(0xFFD0D0D0);

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  Widget _cell(String text,
      {int flex = 1, Color? bg, bool bold = false, bool right = false, bool center = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        alignment: center
            ? Alignment.center
            : (right ? Alignment.centerRight : Alignment.centerLeft),
        decoration: BoxDecoration(
          color: bg,
          border: const Border(
            right: BorderSide(color: _gridColor),
            bottom: BorderSide(color: _gridColor),
          ),
        ),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _table(String label, List<AnalysisEntry> entries) {
    return Column(children: [
      Row(children: [
        _cell(label, flex: 2, bg: _headerColor, bold: true, center: true),
        _cell('금액', flex: 2, bg: _headerColor, bold: true, center: true),
        _cell('비고', flex: 3, bg: _headerColor, bold: true, center: true),
      ]),
      Expanded(
        child: ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, i) => Row(children: [
            _cell(entries[i].name, flex: 2),
            _cell(formatWon(entries[i].total), flex: 2, right: true),
            _cell('', flex: 3),
          ]),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final expenses = [for (final r in state.rows) r.expense];
    final paymentNames = {for (final p in state.paymentMethods) p.id!: p.name};
    final categoryNames = {for (final c in state.categories) c.id!: c.name};

    final paymentEntries =
        aggregateTotals(expenses, (e) => e.paymentMethodId, paymentNames);
    final categoryEntries =
        aggregateTotals(expenses, (e) => e.categoryId, categoryNames);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('분석'),
          bottom: const TabBar(tabs: [
            Tab(text: '결제 수단'),
            Tab(text: '분류'),
            Tab(text: '그래프'),
            Tab(text: '달력'),
          ]),
        ),
        body: TabBarView(children: [
          _table('결제 수단', paymentEntries),
          _table('분류', categoryEntries),
          AnalysisGraphTab(
            expenses: expenses,
            categoryEntries: categoryEntries,
            paymentEntries: paymentEntries,
            categoryNames: categoryNames,
          ),
          AnalysisCalendarTab(
            yearMonth: state.selectedMonth,
            daily: dailyTotals(expenses),
            onDayTap: (date) {
              context.read<AppState>().requestScrollTo(date);
              Navigator.pop(context); // 메인 장부로 복귀 → 해당 날짜로 스크롤
            },
          ),
        ]),
        bottomNavigationBar: MonthTabBar(
          months: state.months,
          selected: state.selectedMonth,
          onSelect: (m) => context.read<AppState>().selectMonth(m),
        ),
      ),
    );
  }
}
