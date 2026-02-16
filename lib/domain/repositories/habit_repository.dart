import '../models/checkin.dart';
import '../models/habit.dart';

abstract class HabitRepository {
  Future<void> deleteHabit(String habitId);
  Future<List<Habit>> listHabits();
  Future<void> createHabit(String title, int difficulty);

  Future<List<CheckIn>> lastCheckins(
    String habitId,
    int days,
    String todayDateKey,
  );

  /// Fetch checkins for multiple habits at once (performance).
  Future<List<CheckIn>> lastCheckinsForHabits(
    List<String> habitIds,
    int days,
    String todayDateKey,
  );
  Future<CheckIn?> getCheckinForDate(String habitId, String dateKey);
  Future<void> upsertCheckinForDate(String habitId, String dateKey, int status);
  Future<void> upsertCheckinForDateKey(
    String habitId,
    String dateKey,
    int status,
  );
}
