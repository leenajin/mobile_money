import 'package:sqflite/sqflite.dart';
import '../models/expense.dart';

class ExpenseRepository {
  ExpenseRepository(this.db);
  final Database db;

  Future<Expense> add(Expense e) async {
    final map = e.toMap()..remove('id');
    final id = await db.insert('expenses', map);
    return e.copyWith(id: id);
  }

  Future<void> update(Expense e) => db.update('expenses', e.toMap(),
      where: 'id = ?', whereArgs: [e.id]);

  Future<void> remove(int id) =>
      db.delete('expenses', where: 'id = ?', whereArgs: [id]);

  Future<List<Expense>> byMonth(String yearMonth) async =>
      (await db.query('expenses',
              where: "date LIKE ?",
              whereArgs: ['$yearMonth-%'],
              orderBy: 'date ASC, id ASC'))
          .map(Expense.fromMap)
          .toList();

  Future<int> monthTotal(String yearMonth) async =>
      Sqflite.firstIntValue(await db.rawQuery(
          "SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE date LIKE ?",
          ['$yearMonth-%']))!;

  Future<List<String>> monthsWithData() async =>
      (await db.rawQuery(
              "SELECT DISTINCT substr(date, 1, 7) AS ym FROM expenses ORDER BY ym"))
          .map((r) => r['ym'] as String)
          .toList();

  /// 월('yyyy-MM') → 그 달 지출 합계 (거래 있는 달만)
  Future<Map<String, int>> monthlyTotals() async => {
        for (final r in await db.rawQuery(
            "SELECT substr(date, 1, 7) AS ym, SUM(amount) AS total "
            "FROM expenses GROUP BY ym ORDER BY ym"))
          r['ym'] as String: r['total'] as int,
      };
}
