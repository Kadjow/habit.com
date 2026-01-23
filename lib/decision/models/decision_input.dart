import '../../domain/models/checkin.dart';
import '../../domain/models/habit.dart';

class DecisionInput {
  final Habit habit;
  final List<CheckIn> last14DaysCheckins;
  final int lastFailureCount7Days;
  final int ignoredPromptsCount3Days;

  const DecisionInput({
    required this.habit,
    required this.last14DaysCheckins,
    required this.lastFailureCount7Days,
    required this.ignoredPromptsCount3Days,
  });
}
