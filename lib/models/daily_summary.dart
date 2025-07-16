import 'package:caltrac/models/caloric_entry.dart';
import 'package:caltrac/models/whoop_data.dart';

class DailySummary {
  final DateTime date;
  final List<CaloricEntry> CaloricEntrys;
  final WhoopData whoopData;

  DailySummary({
    required this.date,
    required this.CaloricEntrys,
    required this.whoopData,
  });

  int get totalCaloriesIN {
    return CaloricEntrys.fold(0, (sum, entry) => sum + entry.calories);
  }
  int get totalProtein {
    return CaloricEntrys.fold(0, (sum, entry) => sum + entry.protien);
  }
  double get totalCaloriesOUT {
    return whoopData.adjustedCalsBurned;
  }
  double get netCalories {
    return totalCaloriesIN - totalCaloriesOUT;
  }
}