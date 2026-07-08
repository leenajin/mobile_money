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
  Future<bool> signInSilently() async => _signedIn;
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

  test('restoreSession: 세션 복원 성공 시 리스너 호출, 실패 시 호출 안 함', () async {
    var notifyCount = 0;
    service.addListener(() => notifyCount++);

    await service.restoreSession(); // remote는 기본적으로 로그인 상태 → 성공
    expect(notifyCount, 1);

    await remote.signOut();
    await service.restoreSession(); // 로그아웃 상태 → 복원 실패
    expect(notifyCount, 1); // 변화 없음
  });
}
