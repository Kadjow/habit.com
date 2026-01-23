class CheckIn {
  final String id;
  final String habitId;
  final String dateKey;
  final int status;
  final DateTime createdAt;

  const CheckIn({
    required this.id,
    required this.habitId,
    required this.dateKey,
    required this.status,
    required this.createdAt,
  });
}
