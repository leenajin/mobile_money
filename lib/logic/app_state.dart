import 'package:flutter/foundation.dart' hide Category;
import 'package:sqflite/sqflite.dart';
import '../data/category_repository.dart';
import '../data/expense_repository.dart';
import '../data/payment_method_repository.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/payment_method.dart';
import 'ledger_rows.dart';

class AppState extends ChangeNotifier {
  AppState({required Database db, String? today})
      : _expenses = ExpenseRepository(db),
        _categories = CategoryRepository(db),
        _payments = PaymentMethodRepository(db),
        _today = today;

  final ExpenseRepository _expenses;
  final CategoryRepository _categories;
  final PaymentMethodRepository _payments;
  final String? _today;

  List<String> months = [];
  String selectedMonth = '';
  List<LedgerRow> rows = [];
  int monthTotal = 0;
  List<Category> categories = [];
  List<PaymentMethod> paymentMethods = [];
  void Function()? onDataChanged;

  String get today {
    if (_today != null) return _today!;
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String get _currentMonth => today.substring(0, 7);

  Future<void> init() async {
    selectedMonth = _currentMonth;
    await reloadAll();
  }

  Future<void> reloadAll() async {
    categories = await _categories.getAll();
    paymentMethods = await _payments.getAll();
    await _reloadLedger();
  }

  Future<void> _reloadLedger() async {
    final withData = await _expenses.monthsWithData();
    months = {...withData, _currentMonth}.toList()..sort();
    if (!months.contains(selectedMonth)) selectedMonth = months.last;
    rows = buildLedgerRows(await _expenses.byMonth(selectedMonth));
    monthTotal = await _expenses.monthTotal(selectedMonth);
    notifyListeners();
  }

  Future<void> selectMonth(String yearMonth) async {
    selectedMonth = yearMonth;
    await _reloadLedger();
  }

  Future<void> addExpense(Expense e) async {
    await _expenses.add(e);
    await _reloadLedger();
    onDataChanged?.call();
  }

  Future<void> updateExpense(Expense e) async {
    await _expenses.update(e);
    await _reloadLedger();
    onDataChanged?.call();
  }

  Future<void> deleteExpense(int id) async {
    await _expenses.remove(id);
    await _reloadLedger();
    onDataChanged?.call();
  }

  Future<void> addCategory(String name) async {
    await _categories.add(name);
    categories = await _categories.getAll();
    notifyListeners();
    onDataChanged?.call();
  }

  Future<void> renameCategory(int id, String name) async {
    await _categories.rename(id, name);
    categories = await _categories.getAll();
    notifyListeners();
    onDataChanged?.call();
  }

  Future<void> removeCategory(int id) async {
    await _categories.remove(id);
    categories = await _categories.getAll();
    await _reloadLedger(); // 재할당 반영
    onDataChanged?.call();
  }

  Future<int> categoryUsage(int id) => _categories.usageCount(id);

  Future<void> addPaymentMethod(String name) async {
    await _payments.add(name);
    paymentMethods = await _payments.getAll();
    notifyListeners();
    onDataChanged?.call();
  }

  Future<void> renamePaymentMethod(int id, String name) async {
    await _payments.rename(id, name);
    paymentMethods = await _payments.getAll();
    notifyListeners();
    onDataChanged?.call();
  }

  Future<void> removePaymentMethod(int id) async {
    await _payments.remove(id);
    paymentMethods = await _payments.getAll();
    await _reloadLedger();
    onDataChanged?.call();
  }

  Future<int> paymentMethodUsage(int id) => _payments.usageCount(id);
}
