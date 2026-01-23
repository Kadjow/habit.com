import '../models/checkin.dart' as domain;
import '../models/habit.dart' as domain;

abstract class HabitRepository {
  Future<List<domain.Habit>> listHabits();
  Future<void> upsertHabit(domain.Habit habit);

  Future<void> addCheckin(domain.CheckIn checkin);
  Future<List<domain.CheckIn>> lastCheckins(
    String habitId,
    int days,
    String todayDateKey,
  );
  Future<domain.CheckIn?> getCheckinForDate(String habitId, String dateKey);
  Future<void> upsertCheckinForDate(String habitId, String dateKey, int status);
}
