import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile_money/data/app_database.dart';
import 'package:mobile_money/data/payment_method_repository.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late PaymentMethodRepository repo;

  setUp(() async {
    db = await openAppDatabase(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    repo = PaymentMethodRepository(db);
  });
  tearDown(() => db.close());

  test('카드 추가/이름수정', () async {
    final card = await repo.add('KB 다담카드');
    await repo.rename(card.id!, 'KB 국민카드');
    final all = await repo.getAll();
    expect(all.length, 2);
    expect(all.map((p) => p.name), contains('KB 국민카드'));
  });

  test('카드 삭제 시 거래가 현금으로 재할당된다', () async {
    final card = await repo.add('KB 다담카드');
    final cash = (await repo.getAll()).firstWhere((p) => p.name == '현금');
    await db.insert('expenses', {
      'date': '2025-09-01', 'payment_method_id': card.id,
      'category_id': 1, 'detail': '점심', 'amount': 12000,
    });
    await repo.remove(card.id!);
    final rows = await db.query('expenses');
    expect(rows.single['payment_method_id'], cash.id);
  });

  test('현금은 삭제할 수 없다', () async {
    final cash = (await repo.getAll()).firstWhere((p) => p.name == '현금');
    expect(() => repo.remove(cash.id!), throwsArgumentError);
  });
}
