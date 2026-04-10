import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../models/rdv_report.dart';
import 'database_service.dart';
import 'photo_service.dart';

class ReportProvider extends ChangeNotifier {
  final _db = DatabaseService();

  List<RdvReport> _reports = [];
  List<Expense> _currentExpenses = [];
  RdvReport? _currentReport;
  bool _loading = false;

  // Caminhos das fotos capturadas no relatório atual (para Anexos no PDF)
  final List<String> _photoPaths = [];

  List<RdvReport> get reports => _reports;
  List<Expense> get currentExpenses => _currentExpenses;
  RdvReport? get currentReport => _currentReport;
  bool get loading => _loading;
  List<String> get photoPaths => List.unmodifiable(_photoPaths);

  List<Expense> get combustivel => _currentExpenses
      .where((e) => e.category == ExpenseCategory.combustivel)
      .toList();
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
    _photoPaths.clear();
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
    _photoPaths.clear();
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
      _photoPaths.clear();
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

  // Gerenciamento de fotos para os Anexos
  // Copia para diretório permanente antes de guardar o path
  Future<void> addPhoto(String tempPath) async {
    final permanentPath = await PhotoService.savePermanently(tempPath);
    _photoPaths.add(permanentPath);
    notifyListeners();
  }

  Future<void> removePhoto(int index) async {
    if (index >= 0 && index < _photoPaths.length) {
      await PhotoService.deletePhoto(_photoPaths[index]);
      _photoPaths.removeAt(index);
      notifyListeners();
    }
  }
}
