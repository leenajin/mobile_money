import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/app_state.dart';

class PaymentMethodScreen extends StatelessWidget {
  const PaymentMethodScreen({super.key});

  Future<String?> _nameDialog(BuildContext context, {String? initial}) {
    final ctrl = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(initial == null ? '카드 추가' : '이름 수정'),
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
    final usage = await state.paymentMethodUsage(id);
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(usage > 0
            ? "'$name' 카드를 쓰는 거래 $usage건이 '현금'으로 바뀝니다. 삭제할까요?"
            : "'$name' 카드를 삭제할까요?"),
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
    if (ok == true) await state.removePaymentMethod(id);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('카드 관리')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final name = await _nameDialog(context);
          if (name != null) await state.addPaymentMethod(name);
        },
        child: const Icon(Icons.add),
      ),
      body: ListView(
        children: [
          for (final p in state.paymentMethods)
            ListTile(
              title: Text(p.name),
              onTap: () async {
                final name = await _nameDialog(context, initial: p.name);
                if (name != null) await state.renamePaymentMethod(p.id!, name);
              },
              trailing: p.isDefault
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () =>
                          _confirmDelete(context, state, p.id!, p.name),
                    ),
            ),
        ],
      ),
    );
  }
}
