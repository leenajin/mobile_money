import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile_money/data/app_database.dart';
import 'package:mobile_money/logic/app_state.dart';
import 'package:mobile_money/models/expense.dart';
import 'package:mobile_money/screens/expense_sheet.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late AppState state;

  setUp(() async {
    db = await openAppDatabase(
        factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    state = AppState(db, '2025-09-15');
    await state.init();
  });
  tearDown(() => db.close());

  Widget host({Expense? existing}) => ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showExpenseSheet(context, existing: existing),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );

  testWidgets('추가: 금액/상세 입력 후 저장하면 거래가 생긴다', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('detail')), '점심');
    await tester.enterText(find.byKey(const Key('amount')), '12000');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(state.rows.single.expense.detail, '점심');
    expect(state.rows.single.expense.amount, 12000);
    expect(state.rows.single.expense.date, '2025-09-15');
  });

  testWidgets('금액 없이 저장하면 오류 표시, 저장 안 됨', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('금액을 입력하세요'), findsOneWidget);
    expect(state.rows, isEmpty);
  });

  testWidgets('수정: 기존 값이 채워지고 저장 시 갱신', (tester) async {
    await state.addExpense(Expense(
        date: '2025-09-01',
        paymentMethodId: state.paymentMethods.first.id!,
        categoryId: state.categories.first.id!,
        detail: '점심', amount: 12000));
    final saved = state.rows.single.expense;
    await tester.pumpWidget(host(existing: saved));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '점심'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('amount')), '9000');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(state.rows.single.expense.amount, 9000);
  });

  testWidgets('삭제: 확인 후 거래 제거', (tester) async {
    await state.addExpense(Expense(
        date: '2025-09-01',
        paymentMethodId: state.paymentMethods.first.id!,
        categoryId: state.categories.first.id!,
        detail: '점심', amount: 12000));
    final saved = state.rows.single.expense;
    await tester.pumpWidget(host(existing: saved));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(state.rows, isEmpty);
  });
}
