import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/time/date_only.dart';
import 'connection.dart';

part 'app_database.g.dart';

@DriftDatabase(include: {'tables/habits.drift'})
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor executor) : super(executor);

  factory AppDatabase.open() => AppDatabase(openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 3) {
            // TODO(drift): Destructive MVP migration; replace with data-preserving copy.
            await m.deleteTable('checkins');
            await m.deleteTable('adjustments');
            await m.createTable(checkins);
            await m.createTable(adjustments);
            await m.createIndex(idxCheckinsHabitId);
            await m.createIndex(idxCheckinsHabitDate);
            await m.createIndex(idxAdjustmentsHabitId);
          }
        },
      );

  Future<void> upsertHabit(HabitsCompanion habit) async {
    await into(habits).insertOnConflictUpdate(habit);
  }

  Future<List<Habit>> listHabits() {
    return select(habits).get();
  }

  Future<void> insertCheckin(CheckinsCompanion checkin) async {
    await into(checkins).insert(checkin);
  }

  Future<Checkin?> getCheckinForDate(String habitId, String dateKey) {
    return (select(checkins)
          ..where((c) => c.habitId.equals(habitId))
          ..where((c) => c.dateKey.equals(dateKey)))
        .getSingleOrNull();
  }

  Future<void> deleteCheckinForDate(String habitId, String dateKey) async {
    await (delete(checkins)
          ..where((c) => c.habitId.equals(habitId))
          ..where((c) => c.dateKey.equals(dateKey)))
        .go();
  }

  Future<List<Checkin>> listCheckinsByHabit(
    String habitId,
    int lastNDays,
    String todayDateKey,
  ) {
    final cutoff = fromDateKey(todayDateKey).subtract(Duration(days: lastNDays - 1));
    final cutoffKey = toDateKey(cutoff);
    return (select(checkins)
          ..where((c) => c.habitId.equals(habitId))
          ..where((c) => c.dateKey.isBiggerOrEqualValue(cutoffKey))
          ..orderBy([(c) => OrderingTerm(expression: c.dateKey, mode: OrderingMode.desc)]))
        .get();
  }

  Future<void> upsertCheckinForDate(String habitId, String dateKey, int status) async {
    final existing = await getCheckinForDate(habitId, dateKey);
    if (status == 0) {
      if (existing != null) {
        await deleteCheckinForDate(habitId, dateKey);
      }
      return;
    }
    if (existing != null) {
      await (update(checkins)..where((c) => c.id.equals(existing.id))).write(
        CheckinsCompanion(status: Value(status), date: null),
      );
      return;
    }
    final now = DateTime.now();
    await insertCheckin(
      CheckinsCompanion(
        id: Value(const Uuid().v4()),
        habitId: Value(habitId),
        dateKey: Value(dateKey),
        status: Value(status),
        createdAt: Value(now), date: null,
      ),
    );
  }
}
