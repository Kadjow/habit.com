class CheckIn {
  final String id;
  final String habitId;
  final DateTime date;
  final String dateKey;
  final int status; // 0 none, 1 done, 2 minimum
  final DateTime createdAt;

  const CheckIn({
    required this.id,
    required this.habitId,
    required this.date,
    required this.dateKey,
    required this.status,
    required this.createdAt,
  });
}
