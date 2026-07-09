import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/analysis.dart';
import '../logic/app_state.dart';
import '../widgets/month_tab_bar.dart';
import 'analysis_calendar_tab.dart';
import 'analysis_graph_tab.dart';
import 'analysis_pattern_tab.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

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
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('분석'),
          bottom: const TabBar(tabs: [
            Tab(text: '그래프'),
            Tab(text: '소비 패턴'),
            Tab(text: '달력'),
          ]),
        ),
        body: TabBarView(children: [
          AnalysisGraphTab(
            expenses: expenses,
            categoryEntries: categoryEntries,
            paymentEntries: paymentEntries,
            monthTotals: state.monthTotals,
          ),
          AnalysisPatternTab(
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
