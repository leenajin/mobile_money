import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/analysis.dart';
import '../logic/app_state.dart';
import '../logic/ledger_rows.dart';
import '../widgets/ledger_table.dart';
import '../widgets/month_tab_bar.dart';
import 'expense_sheet.dart';

const _headerColor = Color(0xFFFFF3C4);
const _gridColor = Color(0xFFD0D0D0);

/// 모아보기: 결제 수단별/분류별 월간 합계 표.
/// 분류 탭에서 분류를 탭하면 그 분류의 거래만 모은 장부 그리드로 전환된다.
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  int? _filterCategoryId; // null이면 분류 합계 표, 아니면 해당 분류 상세 그리드

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

  Widget _table(String label, List<AnalysisEntry> entries,
      {void Function(AnalysisEntry)? onRowTap}) {
    return Column(children: [
      Row(children: [
        _cell(label, flex: 2, bg: _headerColor, bold: true, center: true),
        _cell('금액', flex: 2, bg: _headerColor, bold: true, center: true),
        _cell('비고', flex: 3, bg: _headerColor, bold: true, center: true),
      ]),
      Expanded(
        child: ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final row = Row(children: [
              _cell(entries[i].name, flex: 2),
              _cell(formatWon(entries[i].total), flex: 2, right: true),
              _cell('', flex: 3),
            ]);
            if (onRowTap == null) return row;
            return InkWell(onTap: () => onRowTap(entries[i]), child: row);
          },
        ),
      ),
    ]);
  }

  /// 선택한 분류의 거래만 모은 장부 그리드 (메인 화면과 같은 형식)
  Widget _categoryDetail(AppState state, Map<int, String> categoryNames,
      Map<int, String> paymentNames) {
    final filtered = [
      for (final r in state.rows)
        if (r.expense.categoryId == _filterCategoryId) r.expense
    ];
    final total = filtered.fold(0, (sum, e) => sum + e.amount);
    return Column(children: [
      Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, size: 18),
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() => _filterCategoryId = null),
        ),
        Text('분류: ${categoryNames[_filterCategoryId] ?? ''}',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
      Expanded(
        child: LedgerTable(
          rows: buildLedgerRows(filtered),
          monthTotal: total,
          categoryNames: categoryNames,
          paymentNames: paymentNames,
          onRowTap: (e) => showExpenseSheet(context, existing: e),
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
          _filterCategoryId == null
              ? _table(
                  '분류',
                  aggregateTotals(expenses, (e) => e.categoryId, categoryNames),
                  onRowTap: (entry) {
                    if (entry.id != null) {
                      setState(() => _filterCategoryId = entry.id);
                    }
                  },
                )
              : _categoryDetail(state, categoryNames, paymentNames),
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
