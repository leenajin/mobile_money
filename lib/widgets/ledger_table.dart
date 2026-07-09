import 'package:flutter/material.dart';
import '../logic/ledger_rows.dart';
import '../models/expense.dart';

const _headerColor = Color(0xFFFFF3C4);
const _gridColor = Color(0xFFD0D0D0);
// [0]=날짜는 고정폭(_dateColWidth), 나머지가 남은 폭을 비율로 나눈다
const _dateColWidth = 62.0;
const _colFlexes = [0, 16, 12, 28, 13];

const _rowHeight = 26.0;

class LedgerTable extends StatefulWidget {
  const LedgerTable({
    super.key,
    required this.rows,
    required this.monthTotal,
    required this.categoryNames,
    required this.paymentNames,
    required this.onRowTap,
    this.scrollToDate, // 이 날짜의 첫 행으로 스크롤 (달력에서 이동 시)
    this.onScrollHandled, // 스크롤 처리 후 호출 (요청 클리어용)
  });

  final List<LedgerRow> rows;
  final int monthTotal;
  final Map<int, String> categoryNames;
  final Map<int, String> paymentNames;
  final void Function(Expense) onRowTap;
  final String? scrollToDate;
  final VoidCallback? onScrollHandled;

  @override
  State<LedgerTable> createState() => _LedgerTableState();
}

class _LedgerTableState extends State<LedgerTable> {
  final _controller = ScrollController();

  List<LedgerRow> get rows => widget.rows;
  int get monthTotal => widget.monthTotal;
  Map<int, String> get categoryNames => widget.categoryNames;
  Map<int, String> get paymentNames => widget.paymentNames;
  void Function(Expense) get onRowTap => widget.onRowTap;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _maybeScroll() {
    final target = widget.scrollToDate;
    if (target == null) return;
    final index = rows.indexWhere((r) => r.expense.date == target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (index >= 0 && _controller.hasClients) {
        _controller.animateTo(
          (index * _rowHeight).clamp(0.0, _controller.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      widget.onScrollHandled?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    _maybeScroll();
    return Column(
      children: [
        _headerRow(),
        Expanded(
          child: ListView.builder(
            controller: _controller,
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
    final content =
        _cellBox(text, bg: bg, bold: bold, right: right, center: center);
    if (col == 0) return SizedBox(width: _dateColWidth, child: content);
    return Expanded(flex: _colFlexes[col], child: content);
  }

  Widget _cellBox(String text,
      {Color? bg, bool bold = false, bool right = false, bool center = false}) {
    return Container(
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
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)));
  }

  Widget _headerRow() => Row(children: [
        _cell(0, '날짜', bg: _headerColor, bold: true, center: true),
        _cell(1, '결제 수단', bg: _headerColor, bold: true, center: true),
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
