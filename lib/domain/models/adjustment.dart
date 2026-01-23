class Adjustment {
  final String id;
  final String habitId;
  final String dateKey;
  final String kind;
  final String payload;
  final DateTime createdAt;

  const Adjustment({
    required this.id,
    required this.habitId,
    required this.dateKey,
    required this.kind,
    required this.payload,
    required this.createdAt,
  });
}
