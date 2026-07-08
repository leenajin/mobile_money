import 'package:sqflite/sqflite.dart';
import '../models/category.dart';

class CategoryRepository {
  CategoryRepository(this.db);
  final Database db;

  Future<List<Category>> getAll() async =>
      (await db.query('categories', orderBy: 'id')).map(Category.fromMap).toList();

  Future<Category> add(String name) async {
    final id = await db.insert('categories', {'name': name, 'is_default': 0});
    return Category(id: id, name: name);
  }

  Future<void> rename(int id, String name) =>
      db.update('categories', {'name': name}, where: 'id = ?', whereArgs: [id]);

  Future<int> usageCount(int id) async => Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM expenses WHERE category_id = ?', [id]))!;

  Future<void> remove(int id) async {
    final row = (await db.query('categories', where: 'id = ?', whereArgs: [id])).single;
    if (row['is_default'] == 1) {
      throw ArgumentError('기본 분류는 삭제할 수 없습니다');
    }
    final etc = (await db.query('categories',
            where: 'is_default = 1', limit: 1))
        .single;
    await db.transaction((txn) async {
      await txn.update('expenses', {'category_id': etc['id']},
          where: 'category_id = ?', whereArgs: [id]);
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
  }
}
