class WeightRecord {
  const WeightRecord({
    this.id,
    required this.date,
    required this.weightKg,
  });

  final int? id;
  final DateTime date;
  final double weightKg;

  DateTime get day => DateTime(date.year, date.month, date.day);

  String get dateKey {
    final month = date.month.toString().padLeft(2, '0');
    final dayOfMonth = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$dayOfMonth';
  }

  Map<String, Object?> toDatabaseMap() => {
        'date': dateKey,
        'weight_kg': weightKg,
      };

  factory WeightRecord.fromDatabaseMap(Map<String, Object?> map) {
    final parts = (map['date']! as String).split('-');
    return WeightRecord(
      id: map['id']! as int,
      date: DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      ),
      weightKg: (map['weight_kg']! as num).toDouble(),
    );
  }
}
