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
        factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    state = AppState(db, '2025-09-15');
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

  testWidgets('중복 이름 추가 시 경고 표시, 목록 변화 없음', (tester) async {
    await tester.pumpWidget(host());
    final before = state.categories.length;
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '식사');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('이미 있는 이름입니다'), findsOneWidget);
    expect(state.categories.length, before);
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
