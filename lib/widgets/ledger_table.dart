import 'package:flutter/material.dart';
import '../logic/ledger_rows.dart';
import '../models/expense.dart';

const _headerColor = Color(0xFFFFF3C4);
const _gridColor = Color(0xFFD0D0D0);
const _colFlexes = [15, 16, 12, 28, 13];

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
      ]);

  // 상세 칸: 메모가 있으면 오른쪽 끝에 ⓘ 아이콘, 탭하면 메모 툴팁 표시
  Widget _detailCell(Expense e) {
    return Expanded(
      flex: _colFlexes[3],
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(color: _gridColor),
            bottom: BorderSide(color: _gridColor),
          ),
        ),
        child: Row(children: [
          Expanded(
            child: Text(e.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10)),
          ),
          if (e.memo != null && e.memo!.isNotEmpty)
            Tooltip(
              message: e.memo!,
              triggerMode: TooltipTriggerMode.tap,
              child: const Icon(Icons.info_outline,
                  size: 12, color: Colors.blueGrey),
            ),
        ]),
      ),
    );
  }

  Widget _dataRow(int i) {
    final row = rows[i];
    final e = row.expense;
    return InkWell(
      onTap: () => onRowTap(e),
      child: Row(children: [
        _cell(0, row.showDate ? formatSheetDate(e.date) : ''),
        _cell(1, paymentNames[e.paymentMethodId] ?? ''),
        _cell(2, categoryNames[e.categoryId] ?? ''),
        _detailCell(e),
        _cell(4, formatWon(e.amount), right: true),
      ]),
    );
  }

  // 합계 행: 왼쪽에 '합계', 나머지 네 칸은 병합해 오른쪽 끝에 합계 금액
  Widget _totalRow() => Row(children: [
        _cell(0, '합계', bg: _headerColor, bold: true, center: true),
        Expanded(
          flex: _colFlexes[1] + _colFlexes[2] + _colFlexes[3] + _colFlexes[4],
          child: Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            alignment: Alignment.centerRight,
            decoration: const BoxDecoration(
              color: _headerColor,
              border: Border(
                right: BorderSide(color: _gridColor),
                bottom: BorderSide(color: _gridColor),
              ),
            ),
            child: Text(formatWon(monthTotal),
                maxLines: 1,
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ),
      ]);
}
