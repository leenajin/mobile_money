import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/app_state.dart';
import '../models/expense.dart';
import '../widgets/ledger_table.dart';
import '../widgets/month_tab_bar.dart';
import 'analysis_screen.dart';
import 'expense_sheet.dart';
import 'category_screen.dart';
import 'payment_method_screen.dart';
import 'settings_screen.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  void _openExpenseSheet(BuildContext context, {Expense? existing}) {
    showExpenseSheet(context, existing: existing);
  }

  void _openMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('분석'),
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AnalysisScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('분류 관리'),
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CategoryScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.credit_card),
            title: const Text('카드 관리'),
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const PaymentMethodScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('설정'),
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ]),
      ),
    );
  }

  Widget _topButton(BuildContext context, String label,
      {VoidCallback? onPressed}) {
    return OutlinedButton(
      onPressed: onPressed ?? () {}, // 기능 미정 버튼은 아직 동작 없음
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        textStyle: const TextStyle(fontSize: 12),
      ),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // 상단 버튼 4개 (분석 외 나머지는 자리만 — 기능 미정)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(children: [
              Expanded(child: _topButton(context, '분석', onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AnalysisScreen()));
              })),
              const SizedBox(width: 6),
              Expanded(child: _topButton(context, '버튼2')),
              const SizedBox(width: 6),
              Expanded(child: _topButton(context, '버튼3')),
              const SizedBox(width: 6),
              Expanded(child: _topButton(context, '버튼4')),
            ]),
          ),
          Expanded(
            child: LedgerTable(
              rows: state.rows,
              monthTotal: state.monthTotal,
              categoryNames: {for (final c in state.categories) c.id!: c.name},
              paymentNames: {
                for (final p in state.paymentMethods) p.id!: p.name
              },
              onRowTap: (e) => _openExpenseSheet(context, existing: e),
              scrollToDate: state.pendingScrollDate,
              onScrollHandled: state.clearPendingScroll,
            ),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openExpenseSheet(context),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: MonthTabBar(
        months: state.months,
        selected: state.selectedMonth,
        onSelect: (m) => context.read<AppState>().selectMonth(m),
        onMenuTap: () => _openMenu(context),
      ),
    );
  }
}
