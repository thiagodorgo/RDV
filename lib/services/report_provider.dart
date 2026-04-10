import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../models/rdv_report.dart';
import 'database_service.dart';

class ReportProvider extends ChangeNotifier {
  final _db = DatabaseService();

  List<RdvReport> _reports = [];
  List<Expense> _currentExpenses = [];
  RdvReport? _currentReport;
  bool _loading = false;

  List<RdvReport> get reports => _reports;
  List<Expense> get currentExpenses => _currentExpenses;
  RdvReport? get currentReport => _currentReport;
  bool get loading => _loading;

  List<Expense> get combustivel =>
      _currentExpenses.where((e) => e.category == ExpenseCategory.combustivel).toList();
  List<Expense> get hotel =>
      _currentExpenses.where((e) => e.category == ExpenseCategory.hotel).toList();
  List<Expense> get outros =>
      _currentExpenses.where((e) => e.category == ExpenseCategory.outros).toList();

  double get totalCombustivel =>
      combustivel.fold(0.0, (s, e) => s + e.amount);
  double get totalHotel => hotel.fold(0.0, (s, e) => s + e.amount);
  double get totalOutros => outros.fold(0.0, (s, e) => s + e.amount);
  double get totalGeral => totalCombustivel + totalHotel + totalOutros;

  Future<void> loadReports() async {
    _loading = true;
    notifyListeners();
    _reports = await _db.getReports();
    _loading = false;
    notifyListeners();
  }

  Future<void> selectReport(int id) async {
    _currentReport = await _db.getReport(id);
    await loadExpenses(id);
    notifyListeners();
  }

  Future<void> loadExpenses(int reportId) async {
    _currentExpenses = await _db.getExpensesByReport(reportId);
    notifyListeners();
  }

  Future<int> createReport(RdvReport report) async {
    final id = await _db.insertReport(report);
    _currentReport = report.copyWith(id: id);
    _currentExpenses = [];
    await loadReports();
    notifyListeners();
    return id;
  }

  Future<void> updateReport(RdvReport report) async {
    await _db.updateReport(report);
    _currentReport = report;
    await loadReports();
    notifyListeners();
  }

  Future<void> deleteReport(int id) async {
    await _db.deleteReport(id);
    if (_currentReport?.id == id) {
      _currentReport = null;
      _currentExpenses = [];
    }
    await loadReports();
    notifyListeners();
  }

  Future<void> addExpense(Expense expense) async {
    await _db.insertExpense(expense);
    if (_currentReport != null) await loadExpenses(_currentReport!.id!);
    notifyListeners();
  }

  Future<void> updateExpense(Expense expense) async {
    await _db.updateExpense(expense);
    if (_currentReport != null) await loadExpenses(_currentReport!.id!);
    notifyListeners();
  }

  Future<void> removeExpense(int id) async {
    await _db.deleteExpense(id);
    _currentExpenses.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}
