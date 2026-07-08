# mobile_money 가계부 앱 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 구글 시트 가계부를 그대로 옮긴 표 형식의 안드로이드 지출 가계부 앱 (로컬 SQLite 저장 + 구글 드라이브 백업/복원).

**Architecture:** 화면(screens) → 상태(AppState, Provider) → 저장소(data/sqflite) 순의 단방향 의존. 백업(sync)은 DB 전체를 JSON 하나로 직렬화해 드라이브 appDataFolder에 업로드하는 로컬 우선 구조. 스펙: `docs/superpowers/specs/2026-07-08-mobile-money-design.md`

**Tech Stack:** Flutter(안정 채널) / Dart, sqflite, provider, intl, google_sign_in 6.x, googleapis(Drive v3), shared_preferences. 테스트: flutter_test + sqflite_common_ffi.

## Global Constraints

- 안드로이드 전용. minSdkVersion 23.
- 커밋 메시지는 항상 한글로 작성한다.
- 지출만 기록한다. 수입/잔액/예산 기능 금지 (YAGNI).
- 금액은 정수(원 단위)로 저장. 날짜는 `yyyy-MM-dd` 문자열로 저장, 월 키는 `yyyy-MM`.
- 기본 분류: 식사, 간식, 선물, 정기결제, 카페, 편의점, 식재료, 기타. "기타"는 삭제 불가, 분류 삭제 시 해당 거래는 "기타"로 재할당.
- 기본 결제수단: 현금(삭제 불가). 카드 삭제 시 해당 거래는 "현금"으로 재할당.
- 화면 코드에서 SQL/드라이브 API 직접 호출 금지 (data/, sync/ 계층을 통해서만).
- 드라이브 권한은 `drive.appdata` 스코프만 요청. 백업 파일명은 `mobile_money_backup.json` 고정.
- 모든 Dart 명령은 프로젝트 루트 `D:\projects\mobile_money`에서 실행. 셸은 PowerShell 기준.

## 파일 구조 (전체 지도)

```
lib/
  main.dart                      # 앱 진입점, Provider 배선
  models/
    category.dart                # Category 모델
    payment_method.dart          # PaymentMethod 모델
    expense.dart                 # Expense(거래) 모델
  data/
    app_database.dart            # DB 열기, 스키마 생성, 기본값 시드
    category_repository.dart     # 분류 CRUD + 삭제 시 '기타' 재할당
    payment_method_repository.dart # 결제수단 CRUD + 삭제 시 '현금' 재할당
    expense_repository.dart      # 거래 CRUD, 월별 조회/합계/월 목록
    backup_codec.dart            # DB 전체 ↔ JSON 직렬화/역직렬화
  logic/
    ledger_rows.dart             # 날짜 첫 행만 표시 규칙, 통화 포맷
    app_state.dart               # ChangeNotifier 상태 (Provider로 주입)
  sync/
    drive_sync.dart              # 구글 로그인 + 드라이브 업로드/다운로드
    backup_service.dart          # 자동백업 상태/시각 관리, 백업/복원 실행
  widgets/
    ledger_table.dart            # 표 (헤더 고정, 격자선, 행번호, 합계 행)
    month_tab_bar.dart           # 하단 월 탭 + ☰ 메뉴 버튼
  screens/
    ledger_screen.dart           # 메인 화면 (표 + 탭바 + FAB)
    expense_sheet.dart           # 입력 바텀시트 (추가/수정/삭제)
    category_screen.dart         # 분류 관리
    payment_method_screen.dart   # 카드 관리
    settings_screen.dart         # 설정 (로그인/백업/복원)
test/
  data/ logic/ widgets/          # 각 계층 테스트 (아래 태스크별 명시)
```

각 모델은 `toMap()`/`fromMap()`을 갖는 불변 클래스. 저장소는 생성자로 `Database`를 받는다. AppState는 저장소 3개를 받아 화면에 필요한 목록/합계를 노출한다.

---

### Task 1: 개발 환경 준비 + Flutter 프로젝트 생성

설정 태스크(TDD 없음). 완료 기준: `flutter doctor` 통과, 빈 프로젝트의 기본 테스트 통과.

**Files:**
- Create: Flutter 프로젝트 스캐폴드 전체 (`pubspec.yaml`, `lib/main.dart`, `android/` 등)
- Modify: `android/app/build.gradle.kts` (minSdk), `pubspec.yaml` (의존성)

**Interfaces:**
- Produces: 이후 모든 태스크가 사용할 빌드 가능한 Flutter 프로젝트와 의존성 목록

- [ ] **Step 1: Flutter SDK 설치 확인/설치**

`flutter --version`이 실패하면 설치한다 (PowerShell):

```powershell
winget install --id=Google.FlutterSDK -e --accept-source-agreements --accept-package-agreements
# 설치 후 새 셸에서 flutter --version 확인. winget 미지원 시:
# https://docs.flutter.dev/get-started/install/windows 의 zip을 C:\dev\flutter 에 풀고 PATH에 C:\dev\flutter\bin 추가
```

Android SDK가 없으면 Android Studio 설치가 가장 간단하다: `winget install --id=Google.AndroidStudio -e`. 설치 후 Android Studio 첫 실행에서 SDK/빌드도구 설치 → `flutter doctor --android-licenses` 로 라이선스 동의.

Run: `flutter doctor`
Expected: `Flutter (Channel stable)` 및 `Android toolchain` 항목에 [√]. (Chrome/Visual Studio 항목의 [!]는 무시 — 안드로이드 전용)

- [ ] **Step 2: 프로젝트 생성 (기존 디렉토리 안에)**

```powershell
cd D:\projects\mobile_money
flutter create --platforms=android --org com.mobilemoney --project-name mobile_money .
```

Expected: `All done!` 출력, `pubspec.yaml`·`lib/`·`android/` 생성. 기존 `docs/`, `.git/`은 그대로 유지됨.

- [ ] **Step 3: 의존성 추가**

```powershell
flutter pub add sqflite provider intl shared_preferences path
flutter pub add google_sign_in:^6.2.1 googleapis:^13.2.0 extension_google_sign_in_as_googleapis_auth:^2.0.12
flutter pub add dev:sqflite_common_ffi
```

Expected: `Changed N dependencies!`, `flutter pub get` 자동 실행 성공.

- [ ] **Step 4: minSdk 설정**

`android/app/build.gradle.kts`의 `defaultConfig` 블록에서 `minSdk = flutter.minSdkVersion`을 다음으로 교체:

```kotlin
minSdk = 23
```

(파일이 `build.gradle`(Groovy)라면 `minSdkVersion 23`으로 동일 위치 수정)

- [ ] **Step 5: 기본 테스트로 환경 검증**

`flutter create`가 만든 카운터 앱 기본 테스트를 그대로 실행:

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 6: .gitignore 확인 후 커밋**

`flutter create`가 만든 `.gitignore`가 루트에 있는지 확인 (build/, .dart_tool/ 등 포함).

```powershell
git add -A
git commit -m "Flutter 프로젝트 생성 및 의존성 추가"
```

---
### Task 2: 모델 3종 + DB 스키마/시드

**Files:**
- Create: `lib/models/category.dart`, `lib/models/payment_method.dart`, `lib/models/expense.dart`, `lib/data/app_database.dart`
- Test: `test/data/app_database_test.dart`

**Interfaces:**
- Produces:
  - `class Category { final int? id; final String name; final bool isDefault; }` + `toMap()`, `Category.fromMap(Map)`, `copyWith({int? id, String? name})`
  - `class PaymentMethod` — Category와 동일 형태
  - `class Expense { final int? id; final String date; final int paymentMethodId; final int categoryId; final String detail; final int amount; final String? memo; }` + `toMap()`, `Expense.fromMap(Map)`, `copyWith(...)`
  - `Future<Database> openAppDatabase({DatabaseFactory? factory, String? path})` — 테이블 생성 + 기본 분류 8종/현금 시드. `factory`/`path` 미지정 시 실제 앱 경로 사용, 테스트에선 ffi 팩토리 + `inMemoryDatabasePath` 주입.

- [ ] **Step 1: 실패하는 테스트 작성** — `test/data/app_database_test.dart`

```dart
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
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/data/app_database_test.dart`
Expected: FAIL — `Error: ... 'package:mobile_money/data/app_database.dart' not found` 류의 컴파일 오류

- [ ] **Step 3: 모델 구현**

`lib/models/category.dart`:

```dart
class Category {
  final int? id;
  final String name;
  final bool isDefault;

  const Category({this.id, required this.name, this.isDefault = false});

  Category copyWith({int? id, String? name}) =>
      Category(id: id ?? this.id, name: name ?? this.name, isDefault: isDefault);

  Map<String, Object?> toMap() =>
      {'id': id, 'name': name, 'is_default': isDefault ? 1 : 0};

  factory Category.fromMap(Map<String, Object?> m) => Category(
      id: m['id'] as int?,
      name: m['name'] as String,
      isDefault: m['is_default'] == 1);
}
```

`lib/models/payment_method.dart`: 위와 동일하되 클래스명 `PaymentMethod`.

`lib/models/expense.dart`:

```dart
class Expense {
  final int? id;
  final String date; // yyyy-MM-dd
  final int paymentMethodId;
  final int categoryId;
  final String detail;
  final int amount; // 원 단위
  final String? memo;

  const Expense({
    this.id,
    required this.date,
    required this.paymentMethodId,
    required this.categoryId,
    this.detail = '',
    required this.amount,
    this.memo,
  });

  Expense copyWith({
    int? id,
    String? date,
    int? paymentMethodId,
    int? categoryId,
    String? detail,
    int? amount,
    String? memo,
  }) =>
      Expense(
        id: id ?? this.id,
        date: date ?? this.date,
        paymentMethodId: paymentMethodId ?? this.paymentMethodId,
        categoryId: categoryId ?? this.categoryId,
        detail: detail ?? this.detail,
        amount: amount ?? this.amount,
        memo: memo ?? this.memo,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'date': date,
        'payment_method_id': paymentMethodId,
        'category_id': categoryId,
        'detail': detail,
        'amount': amount,
        'memo': memo,
      };

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
        id: m['id'] as int?,
        date: m['date'] as String,
        paymentMethodId: m['payment_method_id'] as int,
        categoryId: m['category_id'] as int,
        detail: (m['detail'] as String?) ?? '',
        amount: m['amount'] as int,
        memo: m['memo'] as String?,
      );
}
```

- [ ] **Step 4: DB 헬퍼 구현** — `lib/data/app_database.dart`

```dart
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
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `flutter test test/data/app_database_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 6: 커밋**

```powershell
git add lib/models lib/data test/data
git commit -m "모델과 DB 스키마, 기본 분류/현금 시드 추가"
```

---

### Task 3: 분류/결제수단 저장소 (CRUD + 재할당 규칙)

**Files:**
- Create: `lib/data/category_repository.dart`, `lib/data/payment_method_repository.dart`
- Test: `test/data/category_repository_test.dart`, `test/data/payment_method_repository_test.dart`

**Interfaces:**
- Consumes: `openAppDatabase()`, `Category`, `PaymentMethod`
- Produces:
  - `class CategoryRepository { CategoryRepository(this.db); final Database db; Future<List<Category>> getAll(); Future<Category> add(String name); Future<void> rename(int id, String name); Future<void> remove(int id); Future<int> usageCount(int id); }`
    - `remove`: '기타'(is_default=1)면 `ArgumentError` throw. 아니면 해당 분류를 쓰는 expenses의 category_id를 '기타' id로 UPDATE 후 삭제.
  - `class PaymentMethodRepository` — 동일 형태, '현금' 보호/재할당.

- [ ] **Step 1: 실패하는 테스트 작성** — `test/data/category_repository_test.dart`

```dart
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
```

`test/data/payment_method_repository_test.dart` — 같은 구조로 작성 (repo는 `PaymentMethodRepository`, 보호 대상 '현금', 재할당 컬럼 `payment_method_id`, 카드 추가 예시 'KB 다담카드', 시드가 1개이므로 추가 후 길이는 2):

```dart
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
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/data/`
Expected: 새 테스트 2파일 컴파일 오류로 FAIL (app_database_test는 계속 PASS)

- [ ] **Step 3: 구현** — `lib/data/category_repository.dart`

```dart
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
```

`lib/data/payment_method_repository.dart` — 동일 구조 (테이블 `payment_methods`, 모델 `PaymentMethod`, 재할당 컬럼 `payment_method_id`, 오류 메시지 '현금은 삭제할 수 없습니다'):

```dart
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
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/data/`
Expected: PASS (전체)

- [ ] **Step 5: 커밋**

```powershell
git add lib/data test/data
git commit -m "분류/결제수단 저장소와 삭제 시 재할당 규칙 구현"
```

---
### Task 4: 거래 저장소 (CRUD, 월별 조회/합계/월 목록)

**Files:**
- Create: `lib/data/expense_repository.dart`
- Test: `test/data/expense_repository_test.dart`

**Interfaces:**
- Consumes: `openAppDatabase()`, `Expense`
- Produces:
  - `class ExpenseRepository { ExpenseRepository(this.db); final Database db; Future<Expense> add(Expense e); Future<void> update(Expense e); Future<void> remove(int id); Future<List<Expense>> byMonth(String yearMonth); Future<int> monthTotal(String yearMonth); Future<List<String>> monthsWithData(); }`
    - `byMonth('2025-09')`: 해당 월 거래를 date ASC, id ASC 정렬로 반환
    - `monthTotal`: 해당 월 amount 합 (없으면 0)
    - `monthsWithData()`: `['2025-08', '2025-09']`처럼 거래가 있는 월 오름차순

- [ ] **Step 1: 실패하는 테스트 작성** — `test/data/expense_repository_test.dart`

```dart
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
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/data/expense_repository_test.dart`
Expected: FAIL (expense_repository.dart 없음 — 컴파일 오류)

- [ ] **Step 3: 구현** — `lib/data/expense_repository.dart`

```dart
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
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/data/`
Expected: PASS (전체)

- [ ] **Step 5: 커밋**

```powershell
git add lib/data/expense_repository.dart test/data/expense_repository_test.dart
git commit -m "거래 저장소 구현 (월별 조회, 합계, 월 목록)"
```

---

### Task 5: 장부 행 구성 로직 + 통화 포맷 (순수 함수)

**Files:**
- Create: `lib/logic/ledger_rows.dart`
- Test: `test/logic/ledger_rows_test.dart`

**Interfaces:**
- Consumes: `Expense`
- Produces:
  - `class LedgerRow { final Expense expense; final bool showDate; }`
  - `List<LedgerRow> buildLedgerRows(List<Expense> expenses)` — 입력 순서 유지, 직전 행과 date가 같으면 `showDate=false`
  - `String formatWon(int amount)` — `'₩9,400'` 형식
  - `String formatSheetDate(String date)` — `'2025-09-01'` → `'2025. 9. 1'` (시트와 동일 표기)
  - `String monthLabel(String yearMonth)` — `'2025-09'` → `'2025.9'` (월 탭 표기)

- [ ] **Step 1: 실패하는 테스트 작성** — `test/logic/ledger_rows_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_money/logic/ledger_rows.dart';
import 'package:mobile_money/models/expense.dart';

Expense e(String date) =>
    Expense(date: date, paymentMethodId: 1, categoryId: 1, amount: 1000);

void main() {
  test('같은 날짜가 이어지면 첫 행만 날짜를 표시한다', () {
    final rows = buildLedgerRows([
      e('2025-09-01'), e('2025-09-01'), e('2025-09-02'),
      e('2025-09-02'), e('2025-09-04'),
    ]);
    expect(rows.map((r) => r.showDate).toList(),
        [true, false, true, false, true]);
  });

  test('빈 목록이면 빈 행', () {
    expect(buildLedgerRows([]), isEmpty);
  });

  test('통화/날짜/월 포맷', () {
    expect(formatWon(9400), '₩9,400');
    expect(formatWon(3000000), '₩3,000,000');
    expect(formatWon(0), '₩0');
    expect(formatSheetDate('2025-09-01'), '2025. 9. 1');
    expect(formatSheetDate('2025-12-25'), '2025. 12. 25');
    expect(monthLabel('2025-09'), '2025.9');
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/logic/ledger_rows_test.dart`
Expected: FAIL (컴파일 오류)

- [ ] **Step 3: 구현** — `lib/logic/ledger_rows.dart`

```dart
import 'package:intl/intl.dart';
import '../models/expense.dart';

class LedgerRow {
  final Expense expense;
  final bool showDate;
  const LedgerRow(this.expense, {required this.showDate});
}

List<LedgerRow> buildLedgerRows(List<Expense> expenses) {
  final rows = <LedgerRow>[];
  String? prevDate;
  for (final e in expenses) {
    rows.add(LedgerRow(e, showDate: e.date != prevDate));
    prevDate = e.date;
  }
  return rows;
}

final _won = NumberFormat('#,###');

String formatWon(int amount) => '₩${_won.format(amount)}';

String formatSheetDate(String date) {
  final parts = date.split('-');
  return '${parts[0]}. ${int.parse(parts[1])}. ${int.parse(parts[2])}';
}

String monthLabel(String yearMonth) {
  final parts = yearMonth.split('-');
  return '${parts[0]}.${int.parse(parts[1])}';
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/logic/ledger_rows_test.dart`
Expected: PASS

- [ ] **Step 5: 커밋**

```powershell
git add lib/logic/ledger_rows.dart test/logic/ledger_rows_test.dart
git commit -m "장부 행 구성 규칙과 통화/날짜 포맷 구현"
```

---

### Task 6: AppState (Provider 상태)

**Files:**
- Create: `lib/logic/app_state.dart`
- Test: `test/logic/app_state_test.dart`

**Interfaces:**
- Consumes: 저장소 3종, `buildLedgerRows`, 모델 3종
- Produces (화면들이 사용할 유일한 상태 객체):

```dart
class AppState extends ChangeNotifier {
  AppState({required Database db, String? today});
  // today: 'yyyy-MM-dd', 테스트 주입용. null이면 DateTime.now() 사용.

  List<String> months;          // 거래 있는 월 + 현재 월, 오름차순, 중복 없음
  String selectedMonth;         // 'yyyy-MM', 초기값 = 현재 월
  List<LedgerRow> rows;         // 선택 월의 장부 행
  int monthTotal;               // 선택 월 합계
  List<Category> categories;
  List<PaymentMethod> paymentMethods;
  String get today;             // 'yyyy-MM-dd'
  void Function()? onDataChanged; // 백업 훅 (Task 12에서 연결)

  Future<void> init();
  Future<void> selectMonth(String yearMonth);
  Future<void> addExpense(Expense e);
  Future<void> updateExpense(Expense e);
  Future<void> deleteExpense(int id);
  Future<void> addCategory(String name);
  Future<void> renameCategory(int id, String name);
  Future<void> removeCategory(int id);
  Future<int> categoryUsage(int id);
  Future<void> addPaymentMethod(String name);
  Future<void> renamePaymentMethod(int id, String name);
  Future<void> removePaymentMethod(int id);
  Future<int> paymentMethodUsage(int id);
  Future<void> reloadAll(); // 복원 후 전체 새로고침 (Task 12에서 사용)
}
```

모든 변경 메서드는 성공 시 관련 목록을 다시 읽고 `notifyListeners()` 호출, 마지막에 `onDataChanged?.call()`.

- [ ] **Step 1: 실패하는 테스트 작성** — `test/logic/app_state_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile_money/data/app_database.dart';
import 'package:mobile_money/logic/app_state.dart';
import 'package:mobile_money/models/expense.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late AppState state;

  setUp(() async {
    db = await openAppDatabase(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    state = AppState(db: db, today: '2025-09-15');
    await state.init();
  });
  tearDown(() => db.close());

  Expense e(String date, int amount) => Expense(
      date: date,
      paymentMethodId: state.paymentMethods.first.id!,
      categoryId: state.categories.first.id!,
      amount: amount);

  test('초기 상태: 현재 월 선택, 월 목록에 현재 월 포함', () {
    expect(state.selectedMonth, '2025-09');
    expect(state.months, ['2025-09']);
    expect(state.rows, isEmpty);
    expect(state.monthTotal, 0);
    expect(state.categories.length, 8);
    expect(state.paymentMethods.single.name, '현금');
  });

  test('거래 추가 시 행/합계/월 목록 갱신 + 알림', () async {
    var notified = 0;
    state.addListener(() => notified++);
    var hookCalled = 0;
    state.onDataChanged = () => hookCalled++;

    await state.addExpense(e('2025-09-01', 12000));
    await state.addExpense(e('2025-08-20', 5000)); // 과거 달
    expect(state.rows.length, 1); // 선택 월(9월) 것만
    expect(state.monthTotal, 12000);
    expect(state.months, ['2025-08', '2025-09']);
    expect(notified, greaterThanOrEqualTo(2));
    expect(hookCalled, 2);
  });

  test('월 전환', () async {
    await state.addExpense(e('2025-08-20', 5000));
    await state.selectMonth('2025-08');
    expect(state.rows.single.expense.amount, 5000);
    expect(state.monthTotal, 5000);
  });

  test('거래 수정/삭제', () async {
    await state.addExpense(e('2025-09-01', 12000));
    final saved = state.rows.single.expense;
    await state.updateExpense(saved.copyWith(amount: 9000));
    expect(state.monthTotal, 9000);
    await state.deleteExpense(saved.id!);
    expect(state.rows, isEmpty);
  });

  test('분류 추가/삭제 시 목록 갱신', () async {
    await state.addCategory('병원');
    expect(state.categories.map((c) => c.name), contains('병원'));
    final added = state.categories.firstWhere((c) => c.name == '병원');
    await state.removeCategory(added.id!);
    expect(state.categories.map((c) => c.name), isNot(contains('병원')));
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/logic/app_state_test.dart`
Expected: FAIL (컴파일 오류)

- [ ] **Step 3: 구현** — `lib/logic/app_state.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../data/category_repository.dart';
import '../data/expense_repository.dart';
import '../data/payment_method_repository.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/payment_method.dart';
import 'ledger_rows.dart';

class AppState extends ChangeNotifier {
  AppState({required Database db, String? today})
      : _expenses = ExpenseRepository(db),
        _categories = CategoryRepository(db),
        _payments = PaymentMethodRepository(db),
        _today = today;

  final ExpenseRepository _expenses;
  final CategoryRepository _categories;
  final PaymentMethodRepository _payments;
  final String? _today;

  List<String> months = [];
  String selectedMonth = '';
  List<LedgerRow> rows = [];
  int monthTotal = 0;
  List<Category> categories = [];
  List<PaymentMethod> paymentMethods = [];
  void Function()? onDataChanged;

  String get today {
    if (_today != null) return _today!;
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String get _currentMonth => today.substring(0, 7);

  Future<void> init() async {
    selectedMonth = _currentMonth;
    await reloadAll();
  }

  Future<void> reloadAll() async {
    categories = await _categories.getAll();
    paymentMethods = await _payments.getAll();
    await _reloadLedger();
  }

  Future<void> _reloadLedger() async {
    final withData = await _expenses.monthsWithData();
    months = {...withData, _currentMonth}.toList()..sort();
    if (!months.contains(selectedMonth)) selectedMonth = months.last;
    rows = buildLedgerRows(await _expenses.byMonth(selectedMonth));
    monthTotal = await _expenses.monthTotal(selectedMonth);
    notifyListeners();
  }

  Future<void> selectMonth(String yearMonth) async {
    selectedMonth = yearMonth;
    await _reloadLedger();
  }

  Future<void> addExpense(Expense e) async {
    await _expenses.add(e);
    await _reloadLedger();
    onDataChanged?.call();
  }

  Future<void> updateExpense(Expense e) async {
    await _expenses.update(e);
    await _reloadLedger();
    onDataChanged?.call();
  }

  Future<void> deleteExpense(int id) async {
    await _expenses.remove(id);
    await _reloadLedger();
    onDataChanged?.call();
  }

  Future<void> addCategory(String name) async {
    await _categories.add(name);
    categories = await _categories.getAll();
    notifyListeners();
    onDataChanged?.call();
  }

  Future<void> renameCategory(int id, String name) async {
    await _categories.rename(id, name);
    categories = await _categories.getAll();
    notifyListeners();
    onDataChanged?.call();
  }

  Future<void> removeCategory(int id) async {
    await _categories.remove(id);
    categories = await _categories.getAll();
    await _reloadLedger(); // 재할당 반영
    onDataChanged?.call();
  }

  Future<int> categoryUsage(int id) => _categories.usageCount(id);

  Future<void> addPaymentMethod(String name) async {
    await _payments.add(name);
    paymentMethods = await _payments.getAll();
    notifyListeners();
    onDataChanged?.call();
  }

  Future<void> renamePaymentMethod(int id, String name) async {
    await _payments.rename(id, name);
    paymentMethods = await _payments.getAll();
    notifyListeners();
    onDataChanged?.call();
  }

  Future<void> removePaymentMethod(int id) async {
    await _payments.remove(id);
    paymentMethods = await _payments.getAll();
    await _reloadLedger();
    onDataChanged?.call();
  }

  Future<int> paymentMethodUsage(int id) => _payments.usageCount(id);
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/logic/`
Expected: PASS (전체)

- [ ] **Step 5: 커밋**

```powershell
git add lib/logic/app_state.dart test/logic/app_state_test.dart
git commit -m "AppState 상태 관리 구현"
```

---
### Task 7: 장부 표 위젯 (헤더 고정, 격자선, 행번호, 합계 행)

**Files:**
- Create: `lib/widgets/ledger_table.dart`
- Test: `test/widgets/ledger_table_test.dart`

**Interfaces:**
- Consumes: `LedgerRow`, `formatWon`, `formatSheetDate`, `Expense`
- Produces:

```dart
class LedgerTable extends StatelessWidget {
  const LedgerTable({
    super.key,
    required this.rows,
    required this.monthTotal,
    required this.categoryNames,   // Map<int, String> (categoryId → 이름)
    required this.paymentNames,    // Map<int, String>
    required this.onRowTap,        // void Function(Expense)
  });
}
```

디자인 규칙 (시트 스크린샷 기준):
- 컬럼: 행번호(36) | 날짜(96) | 카드(110) | 사용용도(80) | 상세(150) | 금액(96) | 비고(110) — 고정 폭 합계 678. 전체를 가로 `SingleChildScrollView`로 감싼다.
- 헤더 행: 연노랑 배경(`Color(0xFFFFF3C4)`), 굵은 글씨, 세로 스크롤과 무관하게 상단 고정 (Column: [헤더, Expanded(ListView)]).
- 모든 셀: `Border(right/bottom: Color(0xFFD0D0D0))` 격자선, 높이 36, 좌우 패딩 6.
- 행번호 셀은 회색 배경(`Color(0xFFF1F3F4)`), 1부터 증가.
- 금액 셀 오른쪽 정렬, `formatWon`. 날짜는 `showDate`가 true일 때만 `formatSheetDate` 표시.
- 마지막 데이터 행 다음에 합계 행: 상세 컬럼에 '합계', 금액 컬럼에 `formatWon(monthTotal)`, 연노랑 배경, 굵은 글씨. 행번호/탭 이벤트 없음.
- 데이터 행 탭 → `onRowTap(row.expense)`.

- [ ] **Step 1: 실패하는 위젯 테스트 작성** — `test/widgets/ledger_table_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_money/logic/ledger_rows.dart';
import 'package:mobile_money/models/expense.dart';
import 'package:mobile_money/widgets/ledger_table.dart';

void main() {
  final expenses = [
    const Expense(id: 1, date: '2025-09-01', paymentMethodId: 1,
        categoryId: 1, detail: '점심', amount: 12000),
    const Expense(id: 2, date: '2025-09-01', paymentMethodId: 1,
        categoryId: 2, detail: '커피', amount: 4500, memo: '반값할인'),
    const Expense(id: 3, date: '2025-09-02', paymentMethodId: 2,
        categoryId: 1, detail: '저녁', amount: 20000),
  ];

  Widget build({void Function(Expense)? onTap}) => MaterialApp(
        home: Scaffold(
          body: LedgerTable(
            rows: buildLedgerRows(expenses),
            monthTotal: 36500,
            categoryNames: const {1: '식사', 2: '카페'},
            paymentNames: const {1: 'KB 다담카드', 2: '현금'},
            onRowTap: onTap ?? (_) {},
          ),
        ),
      );

  testWidgets('헤더/데이터/합계가 표시된다', (tester) async {
    await tester.pumpWidget(build());
    for (final h in ['날짜', '카드', '사용용도', '상세', '금액', '비고']) {
      expect(find.text(h), findsOneWidget);
    }
    expect(find.text('점심'), findsOneWidget);
    expect(find.text('₩12,000'), findsOneWidget);
    expect(find.text('반값할인'), findsOneWidget);
    expect(find.text('합계'), findsOneWidget);
    expect(find.text('₩36,500'), findsOneWidget);
  });

  testWidgets('같은 날짜는 첫 행만 날짜 표시', (tester) async {
    await tester.pumpWidget(build());
    expect(find.text('2025. 9. 1'), findsOneWidget); // 두 거래지만 한 번만
    expect(find.text('2025. 9. 2'), findsOneWidget);
  });

  testWidgets('행 탭 시 해당 거래 전달', (tester) async {
    Expense? tapped;
    await tester.pumpWidget(build(onTap: (e) => tapped = e));
    await tester.tap(find.text('커피'));
    expect(tapped?.id, 2);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/widgets/ledger_table_test.dart`
Expected: FAIL (컴파일 오류)

- [ ] **Step 3: 구현** — `lib/widgets/ledger_table.dart`

```dart
import 'package:flutter/material.dart';
import '../logic/ledger_rows.dart';
import '../models/expense.dart';

const _headerColor = Color(0xFFFFF3C4);
const _gridColor = Color(0xFFD0D0D0);
const _rowNumColor = Color(0xFFF1F3F4);
const _colWidths = [36.0, 96.0, 110.0, 80.0, 150.0, 96.0, 110.0];

class LedgerTable extends StatelessWidget {
  const LedgerTable({
    super.key,
    required this.rows,
    required this.monthTotal,
    required this.categoryNames,
    required this.paymentNames,
    required this.onRowTap,
  });

  final List<LedgerRow> rows;
  final int monthTotal;
  final Map<int, String> categoryNames;
  final Map<int, String> paymentNames;
  final void Function(Expense) onRowTap;

  @override
  Widget build(BuildContext context) {
    final tableWidth = _colWidths.reduce((a, b) => a + b);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: tableWidth,
        child: Column(
          children: [
            _headerRow(),
            Expanded(
              child: ListView.builder(
                itemCount: rows.length + 1,
                itemBuilder: (context, i) =>
                    i < rows.length ? _dataRow(i) : _totalRow(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(int col, String text,
      {Color? bg, bool bold = false, bool right = false}) {
    return Container(
      width: _colWidths[col],
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: right ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: bg,
        border: const Border(
          right: BorderSide(color: _gridColor),
          bottom: BorderSide(color: _gridColor),
        ),
      ),
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    );
  }

  Widget _headerRow() => Row(children: [
        _cell(0, '', bg: _rowNumColor),
        _cell(1, '날짜', bg: _headerColor, bold: true),
        _cell(2, '카드', bg: _headerColor, bold: true),
        _cell(3, '사용용도', bg: _headerColor, bold: true),
        _cell(4, '상세', bg: _headerColor, bold: true),
        _cell(5, '금액', bg: _headerColor, bold: true, right: true),
        _cell(6, '비고', bg: _headerColor, bold: true),
      ]);

  Widget _dataRow(int i) {
    final row = rows[i];
    final e = row.expense;
    return InkWell(
      onTap: () => onRowTap(e),
      child: Row(children: [
        _cell(0, '${i + 1}', bg: _rowNumColor),
        _cell(1, row.showDate ? formatSheetDate(e.date) : ''),
        _cell(2, paymentNames[e.paymentMethodId] ?? ''),
        _cell(3, categoryNames[e.categoryId] ?? ''),
        _cell(4, e.detail),
        _cell(5, formatWon(e.amount), right: true),
        _cell(6, e.memo ?? ''),
      ]),
    );
  }

  Widget _totalRow() => Row(children: [
        _cell(0, '', bg: _rowNumColor),
        _cell(1, '', bg: _headerColor),
        _cell(2, '', bg: _headerColor),
        _cell(3, '', bg: _headerColor),
        _cell(4, '합계', bg: _headerColor, bold: true),
        _cell(5, formatWon(monthTotal), bg: _headerColor, bold: true, right: true),
        _cell(6, '', bg: _headerColor),
      ]);
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/widgets/ledger_table_test.dart`
Expected: PASS

- [ ] **Step 5: 커밋**

```powershell
git add lib/widgets/ledger_table.dart test/widgets/ledger_table_test.dart
git commit -m "장부 표 위젯 구현 (격자선, 고정 헤더, 합계 행)"
```

---

### Task 8: 월 탭 바 + 메인 화면 + main.dart

**Files:**
- Create: `lib/widgets/month_tab_bar.dart`, `lib/screens/ledger_screen.dart`
- Modify: `lib/main.dart` (flutter create 기본 코드 전체 교체)
- Test: `test/widgets/month_tab_bar_test.dart`

**Interfaces:**
- Consumes: `AppState`, `LedgerTable`, `monthLabel`
- Produces:
  - `class MonthTabBar extends StatelessWidget { const MonthTabBar({required this.months, required this.selected, required this.onSelect, required this.onMenuTap}); }` — months: `List<String>` ('yyyy-MM'), selected: 선택 월, onSelect: `void Function(String)`, onMenuTap: `VoidCallback`
  - `class LedgerScreen extends StatelessWidget` — Provider에서 AppState를 구독해 표/탭/FAB 렌더링. FAB·행 탭은 Task 9의 `showExpenseSheet` 자리에 임시 빈 콜백(`// TODO 없이` 아래 명시된 코드 그대로) → Task 9에서 교체.

- [ ] **Step 1: 실패하는 테스트 작성** — `test/widgets/month_tab_bar_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_money/widgets/month_tab_bar.dart';

void main() {
  testWidgets('월 탭 표시, 선택 강조, 탭/메뉴 콜백', (tester) async {
    String? selected;
    var menuTapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: MonthTabBar(
          months: const ['2025-07', '2025-08', '2025-09'],
          selected: '2025-09',
          onSelect: (m) => selected = m,
          onMenuTap: () => menuTapped = true,
        ),
      ),
    ));
    expect(find.text('2025.7'), findsOneWidget);
    expect(find.text('2025.9'), findsOneWidget);
    await tester.tap(find.text('2025.8'));
    expect(selected, '2025-08');
    await tester.tap(find.byIcon(Icons.menu));
    expect(menuTapped, isTrue);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/widgets/month_tab_bar_test.dart`
Expected: FAIL (컴파일 오류)

- [ ] **Step 3: MonthTabBar 구현** — `lib/widgets/month_tab_bar.dart`

```dart
import 'package:flutter/material.dart';
import '../logic/ledger_rows.dart';

class MonthTabBar extends StatelessWidget {
  const MonthTabBar({
    super.key,
    required this.months,
    required this.selected,
    required this.onSelect,
    required this.onMenuTap,
  });

  final List<String> months;
  final String selected;
  final void Function(String) onSelect;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 52,
        child: Row(children: [
          IconButton(icon: const Icon(Icons.menu), onPressed: onMenuTap),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              reverse: true, // 최신 달이 오른쪽 끝에 보이도록
              children: [
                for (final m in months.reversed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                    child: ChoiceChip(
                      label: Text(monthLabel(m)),
                      selected: m == selected,
                      onSelected: (_) => onSelect(m),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/widgets/month_tab_bar_test.dart`
Expected: PASS

- [ ] **Step 5: 메인 화면 구현** — `lib/screens/ledger_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/app_state.dart';
import '../models/expense.dart';
import '../widgets/ledger_table.dart';
import '../widgets/month_tab_bar.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  void _openExpenseSheet(BuildContext context, {Expense? existing}) {
    // Task 9에서 showExpenseSheet 호출로 교체
  }

  void _openMenu(BuildContext context) {
    // Task 10에서 분류/카드/설정 이동 메뉴로 교체
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: LedgerTable(
          rows: state.rows,
          monthTotal: state.monthTotal,
          categoryNames: {for (final c in state.categories) c.id!: c.name},
          paymentNames: {for (final p in state.paymentMethods) p.id!: p.name},
          onRowTap: (e) => _openExpenseSheet(context, existing: e),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openExpenseSheet(context),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: MonthTabBar(
        months: state.months,
        selected: state.selectedMonth,
        onSelect: (m) => context.read<AppState>().selectMonth(m),
        onMenuTap: () => _openMenu(context),
      ),
    );
  }
}
```

- [ ] **Step 6: main.dart 교체** — `lib/main.dart` 전체를 다음으로 교체

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/app_database.dart';
import 'logic/app_state.dart';
import 'screens/ledger_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openAppDatabase();
  final state = AppState(db: db);
  await state.init();
  runApp(
    ChangeNotifierProvider.value(value: state, child: const MobileMoneyApp()),
  );
}

class MobileMoneyApp extends StatelessWidget {
  const MobileMoneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '가계부',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const LedgerScreen(),
    );
  }
}
```

flutter create가 만든 `test/widget_test.dart`(카운터 테스트)는 더 이상 유효하지 않으므로 삭제한다.

- [ ] **Step 7: 전체 테스트 + 분석 확인**

Run: `flutter test ; flutter analyze`
Expected: `All tests passed!`, `No issues found!`

- [ ] **Step 8: 커밋**

```powershell
git add -A
git commit -m "메인 장부 화면과 월 탭 바 구현"
```

---
### Task 9: 입력 바텀시트 (추가/수정/삭제)

**Files:**
- Create: `lib/screens/expense_sheet.dart`
- Modify: `lib/screens/ledger_screen.dart` (`_openExpenseSheet` 본문 교체)
- Test: `test/widgets/expense_sheet_test.dart`

**Interfaces:**
- Consumes: `AppState` (Provider로 접근), `Expense`, `formatSheetDate`
- Produces:
  - `Future<void> showExpenseSheet(BuildContext context, {Expense? existing})` — `showModalBottomSheet` 기반. `existing == null`이면 추가 모드(날짜 기본값 `state.today`, 결제수단/분류는 목록 첫 항목), 아니면 수정 모드(값 채움 + 삭제 버튼).
  - 저장 시: 추가 모드 → `state.addExpense`, 수정 모드 → `state.updateExpense`. 삭제 버튼 → `AlertDialog` 확인 후 `state.deleteExpense`.
  - 검증: 금액이 비었거나 0 이하이면 저장 버튼이 동작하지 않고 필드에 오류 메시지 '금액을 입력하세요' 표시. 금액 필드는 `keyboardType: TextInputType.number` + 숫자만 허용(`FilteringTextInputFormatter.digitsOnly`).

- [ ] **Step 1: 실패하는 위젯 테스트 작성** — `test/widgets/expense_sheet_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile_money/data/app_database.dart';
import 'package:mobile_money/logic/app_state.dart';
import 'package:mobile_money/models/expense.dart';
import 'package:mobile_money/screens/expense_sheet.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late AppState state;

  setUp(() async {
    db = await openAppDatabase(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    state = AppState(db: db, today: '2025-09-15');
    await state.init();
  });
  tearDown(() => db.close());

  Widget host({Expense? existing}) => ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showExpenseSheet(context, existing: existing),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );

  testWidgets('추가: 금액/상세 입력 후 저장하면 거래가 생긴다', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('detail')), '점심');
    await tester.enterText(find.byKey(const Key('amount')), '12000');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(state.rows.single.expense.detail, '점심');
    expect(state.rows.single.expense.amount, 12000);
    expect(state.rows.single.expense.date, '2025-09-15');
  });

  testWidgets('금액 없이 저장하면 오류 표시, 저장 안 됨', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('금액을 입력하세요'), findsOneWidget);
    expect(state.rows, isEmpty);
  });

  testWidgets('수정: 기존 값이 채워지고 저장 시 갱신', (tester) async {
    await state.addExpense(Expense(
        date: '2025-09-01',
        paymentMethodId: state.paymentMethods.first.id!,
        categoryId: state.categories.first.id!,
        detail: '점심', amount: 12000));
    final saved = state.rows.single.expense;
    await tester.pumpWidget(host(existing: saved));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '점심'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('amount')), '9000');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(state.rows.single.expense.amount, 9000);
  });

  testWidgets('삭제: 확인 후 거래 제거', (tester) async {
    await state.addExpense(Expense(
        date: '2025-09-01',
        paymentMethodId: state.paymentMethods.first.id!,
        categoryId: state.categories.first.id!,
        detail: '점심', amount: 12000));
    final saved = state.rows.single.expense;
    await tester.pumpWidget(host(existing: saved));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(state.rows, isEmpty);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/widgets/expense_sheet_test.dart`
Expected: FAIL (컴파일 오류)

- [ ] **Step 3: 구현** — `lib/screens/expense_sheet.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../logic/app_state.dart';
import '../logic/ledger_rows.dart';
import '../models/expense.dart';

Future<void> showExpenseSheet(BuildContext context, {Expense? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: _ExpenseForm(
          state: context.read<AppState>(), existing: existing),
    ),
  );
}

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm({required this.state, this.existing});
  final AppState state;
  final Expense? existing;

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  late String date;
  late int paymentMethodId;
  late int categoryId;
  late final TextEditingController detailCtrl;
  late final TextEditingController amountCtrl;
  late final TextEditingController memoCtrl;
  String? amountError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    date = e?.date ?? widget.state.today;
    paymentMethodId = e?.paymentMethodId ?? widget.state.paymentMethods.first.id!;
    categoryId = e?.categoryId ?? widget.state.categories.first.id!;
    detailCtrl = TextEditingController(text: e?.detail ?? '');
    amountCtrl = TextEditingController(text: e == null ? '' : '${e.amount}');
    memoCtrl = TextEditingController(text: e?.memo ?? '');
  }

  @override
  void dispose() {
    detailCtrl.dispose();
    amountCtrl.dispose();
    memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initial = DateTime.parse(date);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => date =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _save() async {
    final amount = int.tryParse(amountCtrl.text);
    if (amount == null || amount <= 0) {
      setState(() => amountError = '금액을 입력하세요');
      return;
    }
    final e = Expense(
      id: widget.existing?.id,
      date: date,
      paymentMethodId: paymentMethodId,
      categoryId: categoryId,
      detail: detailCtrl.text.trim(),
      amount: amount,
      memo: memoCtrl.text.trim().isEmpty ? null : memoCtrl.text.trim(),
    );
    if (widget.existing == null) {
      await widget.state.addExpense(e);
    } else {
      await widget.state.updateExpense(e);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: const Text('이 거래를 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('확인')),
        ],
      ),
    );
    if (ok == true) {
      await widget.state.deleteExpense(widget.existing!.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.existing == null ? '지출 입력' : '지출 수정',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(formatSheetDate(date)),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            key: const Key('payment'),
            initialValue: paymentMethodId,
            decoration: const InputDecoration(labelText: '카드/현금'),
            items: [
              for (final p in state.paymentMethods)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() => paymentMethodId = v!),
          ),
          DropdownButtonFormField<int>(
            key: const Key('category'),
            initialValue: categoryId,
            decoration: const InputDecoration(labelText: '사용용도'),
            items: [
              for (final c in state.categories)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => setState(() => categoryId = v!),
          ),
          TextField(
            key: const Key('detail'),
            controller: detailCtrl,
            decoration: const InputDecoration(labelText: '상세'),
          ),
          TextField(
            key: const Key('amount'),
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration:
                InputDecoration(labelText: '금액(원)', errorText: amountError),
          ),
          TextField(
            key: const Key('memo'),
            controller: memoCtrl,
            decoration: const InputDecoration(labelText: '비고 (선택)'),
          ),
          const SizedBox(height: 16),
          Row(children: [
            if (widget.existing != null)
              TextButton(
                onPressed: _delete,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('삭제'),
              ),
            const Spacer(),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소')),
            const SizedBox(width: 8),
            FilledButton(onPressed: _save, child: const Text('저장')),
          ]),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: ledger_screen 연결** — `lib/screens/ledger_screen.dart`의 `_openExpenseSheet`를 다음으로 교체하고 import에 `import 'expense_sheet.dart';` 추가:

```dart
  void _openExpenseSheet(BuildContext context, {Expense? existing}) {
    showExpenseSheet(context, existing: existing);
  }
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 6: 커밋**

```powershell
git add lib/screens test/widgets/expense_sheet_test.dart
git commit -m "지출 입력/수정/삭제 바텀시트 구현"
```

---

### Task 10: 분류 관리 + 카드 관리 화면 + ☰ 메뉴 연결

두 화면은 구조가 같으므로 한 태스크로 묶는다. 목록/추가/이름수정/삭제(사용 중이면 경고 문구 포함 확인창) UI.

**Files:**
- Create: `lib/screens/category_screen.dart`, `lib/screens/payment_method_screen.dart`
- Modify: `lib/screens/ledger_screen.dart` (`_openMenu` 교체)
- Test: `test/widgets/category_screen_test.dart`

**Interfaces:**
- Consumes: `AppState` (categories/paymentMethods 목록과 add/rename/remove/usage 메서드)
- Produces: `class CategoryScreen extends StatelessWidget`, `class PaymentMethodScreen extends StatelessWidget` — 둘 다 인자 없는 일반 라우트

- [ ] **Step 1: 실패하는 위젯 테스트 작성** — `test/widgets/category_screen_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile_money/data/app_database.dart';
import 'package:mobile_money/logic/app_state.dart';
import 'package:mobile_money/screens/category_screen.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late AppState state;

  setUp(() async {
    db = await openAppDatabase(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    state = AppState(db: db, today: '2025-09-15');
    await state.init();
  });
  tearDown(() => db.close());

  Widget host() => ChangeNotifierProvider.value(
      value: state, child: const MaterialApp(home: CategoryScreen()));

  testWidgets('기본 분류 8종이 표시된다', (tester) async {
    await tester.pumpWidget(host());
    for (final name in ['식사', '간식', '기타']) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('분류 추가', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '병원');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('병원'), findsOneWidget);
  });

  testWidgets('기타에는 삭제 버튼이 없다', (tester) async {
    await tester.pumpWidget(host());
    final etcTile = find.widgetWithText(ListTile, '기타');
    expect(find.descendant(of: etcTile, matching: find.byIcon(Icons.delete)),
        findsNothing);
    final mealTile = find.widgetWithText(ListTile, '식사');
    expect(find.descendant(of: mealTile, matching: find.byIcon(Icons.delete)),
        findsOneWidget);
  });

  testWidgets('삭제 확인 후 목록에서 제거', (tester) async {
    await tester.pumpWidget(host());
    final mealTile = find.widgetWithText(ListTile, '식사');
    await tester.tap(
        find.descendant(of: mealTile, matching: find.byIcon(Icons.delete)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('식사'), findsNothing);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/widgets/category_screen_test.dart`
Expected: FAIL (컴파일 오류)

- [ ] **Step 3: 구현** — `lib/screens/category_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/app_state.dart';

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  Future<String?> _nameDialog(BuildContext context, {String? initial}) {
    final ctrl = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(initial == null ? '분류 추가' : '이름 수정'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소')),
          TextButton(
              onPressed: () {
                final name = ctrl.text.trim();
                if (name.isNotEmpty) Navigator.pop(dialogContext, name);
              },
              child: const Text('저장')),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, AppState state, int id, String name) async {
    final usage = await state.categoryUsage(id);
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(usage > 0
            ? "'$name' 분류를 쓰는 거래 $usage건이 '기타'로 바뀝니다. 삭제할까요?"
            : "'$name' 분류를 삭제할까요?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('확인')),
        ],
      ),
    );
    if (ok == true) await state.removeCategory(id);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('분류 관리')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final name = await _nameDialog(context);
          if (name != null) await state.addCategory(name);
        },
        child: const Icon(Icons.add),
      ),
      body: ListView(
        children: [
          for (final c in state.categories)
            ListTile(
              title: Text(c.name),
              onTap: () async {
                final name = await _nameDialog(context, initial: c.name);
                if (name != null) await state.renameCategory(c.id!, name);
              },
              trailing: c.isDefault
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () =>
                          _confirmDelete(context, state, c.id!, c.name),
                    ),
            ),
        ],
      ),
    );
  }
}
```

`lib/screens/payment_method_screen.dart` — 동일 구조로 작성. 차이점: 클래스명 `PaymentMethodScreen`, AppBar 제목 '카드 관리', 다이얼로그 제목 '카드 추가', 목록 `state.paymentMethods`, 메서드 `addPaymentMethod`/`renamePaymentMethod`/`removePaymentMethod`/`paymentMethodUsage`, 삭제 안내 문구 `"'$name' 카드를 쓰는 거래 $usage건이 '현금'으로 바뀝니다. 삭제할까요?"`.

- [ ] **Step 4: ☰ 메뉴 연결** — `lib/screens/ledger_screen.dart`의 `_openMenu`를 다음으로 교체하고 import 3줄(`category_screen.dart`, `payment_method_screen.dart`, `settings_screen.dart`는 Task 12에서 추가하므로 지금은 앞의 2개만) 추가:

```dart
  void _openMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('분류 관리'),
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CategoryScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.credit_card),
            title: const Text('카드 관리'),
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const PaymentMethodScreen()));
            },
          ),
        ]),
      ),
    );
  }
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `flutter test ; flutter analyze`
Expected: `All tests passed!`, `No issues found!`

- [ ] **Step 6: 커밋**

```powershell
git add lib/screens test/widgets/category_screen_test.dart
git commit -m "분류/카드 관리 화면과 메뉴 구현"
```

---
### Task 11: 백업 JSON 직렬화/역직렬화

**Files:**
- Create: `lib/data/backup_codec.dart`
- Test: `test/data/backup_codec_test.dart`

**Interfaces:**
- Consumes: `Database` (sqflite)
- Produces:
  - `Future<String> exportBackupJson(Database db)` — 세 테이블 전체를 `{"version": 1, "categories": [...], "payment_methods": [...], "expenses": [...]}` JSON 문자열로
  - `Future<void> importBackupJson(Database db, String json)` — 트랜잭션 안에서 세 테이블을 비우고 JSON 내용으로 교체 (id 보존). version이 1이 아니면 `FormatException` throw.

- [ ] **Step 1: 실패하는 테스트 작성** — `test/data/backup_codec_test.dart`

```dart
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
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/data/backup_codec_test.dart`
Expected: FAIL (컴파일 오류)

- [ ] **Step 3: 구현** — `lib/data/backup_codec.dart`

```dart
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
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/data/backup_codec_test.dart`
Expected: PASS

- [ ] **Step 5: 커밋**

```powershell
git add lib/data/backup_codec.dart test/data/backup_codec_test.dart
git commit -m "백업 JSON 직렬화/역직렬화 구현"
```

---

### Task 12: 구글 로그인 + 드라이브 백업/복원 + 설정 화면

드라이브 API는 실기기+실계정으로만 검증 가능하므로, 이 태스크는 BackupService의 상태 로직만 가짜 업로더로 단위 테스트하고 드라이브 연동 자체는 Task 13에서 수동 확인한다.

**Files:**
- Create: `lib/sync/drive_sync.dart`, `lib/sync/backup_service.dart`, `lib/screens/settings_screen.dart`
- Modify: `lib/main.dart` (BackupService 배선 + onDataChanged 연결), `lib/screens/ledger_screen.dart` (_openMenu에 설정 항목 추가)
- Test: `test/sync/backup_service_test.dart`

**Interfaces:**
- Consumes: `exportBackupJson`, `importBackupJson`, `AppState.reloadAll`, `AppState.onDataChanged`
- Produces:

```dart
// drive_sync.dart — 드라이브 연동 구현체 (테스트에서는 사용 안 함)
abstract class RemoteStore {
  bool get signedIn;
  String? get accountEmail;
  Future<bool> signIn();          // 성공 여부
  Future<void> signOut();
  Future<void> upload(String json);   // 실패 시 Exception throw
  Future<String?> download();         // 백업 없으면 null
}
class DriveSync implements RemoteStore { ... }

// backup_service.dart
class BackupService extends ChangeNotifier {
  BackupService({required this.remote, required this.db, SharedPreferences? prefs});
  bool autoBackup;                // SharedPreferences 'auto_backup' 유지
  DateTime? lastBackupAt;         // 'last_backup_at' (ISO 문자열) 유지
  String? lastError;              // 최근 백업 실패 메시지 (성공 시 null)
  bool busy;                      // 업로드/복원 진행 중
  Future<bool>? lastAutoBackup;   // onDataChanged가 시작한 백업 (테스트 대기용)
  Future<bool> signIn();          // remote.signIn 후 notifyListeners
  Future<void> signOut();         // remote.signOut + 자동백업 끔
  Future<void> setAutoBackup(bool on);
  Future<bool> backupNow();       // export → remote.upload, 성공 시 시각 기록
  Future<bool> restore();         // remote.download → importBackupJson (null이면 false)
  void onDataChanged();           // autoBackup && signedIn 이면 lastAutoBackup = backupNow()
}
```

화면은 로그인/로그아웃을 반드시 BackupService의 `signIn()`/`signOut()`으로 호출한다 (`notifyListeners()`는 protected라 외부 호출 시 analyze 경고).

- [ ] **Step 1: 실패하는 테스트 작성** — `test/sync/backup_service_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile_money/data/app_database.dart';
import 'package:mobile_money/sync/backup_service.dart';
import 'package:mobile_money/sync/drive_sync.dart';

class FakeRemote implements RemoteStore {
  bool _signedIn = true;
  String? stored;
  bool failNext = false;
  int uploadCount = 0;

  @override
  bool get signedIn => _signedIn;
  @override
  String? get accountEmail => _signedIn ? 'test@gmail.com' : null;
  @override
  Future<bool> signIn() async => _signedIn = true;
  @override
  Future<void> signOut() async => _signedIn = false;
  @override
  Future<void> upload(String json) async {
    uploadCount++;
    if (failNext) throw Exception('네트워크 오류');
    stored = json;
  }
  @override
  Future<String?> download() async => stored;
}

void main() {
  sqfliteFfiInit();
  late Database db;
  late FakeRemote remote;
  late BackupService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await openAppDatabase(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    remote = FakeRemote();
    service = BackupService(
        remote: remote, db: db, prefs: await SharedPreferences.getInstance());
  });
  tearDown(() => db.close());

  test('backupNow 성공: 업로드되고 시각 기록, 오류 없음', () async {
    expect(await service.backupNow(), isTrue);
    expect(remote.stored, contains('"version":1'));
    expect(service.lastBackupAt, isNotNull);
    expect(service.lastError, isNull);
  });

  test('backupNow 실패: 오류 저장, 앱은 계속', () async {
    remote.failNext = true;
    expect(await service.backupNow(), isFalse);
    expect(service.lastError, isNotNull);
  });

  test('restore: 백업 없으면 false, 있으면 DB 교체', () async {
    expect(await service.restore(), isFalse);
    await db.insert('expenses', {
      'date': '2025-09-01', 'payment_method_id': 1,
      'category_id': 1, 'detail': '점심', 'amount': 12000,
    });
    await service.backupNow();
    await db.delete('expenses');
    expect(await service.restore(), isTrue);
    expect((await db.query('expenses')).single['detail'], '점심');
  });

  test('onDataChanged: 자동백업 켜짐+로그인 시에만 업로드', () async {
    await service.setAutoBackup(false);
    service.onDataChanged();
    expect(service.lastAutoBackup, isNull);
    expect(remote.uploadCount, 0);

    await service.setAutoBackup(true);
    service.onDataChanged();
    await service.lastAutoBackup;
    expect(remote.uploadCount, 1);

    await service.signOut();
    service.onDataChanged();
    await service.lastAutoBackup;
    expect(remote.uploadCount, 1); // 로그아웃 상태라 새 업로드 없음
  });

  test('autoBackup 설정이 SharedPreferences에 유지된다', () async {
    await service.setAutoBackup(true);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('auto_backup'), isTrue);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/sync/backup_service_test.dart`
Expected: FAIL (컴파일 오류)

- [ ] **Step 3: RemoteStore/DriveSync 구현** — `lib/sync/drive_sync.dart`

```dart
import 'dart:convert';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

abstract class RemoteStore {
  bool get signedIn;
  String? get accountEmail;
  Future<bool> signIn();
  Future<void> signOut();
  Future<void> upload(String json);
  Future<String?> download();
}

const _backupFileName = 'mobile_money_backup.json';

class DriveSync implements RemoteStore {
  final _google = GoogleSignIn(scopes: [drive.DriveApi.driveAppdataScope]);
  GoogleSignInAccount? _account;

  @override
  bool get signedIn => _account != null;

  @override
  String? get accountEmail => _account?.email;

  @override
  Future<bool> signIn() async {
    _account = await _google.signInSilently() ?? await _google.signIn();
    return _account != null;
  }

  @override
  Future<void> signOut() async {
    await _google.signOut();
    _account = null;
  }

  Future<drive.DriveApi> _api() async {
    final client = await _google.authenticatedClient();
    if (client == null) throw Exception('구글 인증이 만료되었습니다. 다시 로그인하세요.');
    return drive.DriveApi(client);
  }

  Future<String?> _findFileId(drive.DriveApi api) async {
    final list = await api.files.list(
        spaces: 'appDataFolder', q: "name = '$_backupFileName'");
    final files = list.files ?? [];
    return files.isEmpty ? null : files.first.id;
  }

  @override
  Future<void> upload(String json) async {
    final api = await _api();
    final bytes = utf8.encode(json);
    final media = drive.Media(Stream.value(bytes), bytes.length);
    final existingId = await _findFileId(api);
    if (existingId == null) {
      await api.files.create(
        drive.File()
          ..name = _backupFileName
          ..parents = ['appDataFolder'],
        uploadMedia: media,
      );
    } else {
      await api.files.update(drive.File(), existingId, uploadMedia: media);
    }
  }

  @override
  Future<String?> download() async {
    final api = await _api();
    final id = await _findFileId(api);
    if (id == null) return null;
    final media = await api.files.get(id,
        downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final bytes = await media.stream.expand((c) => c).toList();
    return utf8.decode(bytes);
  }
}
```

- [ ] **Step 4: BackupService 구현** — `lib/sync/backup_service.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../data/backup_codec.dart';
import 'drive_sync.dart';

class BackupService extends ChangeNotifier {
  BackupService({required this.remote, required this.db, SharedPreferences? prefs})
      : _prefs = prefs {
    final saved = _prefs?.getString('last_backup_at');
    if (saved != null) lastBackupAt = DateTime.tryParse(saved);
    autoBackup = _prefs?.getBool('auto_backup') ?? false;
  }

  final RemoteStore remote;
  final Database db;
  final SharedPreferences? _prefs;

  bool autoBackup = false;
  DateTime? lastBackupAt;
  String? lastError;
  bool busy = false;
  Future<bool>? lastAutoBackup;

  Future<bool> signIn() async {
    final ok = await remote.signIn();
    notifyListeners();
    return ok;
  }

  Future<void> signOut() async {
    await remote.signOut();
    await setAutoBackup(false);
  }

  Future<void> setAutoBackup(bool on) async {
    autoBackup = on;
    await _prefs?.setBool('auto_backup', on);
    notifyListeners();
  }

  Future<bool> backupNow() async {
    busy = true;
    notifyListeners();
    try {
      final json = await exportBackupJson(db);
      await remote.upload(json);
      lastBackupAt = DateTime.now();
      await _prefs?.setString('last_backup_at', lastBackupAt!.toIso8601String());
      lastError = null;
      return true;
    } catch (e) {
      lastError = '$e';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> restore() async {
    busy = true;
    notifyListeners();
    try {
      final json = await remote.download();
      if (json == null) return false;
      await importBackupJson(db, json);
      lastError = null;
      return true;
    } catch (e) {
      lastError = '$e';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void onDataChanged() {
    if (!autoBackup || !remote.signedIn || busy) return;
    lastAutoBackup = backupNow(); // await 하지 않음 — 화면을 막지 않는다
  }
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `flutter test test/sync/backup_service_test.dart`
Expected: PASS

- [ ] **Step 6: 설정 화면 구현** — `lib/screens/settings_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/app_state.dart';
import '../sync/backup_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final backup = context.watch<BackupService>();
    final remote = backup.remote;

    Future<void> guarded(Future<void> Function() action) async {
      try {
        await action();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(children: [
        ListTile(
          leading: const Icon(Icons.account_circle),
          title: Text(remote.signedIn ? remote.accountEmail! : '구글 로그인'),
          subtitle: Text(remote.signedIn ? '로그인됨' : '드라이브 백업에 필요합니다'),
          trailing: TextButton(
            child: Text(remote.signedIn ? '로그아웃' : '로그인'),
            onPressed: () => guarded(() async {
              if (remote.signedIn) {
                await backup.signOut();
              } else {
                await backup.signIn();
              }
            }),
          ),
        ),
        SwitchListTile(
          title: const Text('드라이브 자동 백업'),
          subtitle: const Text('거래를 저장할 때마다 내 드라이브에 백업'),
          value: backup.autoBackup,
          onChanged: remote.signedIn
              ? (v) => backup.setAutoBackup(v)
              : null,
        ),
        ListTile(
          title: const Text('지금 백업'),
          enabled: remote.signedIn && !backup.busy,
          trailing: backup.busy
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.backup),
          onTap: () => guarded(() async {
            final ok = await backup.backupNow();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? '백업 완료' : '백업 실패: ${backup.lastError}')));
            }
          }),
        ),
        ListTile(
          title: const Text('드라이브에서 복원'),
          subtitle: const Text('현재 폰의 데이터를 백업 내용으로 덮어씁니다'),
          enabled: remote.signedIn && !backup.busy,
          trailing: const Icon(Icons.restore),
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                content: const Text('현재 폰의 모든 데이터를 드라이브 백업으로 덮어씁니다. 계속할까요?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('취소')),
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('확인')),
                ],
              ),
            );
            if (ok != true || !context.mounted) return;
            final restored = await backup.restore();
            if (restored && context.mounted) {
              await context.read<AppState>().reloadAll();
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(restored
                      ? '복원 완료'
                      : '복원 실패: ${backup.lastError ?? "드라이브에 백업이 없습니다"}')));
            }
          },
        ),
        if (backup.lastBackupAt != null)
          ListTile(
            title: const Text('마지막 백업'),
            subtitle: Text('${backup.lastBackupAt}'),
          ),
        if (backup.lastError != null)
          ListTile(
            title: const Text('백업 안 됨'),
            subtitle: Text(backup.lastError!,
                style: const TextStyle(color: Colors.red)),
          ),
      ]),
    );
  }
}
```

- [ ] **Step 7: main.dart 배선 + 메뉴에 설정 추가**

`lib/main.dart`의 `main()`을 다음으로 교체 (import에 `sync/drive_sync.dart`, `sync/backup_service.dart`, `package:shared_preferences/shared_preferences.dart` 추가):

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openAppDatabase();
  final state = AppState(db: db);
  await state.init();
  final backup = BackupService(
      remote: DriveSync(),
      db: db,
      prefs: await SharedPreferences.getInstance());
  state.onDataChanged = backup.onDataChanged;
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: state),
      ChangeNotifierProvider.value(value: backup),
    ],
    child: const MobileMoneyApp(),
  ));
}
```

`lib/screens/ledger_screen.dart`의 `_openMenu` Column 마지막에 항목 추가 (import `settings_screen.dart` 추가):

```dart
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('설정'),
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
```

- [ ] **Step 8: 구글 클라우드 콘솔 설정 (수동, 사용자와 함께)**

앱 실행 전 1회 필요. 사용자에게 안내:

1. https://console.cloud.google.com 에서 새 프로젝트 생성 (이름: mobile-money)
2. "API 및 서비스 → 라이브러리"에서 **Google Drive API** 사용 설정
3. "API 및 서비스 → OAuth 동의 화면": User Type=외부, 앱 이름/이메일 입력, 범위에 `.../auth/drive.appdata` 추가, 테스트 사용자에 본인 지메일 추가 (테스트 모드로 충분 — 게시 불필요)
4. "사용자 인증 정보 → 사용자 인증 정보 만들기 → OAuth 클라이언트 ID": 유형=Android, 패키지 이름=`com.mobilemoney.mobile_money`, SHA-1은 아래 명령으로 확인:

```powershell
cd D:\projects\mobile_money\android
.\gradlew signingReport
# 출력 중 Variant: debug 의 SHA1 값을 복사
```

(google_sign_in의 Android는 클라이언트 ID를 코드에 넣을 필요 없음 — 패키지명+SHA-1 매칭으로 동작)

- [ ] **Step 9: 전체 테스트 + 분석**

Run: `flutter test ; flutter analyze`
Expected: `All tests passed!`, `No issues found!`

- [ ] **Step 10: 커밋**

```powershell
git add -A
git commit -m "구글 드라이브 백업/복원과 설정 화면 구현"
```

---

### Task 13: 최종 검증 (실기기/에뮬레이터)

수동 검증 태스크. superpowers:verification-before-completion 스킬 적용.

- [ ] **Step 1: 전체 자동 검증**

Run: `flutter test ; flutter analyze`
Expected: `All tests passed!`, `No issues found!`

- [ ] **Step 2: 릴리즈 APK 빌드**

Run: `flutter build apk --release`
Expected: `√ Built build\app\outputs\flutter-apk\app-release.apk`

- [ ] **Step 3: 기기에서 수동 확인 (사용자와 함께)**

폰을 USB로 연결(개발자 옵션+USB 디버깅 켜기) 후 `flutter run --release` 또는 APK 직접 설치. 확인 목록:

1. 거래 3건 입력(같은 날 2건 포함) → 표에 시트처럼 표시되는지 (날짜 첫 행만, 합계 행)
2. 행 탭 → 수정/삭제 동작
3. 월 탭 전환, 과거 날짜 입력 시 해당 월 탭 자동 생성
4. 분류/카드 추가 후 입력창 드롭다운에 반영
5. 설정 → 구글 로그인 → 지금 백업 → 성공 메시지
6. 앱 데이터 삭제(또는 거래 하나 지운 뒤) → 복원 → 데이터 복귀
7. 자동 백업 켜고 거래 추가 → 마지막 백업 시각 갱신

- [ ] **Step 4: 마무리 커밋**

수동 확인 중 수정 사항이 있으면 반영 후:

```powershell
git add -A
git commit -m "실기기 검증 및 마무리"
```

이후 superpowers:finishing-a-development-branch 스킬로 마무리.





