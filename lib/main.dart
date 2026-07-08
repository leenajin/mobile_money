import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/app_database.dart';
import 'logic/app_state.dart';
import 'screens/ledger_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openAppDatabase();
  final state = AppState(db);
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
