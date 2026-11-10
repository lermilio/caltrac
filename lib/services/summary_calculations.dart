// Count all included calendar days, including days without logged entries.
int averagePerDay({required num total, required int dayCount}) {
  if (dayCount == 0) return 0;
  return (total / dayCount).round();
}
