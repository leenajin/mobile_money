import 'package:sqflite/sqflite.dart';
import '../models/payment_method.dart';

class PaymentMethodRepository {
  PaymentMethodRepository(this.db);
  final Database db;

  Future<List<PaymentMethod>> getAll() async =>
      (await db.query('payment_methods', orderBy: 'id'))
          .map(PaymentMethod.fromMap)
          .toList();

  Future<PaymentMethod> add(String name) async {
    final id = await db.insert('payment_methods', {'name': name, 'is_default': 0});
    return PaymentMethod(id: id, name: name);
  }

  Future<void> rename(int id, String name) =>
      db.update('payment_methods', {'name': name}, where: 'id = ?', whereArgs: [id]);

  Future<int> usageCount(int id) async => Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM expenses WHERE payment_method_id = ?', [id]))!;

  Future<void> remove(int id) async {
    final row = (await db.query('payment_methods', where: 'id = ?', whereArgs: [id])).single;
    if (row['is_default'] == 1) {
      throw ArgumentError('현금은 삭제할 수 없습니다');
    }
    final cash = (await db.query('payment_methods',
            where: 'is_default = 1', limit: 1))
        .single;
    await db.transaction((txn) async {
      await txn.update('expenses', {'payment_method_id': cash['id']},
          where: 'payment_method_id = ?', whereArgs: [id]);
      await txn.delete('payment_methods', where: 'id = ?', whereArgs: [id]);
    });
  }
}
