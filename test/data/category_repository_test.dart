import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile_money/data/app_database.dart';
import 'package:mobile_money/data/category_repository.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late CategoryRepository repo;

  setUp(() async {
    db = await openAppDatabase(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    repo = CategoryRepository(db);
  });
  tearDown(() => db.close());

  test('추가/이름수정/조회', () async {
    final added = await repo.add('병원');
    await repo.rename(added.id!, '의료');
    final all = await repo.getAll();
    expect(all.map((c) => c.name), contains('의료'));
    expect(all.length, 9);
  });

  test('삭제하면 해당 분류의 거래가 기타로 재할당된다', () async {
    final all = await repo.getAll();
    final meal = all.firstWhere((c) => c.name == '식사');
    final etc = all.firstWhere((c) => c.name == '기타');
    await db.insert('expenses', {
      'date': '2025-09-01', 'payment_method_id': 1,
      'category_id': meal.id, 'detail': '점심', 'amount': 12000,
    });
    expect(await repo.usageCount(meal.id!), 1);
    await repo.remove(meal.id!);
    final rows = await db.query('expenses');
    expect(rows.single['category_id'], etc.id);
    expect((await repo.getAll()).map((c) => c.name), isNot(contains('식사')));
  });

  test('기타는 삭제할 수 없다', () async {
    final etc = (await repo.getAll()).firstWhere((c) => c.name == '기타');
    expect(() => repo.remove(etc.id!), throwsArgumentError);
  });
}
