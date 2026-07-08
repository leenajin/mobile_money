import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile_money/data/app_database.dart';

void main() {
  sqfliteFfiInit();

  test('DB를 열면 기본 분류 8종과 현금이 시드된다', () async {
    final db = await openAppDatabase(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    final cats = await db.query('categories', orderBy: 'id');
    expect(cats.map((c) => c['name']).toList(),
        ['식사', '간식', '선물', '정기결제', '카페', '편의점', '식재료', '기타']);
    final pays = await db.query('payment_methods');
    expect(pays.single['name'], '현금');
    expect(pays.single['is_default'], 1);
    await db.close();
  });

  test('expenses 테이블에 거래를 넣고 읽을 수 있다', () async {
    final db = await openAppDatabase(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    final id = await db.insert('expenses', {
      'date': '2025-09-01',
      'payment_method_id': 1,
      'category_id': 1,
      'detail': '점심',
      'amount': 12000,
      'memo': null,
    });
    final rows = await db.query('expenses', where: 'id = ?', whereArgs: [id]);
    expect(rows.single['amount'], 12000);
    await db.close();
  });
}
