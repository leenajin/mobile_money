import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/analysis.dart';
import '../logic/app_state.dart';
import '../logic/ledger_rows.dart';
import '../widgets/month_tab_bar.dart';

const _headerColor = Color(0xFFFFF3C4);
const _gridColor = Color(0xFFD0D0D0);

/// 모아보기: 결제 수단별/분류별 월간 합계 표
class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  Widget _cell(String text,
      {int flex = 1,
      Color? bg,
      bool bold = false,
      bool right = false,
      bool center = false}) {
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('모아보기'),
          bottom: const TabBar(tabs: [Tab(text: '결제 수단'), Tab(text: '분류')]),
        ),
        body: TabBarView(children: [
          _table('결제 수단',
              aggregateTotals(expenses, (e) => e.paymentMethodId, paymentNames)),
          _table('분류',
              aggregateTotals(expenses, (e) => e.categoryId, categoryNames)),
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
