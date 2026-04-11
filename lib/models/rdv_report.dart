enum ExpenseOrigin { engenharia, supervisaoObras, comercial, administrativo }

extension ExpenseOriginLabel on ExpenseOrigin {
  String get label {
    switch (this) {
      case ExpenseOrigin.engenharia:
        return 'Engenharia';
      case ExpenseOrigin.supervisaoObras:
        return 'Supervisão Obras';
      case ExpenseOrigin.comercial:
        return 'Comercial';
      case ExpenseOrigin.administrativo:
        return 'Administrativo';
    }
  }
}

class RdvReport {
  final int? id;
  final String employee;
  final String role;
  final ExpenseOrigin origin;
  final String obra;
  final String orderNumber;
  final int month;
  final int year;
  final String city;
  final String period;
  final double advance;
  final DateTime createdAt;

  RdvReport({
    this.id,
    required this.employee,
    required this.role,
    required this.origin,
    required this.obra,
    required this.orderNumber,
    required this.month,
    required this.year,
    required this.city,
    required this.period,
    this.advance = 0.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee': employee,
      'role': role,
      'origin': origin.index,
      'obra': obra,
      'order_number': orderNumber,
      'month': month,
      'year': year,
      'city': city,
      'period': period,
      'advance': advance,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory RdvReport.fromMap(Map<String, dynamic> map) {
    return RdvReport(
      id: map['id'],
      employee: (map['employee'] as String?) ?? '',
      role: (map['role'] as String?) ?? '',
      origin: ExpenseOrigin.values[(map['origin'] as int?) ?? 0],
      obra: (map['obra'] as String?) ?? '',
      orderNumber: (map['order_number'] as String?) ?? '',
      month: (map['month'] as int?) ?? DateTime.now().month,
      year: (map['year'] as int?) ?? DateTime.now().year,
      city: (map['city'] as String?) ?? '',
      period: (map['period'] as String?) ?? '',
      advance: ((map['advance'] as num?) ?? 0).toDouble(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  String get monthYearLabel {
    return '${month.toString().padLeft(2, '0')}/$year';
  }

  RdvReport copyWith({
    int? id,
    String? employee,
    String? role,
    ExpenseOrigin? origin,
    String? obra,
    String? orderNumber,
    int? month,
    int? year,
    String? city,
    String? period,
    double? advance,
    DateTime? createdAt,
  }) {
    return RdvReport(
      id: id ?? this.id,
      employee: employee ?? this.employee,
      role: role ?? this.role,
      origin: origin ?? this.origin,
      obra: obra ?? this.obra,
      orderNumber: orderNumber ?? this.orderNumber,
      month: month ?? this.month,
      year: year ?? this.year,
      city: city ?? this.city,
      period: period ?? this.period,
      advance: advance ?? this.advance,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
