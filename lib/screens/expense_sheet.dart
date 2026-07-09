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
            decoration: const InputDecoration(labelText: '지출처 (카드/현금)'),
            items: [
              for (final p in state.paymentMethods)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() => paymentMethodId = v!),
          ),
          DropdownButtonFormField<int>(
            key: const Key('category'),
            initialValue: categoryId,
            decoration: const InputDecoration(labelText: '분류'),
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
