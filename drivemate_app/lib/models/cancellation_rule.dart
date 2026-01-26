class CancellationRule {
  CancellationRule({
    required this.hoursBefore,
    required this.chargePercent,
  });

  final int hoursBefore; // e.g., 24, 48, 72
  final int chargePercent; // e.g., 100, 50, 0

  Map<String, dynamic> toMap() {
    return {
      'hoursBefore': hoursBefore,
      'chargePercent': chargePercent,
    };
  }

  static CancellationRule fromMap(Map<String, dynamic> data) {
    return CancellationRule(
      hoursBefore: (data['hoursBefore'] as int?) ?? 24,
      chargePercent: (data['chargePercent'] as int?) ?? 50,
    );
  }

  CancellationRule copyWith({
    int? hoursBefore,
    int? chargePercent,
  }) {
    return CancellationRule(
      hoursBefore: hoursBefore ?? this.hoursBefore,
      chargePercent: chargePercent ?? this.chargePercent,
    );
  }
}
