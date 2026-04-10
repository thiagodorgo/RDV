import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense.dart';
import '../models/rdv_report.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'rdv.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee TEXT NOT NULL,
        role TEXT NOT NULL,
        origin INTEGER NOT NULL,
        obra TEXT NOT NULL,
        order_number TEXT,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        city TEXT NOT NULL,
        period TEXT NOT NULL,
        advance REAL DEFAULT 0.0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id INTEGER NOT NULL,
        category INTEGER NOT NULL,
        date TEXT NOT NULL,
        establishment TEXT NOT NULL,
        city TEXT NOT NULL,
        uf TEXT NOT NULL,
        amount REAL NOT NULL,
        observations TEXT,
        km TEXT,
        FOREIGN KEY (report_id) REFERENCES reports(id) ON DELETE CASCADE
      )
    ''');
  }

  // ── Reports ──────────────────────────────────────────────────────────────

  Future<int> insertReport(RdvReport report) async {
    final db = await database;
    return await db.insert('reports', report.toMap()..remove('id'));
  }

  Future<List<RdvReport>> getReports() async {
    final db = await database;
    final maps = await db.query('reports', orderBy: 'created_at DESC');
    return maps.map((m) => RdvReport.fromMap(m)).toList();
  }

  Future<RdvReport?> getReport(int id) async {
    final db = await database;
    final maps = await db.query('reports', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return RdvReport.fromMap(maps.first);
  }

  Future<int> updateReport(RdvReport report) async {
    final db = await database;
    return await db.update(
      'reports',
      report.toMap(),
      where: 'id = ?',
      whereArgs: [report.id],
    );
  }

  Future<int> deleteReport(int id) async {
    final db = await database;
    await db.delete('expenses', where: 'report_id = ?', whereArgs: [id]);
    return await db.delete('reports', where: 'id = ?', whereArgs: [id]);
  }

  // ── Expenses ─────────────────────────────────────────────────────────────

  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    return await db.insert('expenses', expense.toMap()..remove('id'));
  }

  Future<List<Expense>> getExpensesByReport(int reportId) async {
    final db = await database;
    final maps = await db.query(
      'expenses',
      where: 'report_id = ?',
      whereArgs: [reportId],
      orderBy: 'date ASC',
    );
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }
}
