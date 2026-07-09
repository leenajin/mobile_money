import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile_money/data/app_database.dart';
import 'package:mobile_money/data/expense_repository.dart';
import 'package:mobile_money/models/expense.dart';

Expense e(String date, int amount, {String detail = ''}) => Expense(
    date: date, paymentMethodId: 1, categoryId: 1, detail: detail, amount: amount);

void main() {
  sqfliteFfiInit();
  late Database db;
  late ExpenseRepository repo;

  setUp(() async {
    db = await openAppDatabase(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    repo = ExpenseRepository(db);
  });
  tearDown(() => db.close());

  test('추가/수정/삭제', () async {
    final saved = await repo.add(e('2025-09-01', 12000, detail: '점심'));
    expect(saved.id, isNotNull);
    await repo.update(saved.copyWith(amount: 13000));
    var list = await repo.byMonth('2025-09');
    expect(list.single.amount, 13000);
    await repo.remove(saved.id!);
    list = await repo.byMonth('2025-09');
    expect(list, isEmpty);
  });

  test('월별 조회는 날짜순, 같은 날짜는 입력순', () async {
    await repo.add(e('2025-09-02', 100));
    final first = await repo.add(e('2025-09-01', 200));
    final second = await repo.add(e('2025-09-01', 300));
    await repo.add(e('2025-08-31', 400)); // 다른 달
    final list = await repo.byMonth('2025-09');
    expect(list.map((x) => x.amount).toList(), [200, 300, 100]);
    expect(list[0].id, first.id);
    expect(list[1].id, second.id);
  });

  test('월 합계와 월 목록', () async {
    expect(await repo.monthTotal('2025-09'), 0);
    await repo.add(e('2025-09-01', 100));
    await repo.add(e('2025-09-30', 200));
    await repo.add(e('2025-08-15', 999));
    expect(await repo.monthTotal('2025-09'), 300);
    expect(await repo.monthsWithData(), ['2025-08', '2025-09']);
  });

  test('전체 월별 합계', () async {
    expect(await repo.monthlyTotals(), isEmpty);
    await repo.add(e('2025-09-01', 100));
    await repo.add(e('2025-09-30', 200));
    await repo.add(e('2025-08-15', 999));
    expect(await repo.monthlyTotals(), {'2025-08': 999, '2025-09': 300});
  });
}
