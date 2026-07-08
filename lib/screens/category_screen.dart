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
