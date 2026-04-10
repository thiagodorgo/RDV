import 'dart:convert';

enum ExpenseCategory { combustivel, hotel, outros }

extension ExpenseCategoryLabel on ExpenseCategory {
  String get label {
    switch (this) {
      case ExpenseCategory.combustivel:
        return 'Combustível';
      case ExpenseCategory.hotel:
        return 'Hotel';
      case ExpenseCategory.outros:
        return 'Outros';
    }
  }
}

class Expense {
  final int? id;
  final int reportId;
  final ExpenseCategory category;
  final DateTime date;
  final String establishment;
  final String city;
  final String uf;
  final double amount;
  final String? observations;
  final String? km;

  Expense({
    this.id,
    required this.reportId,
    required this.category,
    required this.date,
    required this.establishment,
    required this.city,
    required this.uf,
    required this.amount,
    this.observations,
    this.km,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'report_id': reportId,
      'category': category.index,
      'date': date.toIso8601String(),
      'establishment': establishment,
      'city': city,
      'uf': uf,
      'amount': amount,
      'observations': observations,
      'km': km,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      reportId: map['report_id'],
      category: ExpenseCategory.values[map['category']],
      date: DateTime.parse(map['date']),
      establishment: map['establishment'],
      city: map['city'],
      uf: map['uf'],
      amount: map['amount'],
      observations: map['observations'],
      km: map['km'],
    );
  }

  Expense copyWith({
    int? id,
    int? reportId,
    ExpenseCategory? category,
    DateTime? date,
    String? establishment,
    String? city,
    String? uf,
    double? amount,
    String? observations,
    String? km,
  }) {
    return Expense(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      category: category ?? this.category,
      date: date ?? this.date,
      establishment: establishment ?? this.establishment,
      city: city ?? this.city,
      uf: uf ?? this.uf,
      amount: amount ?? this.amount,
      observations: observations ?? this.observations,
      km: km ?? this.km,
    );
  }
}
