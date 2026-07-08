import 'dart:convert';
import 'package:sqflite/sqflite.dart';

const _tables = ['categories', 'payment_methods', 'expenses'];

Future<String> exportBackupJson(Database db) async {
  final data = <String, Object?>{'version': 1};
  for (final t in _tables) {
    data[t] = await db.query(t);
  }
  return jsonEncode(data);
}

Future<void> importBackupJson(Database db, String json) async {
  final data = jsonDecode(json) as Map<String, dynamic>;
  if (data['version'] != 1) {
    throw FormatException('지원하지 않는 백업 버전: ${data['version']}');
  }
  await db.transaction((txn) async {
    for (final t in _tables) {
      await txn.delete(t);
      for (final row in (data[t] as List)) {
        await txn.insert(t, Map<String, Object?>.from(row as Map));
      }
    }
  });
}
