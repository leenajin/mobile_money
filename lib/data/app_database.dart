import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const defaultCategories = ['식사', '간식', '선물', '정기결제', '카페', '편의점', '식재료', '기타'];

Future<Database> openAppDatabase({DatabaseFactory? factory, String? path}) async {
  final f = factory ?? databaseFactory;
  final dbPath = path ?? p.join(await f.getDatabasesPath(), 'mobile_money.db');
  return f.openDatabase(dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE categories (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL UNIQUE,
              is_default INTEGER NOT NULL DEFAULT 0
            )''');
          await db.execute('''
            CREATE TABLE payment_methods (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL UNIQUE,
              is_default INTEGER NOT NULL DEFAULT 0
            )''');
          await db.execute('''
            CREATE TABLE expenses (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              payment_method_id INTEGER NOT NULL,
              category_id INTEGER NOT NULL,
              detail TEXT NOT NULL DEFAULT '',
              amount INTEGER NOT NULL,
              memo TEXT
            )''');
          await db.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
          for (final name in defaultCategories) {
            await db.insert('categories',
                {'name': name, 'is_default': name == '기타' ? 1 : 0});
          }
          await db.insert('payment_methods', {'name': '현금', 'is_default': 1});
        },
      ));
}
