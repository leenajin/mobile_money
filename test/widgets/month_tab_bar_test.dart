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
