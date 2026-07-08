import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/app_state.dart';
import '../models/expense.dart';
import '../widgets/ledger_table.dart';
import '../widgets/month_tab_bar.dart';
import 'expense_sheet.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  void _openExpenseSheet(BuildContext context, {Expense? existing}) {
    showExpenseSheet(context, existing: existing);
  }

  void _openMenu(BuildContext context) {
    // Task 10에서 분류/카드/설정 이동 메뉴로 교체
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: LedgerTable(
          rows: state.rows,
          monthTotal: state.monthTotal,
          categoryNames: {for (final c in state.categories) c.id!: c.name},
          paymentNames: {for (final p in state.paymentMethods) p.id!: p.name},
          onRowTap: (e) => _openExpenseSheet(context, existing: e),
        ),
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
