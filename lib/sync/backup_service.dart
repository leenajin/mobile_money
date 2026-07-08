import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../data/backup_codec.dart';
import 'drive_sync.dart';

class BackupService extends ChangeNotifier {
  BackupService({required this.remote, required this.db, this.prefs}) {
    final saved = prefs?.getString('last_backup_at');
    if (saved != null) lastBackupAt = DateTime.tryParse(saved);
    autoBackup = prefs?.getBool('auto_backup') ?? false;
  }

  final RemoteStore remote;
  final Database db;
  final SharedPreferences? prefs;

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
    await prefs?.setBool('auto_backup', on);
    notifyListeners();
  }

  Future<bool> backupNow() async {
    busy = true;
    notifyListeners();
    try {
      final json = await exportBackupJson(db);
      await remote.upload(json);
      lastBackupAt = DateTime.now();
      await prefs?.setString('last_backup_at', lastBackupAt!.toIso8601String());
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
