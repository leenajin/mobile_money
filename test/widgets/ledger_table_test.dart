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
    for (final h in ['날짜', '지출처', '분류', '상세', '금액', '비고']) {
      expect(find.text(h), findsOneWidget);
    }
    expect(find.text('점심'), findsOneWidget);
    expect(find.text('₩12,000'), findsOneWidget);
    expect(find.text('반값할인'), findsOneWidget);
    expect(find.text('합계'), findsOneWidget);
    expect(find.text('₩36,500'), findsOneWidget);
  });

  testWidgets('같은 날짜는 첫 행만 날짜 표시', (tester) async {
    await tester.pumpWidget(build());
    expect(find.text('2025. 9. 1'), findsOneWidget); // 두 거래지만 한 번만
    expect(find.text('2025. 9. 2'), findsOneWidget);
  });

  testWidgets('행 탭 시 해당 거래 전달', (tester) async {
    Expense? tapped;
    await tester.pumpWidget(build(onTap: (e) => tapped = e));
    await tester.tap(find.text('커피'));
    expect(tapped?.id, 2);
  });
}
