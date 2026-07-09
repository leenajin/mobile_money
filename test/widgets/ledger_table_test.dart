import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_money/logic/ledger_rows.dart';
import 'package:mobile_money/models/expense.dart';
import 'package:mobile_money/widgets/ledger_table.dart';

void main() {
  final expenses = [
    const Expense(id: 1, date: '2025-09-01', paymentMethodId: 1,
        categoryId: 1, detail: '점심', amount: 12000),
    const Expense(id: 2, date: '2025-09-01', paymentMethodId: 1,
        categoryId: 2, detail: '커피', amount: 4500, memo: '반값할인'),
    const Expense(id: 3, date: '2025-09-02', paymentMethodId: 2,
        categoryId: 1, detail: '저녁', amount: 20000),
  ];

  Widget build({void Function(Expense)? onTap}) => MaterialApp(
        home: Scaffold(
          body: LedgerTable(
            rows: buildLedgerRows(expenses),
            monthTotal: 36500,
            categoryNames: const {1: '식사', 2: '카페'},
            paymentNames: const {1: 'KB 다담카드', 2: '현금'},
            onRowTap: onTap ?? (_) {},
          ),
        ),
      );

  testWidgets('헤더/데이터/합계가 표시된다', (tester) async {
    await tester.pumpWidget(build());
    for (final h in ['날짜', '결제 수단', '분류', '상세', '금액']) {
      expect(find.text(h), findsOneWidget);
    }
    expect(find.text('점심'), findsOneWidget);
    expect(find.text('₩12,000'), findsOneWidget);
    expect(find.text('합계'), findsOneWidget);
    expect(find.text('₩36,500'), findsOneWidget);
  });

  testWidgets('메모가 있는 행만 ⓘ 아이콘, 탭하면 툴팁으로 메모 표시', (tester) async {
    await tester.pumpWidget(build());
    // 메모 텍스트는 표에 직접 보이지 않는다
    expect(find.text('반값할인'), findsNothing);
    // 메모가 있는 거래(커피)에만 아이콘 하나
    final icon = find.byIcon(Icons.info_outline);
    expect(icon, findsOneWidget);
    // 아이콘 탭 → 툴팁으로 메모 표시
    await tester.tap(icon);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('반값할인'), findsOneWidget);
  });

  testWidgets('같은 날짜는 첫 행만 날짜 표시', (tester) async {
    await tester.pumpWidget(build());
    expect(find.text('2025.09.01'), findsOneWidget); // 두 거래지만 한 번만
    expect(find.text('2025.09.02'), findsOneWidget);
  });

  testWidgets('행 탭 시 해당 거래 전달', (tester) async {
    Expense? tapped;
    await tester.pumpWidget(build(onTap: (e) => tapped = e));
    await tester.tap(find.text('커피'));
    expect(tapped?.id, 2);
  });
}
