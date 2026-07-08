import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile_money/data/app_database.dart';
import 'package:mobile_money/data/backup_codec.dart';

void main() {
  sqfliteFfiInit();

  Future<Database> freshDb() => openAppDatabase(
      factory: databaseFactoryFfi, path: inMemoryDatabasePath);

  test('내보내기 → 새 DB에 들여오기 왕복이 데이터를 보존한다', () async {
    final src = await freshDb();
    await src.insert('payment_methods', {'name': 'KB 다담카드', 'is_default': 0});
    await src.insert('expenses', {
      'date': '2025-09-01', 'payment_method_id': 2, 'category_id': 1,
      'detail': '점심', 'amount': 12000, 'memo': '비고',
    });
    final json = await exportBackupJson(src);

    final dst = await freshDb();
    await dst.insert('expenses', {
      'date': '2024-01-01', 'payment_method_id': 1, 'category_id': 1,
      'detail': '지워질 데이터', 'amount': 1,
    });
    await importBackupJson(dst, json);

    expect(await dst.query('expenses'), await src.query('expenses'));
    expect(await dst.query('categories'), await src.query('categories'));
    expect(await dst.query('payment_methods'), await src.query('payment_methods'));
    await src.close();
    await dst.close();
  });

  test('버전이 다르면 FormatException', () async {
    final db = await freshDb();
    final bad = jsonEncode({'version': 99, 'categories': [], 'payment_methods': [], 'expenses': []});
    expect(() => importBackupJson(db, bad), throwsFormatException);
    await db.close();
  });
}
