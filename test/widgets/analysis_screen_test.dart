import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile_money/data/app_database.dart';
import 'package:mobile_money/logic/app_state.dart';
import 'package:mobile_money/models/expense.dart';
import 'package:mobile_money/screens/analysis_screen.dart';

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
      value: state, child: const MaterialApp(home: AnalysisScreen()));

  testWidgets('지출처 탭: 거래 있는 지출처만 합산 표시', (tester) async {
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
    // 지출처 탭 (기본): 현금 16,500 합산
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

  testWidgets('그래프 탭: 총 지출과 소비 패턴 표시', (tester) async {
    final meal = state.categories.firstWhere((c) => c.name == '식사');
    final cafe = state.categories.firstWhere((c) => c.name == '카페');
    final cash = state.paymentMethods.first;
    await state.addExpense(Expense(
        date: '2025-09-01',
        paymentMethodId: cash.id!,
        categoryId: meal.id!,
        detail: '회식',
        amount: 30000));
    await state.addExpense(Expense(
        date: '2025-09-02',
        paymentMethodId: cash.id!,
        categoryId: cafe.id!,
        amount: 4500));

    await tester.pumpWidget(host());
    await tester.tap(find.text('그래프'));
    await tester.pumpAndSettle();

    expect(find.text('총 지출'), findsOneWidget);
    expect(find.text('₩34,500'), findsOneWidget);
    expect(find.text('가장 큰 지출'), findsOneWidget);
    expect(find.text('가장 지출이 많았던 날'), findsOneWidget);
    expect(find.textContaining('회식'), findsWidgets);
  });

  testWidgets('달력 탭: 지출 있는 날에 금액 표시', (tester) async {
    final meal = state.categories.firstWhere((c) => c.name == '식사');
    final cash = state.paymentMethods.first;
    await state.addExpense(Expense(
        date: '2025-09-05',
        paymentMethodId: cash.id!,
        categoryId: meal.id!,
        amount: 7000));

    await tester.pumpWidget(host());
    await tester.tap(find.text('달력'));
    await tester.pumpAndSettle();

    expect(find.text('7,000'), findsOneWidget);
    expect(find.text('일'), findsOneWidget); // 요일 헤더
    expect(find.text('30'), findsOneWidget); // 9월 마지막 날
  });
}
