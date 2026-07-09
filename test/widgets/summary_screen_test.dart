import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile_money/data/app_database.dart';
import 'package:mobile_money/logic/app_state.dart';
import 'package:mobile_money/models/expense.dart';
import 'package:mobile_money/screens/summary_screen.dart';

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

  Widget host() => ChangeNotifierProvider.value(
      value: state, child: const MaterialApp(home: SummaryScreen()));

  testWidgets('결제 수단 탭: 거래 있는 결제 수단만 합산 표시', (tester) async {
    final meal = state.categories.firstWhere((c) => c.name == '식사');
    final cafe = state.categories.firstWhere((c) => c.name == '카페');
    final cash = state.paymentMethods.first;
    await state.addExpense(Expense(
        date: '2025-09-01',
        paymentMethodId: cash.id!,
        categoryId: meal.id!,
        amount: 12000));
    await state.addExpense(Expense(
        date: '2025-09-02',
        paymentMethodId: cash.id!,
        categoryId: cafe.id!,
        amount: 4500));

    await tester.pumpWidget(host());
    // 결제 수단 탭 (기본): 현금 16,500 합산
    expect(find.text('현금'), findsOneWidget);
    expect(find.text('₩16,500'), findsOneWidget);
  });

  testWidgets('분류 탭: 거래 없는 분류는 나오지 않는다', (tester) async {
    final meal = state.categories.firstWhere((c) => c.name == '식사');
    final cash = state.paymentMethods.first;
    await state.addExpense(Expense(
        date: '2025-09-01',
        paymentMethodId: cash.id!,
        categoryId: meal.id!,
        amount: 12000));

    await tester.pumpWidget(host());
    await tester.tap(find.text('분류').first); // 탭 전환
    await tester.pumpAndSettle();

    expect(find.text('식사'), findsOneWidget);
    expect(find.text('₩12,000'), findsOneWidget);
    expect(find.text('카페'), findsNothing); // 거래 없는 분류 미표시
    expect(find.text('편의점'), findsNothing);
  });

  testWidgets('분류를 탭하면 그 분류의 거래만 모은 장부 그리드가 나온다', (tester) async {
    final meal = state.categories.firstWhere((c) => c.name == '식사');
    final cafe = state.categories.firstWhere((c) => c.name == '카페');
    final cash = state.paymentMethods.first;
    await state.addExpense(Expense(
        date: '2025-09-01',
        paymentMethodId: cash.id!,
        categoryId: meal.id!,
        detail: '점심',
        amount: 12000));
    await state.addExpense(Expense(
        date: '2025-09-02',
        paymentMethodId: cash.id!,
        categoryId: cafe.id!,
        detail: '라떼',
        amount: 4500));

    await tester.pumpWidget(host());
    await tester.tap(find.text('분류').first);
    await tester.pumpAndSettle();

    // 분류 합계 표에서 식사 탭
    await tester.tap(find.text('식사'));
    await tester.pumpAndSettle();

    // 메인과 같은 장부 그리드: 헤더 + 식사 거래만
    expect(find.text('분류: 식사'), findsOneWidget);
    expect(find.text('날짜'), findsOneWidget); // 장부 헤더
    expect(find.text('점심'), findsOneWidget);
    expect(find.text('₩12,000'), findsNWidgets(2)); // 거래 행 + 합계 행
    expect(find.text('라떼'), findsNothing); // 다른 분류 거래 제외
    expect(find.text('합계'), findsOneWidget);

    // 뒤로 버튼 → 합계 표 복귀
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('식사'), findsOneWidget);
    expect(find.text('카페'), findsOneWidget);
    expect(find.text('날짜'), findsNothing);
  });
}
