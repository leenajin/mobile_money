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
