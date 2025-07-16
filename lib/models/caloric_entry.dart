class CaloricEntry {
  final String entry;
  final DateTime date;
  final int calories;
  final int protien;


  CaloricEntry({
    required this.entry,
    required this.date,
    required this.calories,
    required this.protien,
  });

  Map<String, dynamic> toJson() {
    return {
      'entry': entry,
      'date': date.toIso8601String(),
      'calories': calories,
      'protien': protien,
    };
  }

  factory CaloricEntry.fromJson(Map<String, dynamic> json) {
    return CaloricEntry(
      entry: json['entry'] as String,
      date: DateTime.parse(json['date'] as String),
      calories: json['calories'] as int,
      protien: json['protien'] as int,
    );
  }
}