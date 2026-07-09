import 'package:flutter/material.dart';
import '../logic/ledger_rows.dart';
import '../models/expense.dart';

const _headerColor = Color(0xFFFFF3C4);
const _gridColor = Color(0xFFD0D0D0);
const _colFlexes = [15, 16, 12, 20, 16, 15];

class LedgerTable extends StatelessWidget {
  const LedgerTable({
    super.key,
    required this.rows,
    required this.monthTotal,
    required this.categoryNames,
    required this.paymentNames,
    required this.onRowTap,
  });

  final List<LedgerRow> rows;
  final int monthTotal;
  final Map<int, String> categoryNames;
  final Map<int, String> paymentNames;
  final void Function(Expense) onRowTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _headerRow(),
        Expanded(
          child: ListView.builder(
            itemCount: rows.length + 1,
            itemBuilder: (context, i) =>
                i < rows.length ? _dataRow(i) : _totalRow(),
          ),
        ),
      ],
    );
  }

  Widget _cell(int col, String text,
      {Color? bg, bool bold = false, bool right = false, bool center = false}) {
    return Expanded(
      flex: _colFlexes[col],
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

  Widget _headerRow() => Row(children: [
        _cell(0, '날짜', bg: _headerColor, bold: true, center: true),
        _cell(1, '지출처', bg: _headerColor, bold: true, center: true),
        _cell(2, '분류', bg: _headerColor, bold: true, center: true),
        _cell(3, '상세', bg: _headerColor, bold: true, center: true),
        _cell(4, '금액', bg: _headerColor, bold: true, center: true),
        _cell(5, '비고', bg: _headerColor, bold: true, center: true),
      ]);

  Widget _dataRow(int i) {
    final row = rows[i];
    final e = row.expense;
    return InkWell(
      onTap: () => onRowTap(e),
      child: Row(children: [
        _cell(0, row.showDate ? formatSheetDate(e.date) : ''),
        _cell(1, paymentNames[e.paymentMethodId] ?? ''),
        _cell(2, categoryNames[e.categoryId] ?? ''),
        _cell(3, e.detail),
        _cell(4, formatWon(e.amount), right: true),
        _cell(5, e.memo ?? ''),
      ]),
    );
  }

  Widget _totalRow() => Row(children: [
        _cell(0, '', bg: _headerColor),
        _cell(1, '', bg: _headerColor),
        _cell(2, '', bg: _headerColor),
        _cell(3, '합계', bg: _headerColor, bold: true),
        _cell(4, formatWon(monthTotal), bg: _headerColor, bold: true, right: true),
        _cell(5, '', bg: _headerColor),
      ]);
}
