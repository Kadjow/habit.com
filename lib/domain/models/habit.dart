class Habit {
  final String id;
  final String title;
  final bool isActive;
  final int difficulty;
  final DateTime createdAt;

  const Habit({
    required this.id,
    required this.title,
    required this.isActive,
    required this.difficulty,
    required this.createdAt,
  });
}
