import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile_money/data/app_database.dart';
import 'package:mobile_money/logic/app_state.dart';
import 'package:mobile_money/models/expense.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late AppState state;

  setUp(() async {
    db = await openAppDatabase(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    state = AppState(db: db, today: '2025-09-15');
    await state.init();
  });
  tearDown(() => db.close());

  Expense e(String date, int amount) => Expense(
      date: date,
      paymentMethodId: state.paymentMethods.first.id!,
      categoryId: state.categories.first.id!,
      amount: amount);

  test('초기 상태: 현재 월 선택, 월 목록에 현재 월 포함', () {
    expect(state.selectedMonth, '2025-09');
    expect(state.months, ['2025-09']);
    expect(state.rows, isEmpty);
    expect(state.monthTotal, 0);
    expect(state.categories.length, 8);
    expect(state.paymentMethods.single.name, '현금');
  });

  test('거래 추가 시 행/합계/월 목록 갱신 + 알림', () async {
    var notified = 0;
    state.addListener(() => notified++);
    var hookCalled = 0;
    state.onDataChanged = () => hookCalled++;

    await state.addExpense(e('2025-09-01', 12000));
    await state.addExpense(e('2025-08-20', 5000)); // 과거 달
    expect(state.rows.length, 1); // 선택 월(9월) 것만
    expect(state.monthTotal, 12000);
    expect(state.months, ['2025-08', '2025-09']);
    expect(notified, greaterThanOrEqualTo(2));
    expect(hookCalled, 2);
  });

  test('월 전환', () async {
    await state.addExpense(e('2025-08-20', 5000));
    await state.selectMonth('2025-08');
    expect(state.rows.single.expense.amount, 5000);
    expect(state.monthTotal, 5000);
  });

  test('거래 수정/삭제', () async {
    await state.addExpense(e('2025-09-01', 12000));
    final saved = state.rows.single.expense;
    await state.updateExpense(saved.copyWith(amount: 9000));
    expect(state.monthTotal, 9000);
    await state.deleteExpense(saved.id!);
    expect(state.rows, isEmpty);
  });

  test('분류 추가/삭제 시 목록 갱신', () async {
    await state.addCategory('병원');
    expect(state.categories.map((c) => c.name), contains('병원'));
    final added = state.categories.firstWhere((c) => c.name == '병원');
    await state.removeCategory(added.id!);
    expect(state.categories.map((c) => c.name), isNot(contains('병원')));
  });
}
