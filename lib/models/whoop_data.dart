class WhoopData {
  final int burnedCals;
  final DateTime date;
  final bool liftWeights;

  WhoopData({
    required this.burnedCals,
    required this.date,
    required this.liftWeights,
  });

  double get adjustedCalsBurned {
    return burnedCals + (liftWeights ? 200 : 0);
  }
}