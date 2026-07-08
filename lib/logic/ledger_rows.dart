import 'package:intl/intl.dart';
import '../models/expense.dart';

class LedgerRow {
  final Expense expense;
  final bool showDate;
  const LedgerRow(this.expense, {required this.showDate});
}

List<LedgerRow> buildLedgerRows(List<Expense> expenses) {
  final rows = <LedgerRow>[];
  String? prevDate;
  for (final e in expenses) {
    rows.add(LedgerRow(e, showDate: e.date != prevDate));
    prevDate = e.date;
  }
  return rows;
}

final _won = NumberFormat('#,###');

String formatWon(int amount) => '₩${_won.format(amount)}';

String formatSheetDate(String date) {
  final parts = date.split('-');
  return '${parts[0]}. ${int.parse(parts[1])}. ${int.parse(parts[2])}';
}

String monthLabel(String yearMonth) {
  final parts = yearMonth.split('-');
  return '${parts[0]}.${int.parse(parts[1])}';
}
