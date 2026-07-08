import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'data/app_database.dart';
import 'logic/app_state.dart';
import 'screens/ledger_screen.dart';
import 'sync/backup_service.dart';
import 'sync/drive_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  final db = await openAppDatabase();
  final state = AppState(db);
  await state.init();
  final backup = BackupService(
      remote: DriveSync(),
      db: db,
      prefs: await SharedPreferences.getInstance());
  state.onDataChanged = backup.onDataChanged;
  backup.restoreSession(); // 로그인 세션 복원 — await 하지 않음(시작을 막지 않는다)
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: state),
      ChangeNotifierProvider.value(value: backup),
    ],
    child: const MobileMoneyApp(),
  ));
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
