import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/checkin.dart' as domain;
import '../../domain/models/habit.dart' as domain;
import '../../domain/repositories/habit_repository.dart';

import '../db/app_database.dart' as db;

class HabitRepositoryImpl implements HabitRepository {
  final db.AppDatabase _db;

  HabitRepositoryImpl(this._db);

  @override
  Future<List<domain.Habit>> listHabits() async {
    final rows = await _db.listHabits();
    return rows
        .map(
          (row) => domain.Habit(
            id: row.id,
            title: row.title,
            isActive: row.isActive,
            difficulty: row.difficulty,
            createdAt: row.createdAt,
          ),
        )
        .toList();
  }

  @override
  Future<void> upsertHabit(domain.Habit habit) async {
    final companion = db.HabitsCompanion(
      id: Value(habit.id),
      title: Value(habit.title),
      isActive: Value(habit.isActive),
      difficulty: Value(habit.difficulty),
      createdAt: Value(habit.createdAt),
    );
    await _db.upsertHabit(companion);
  }

  @override
  Future<void> addCheckin(domain.CheckIn checkin) async {
    final companion = db.CheckinsCompanion(
      id: Value(checkin.id.isEmpty ? const Uuid().v4() : checkin.id),
      habitId: Value(checkin.habitId),
      dateKey: Value(checkin.dateKey),
      status: Value(checkin.status),
      createdAt: Value(checkin.createdAt), date: null,
    );
    await _db.insertCheckin(companion);
  }

  @override
  Future<List<domain.CheckIn>> lastCheckins(
    String habitId,
    int days,
    String todayDateKey,
  ) async {
    final rows = await _db.listCheckinsByHabit(habitId, days, todayDateKey);
    return rows
        .map(
          (row) => domain.CheckIn(
            id: row.id,
            habitId: row.habitId,
            dateKey: row.dateKey,
            status: row.status,
            createdAt: row.createdAt, date: null,
          ),
        )
        .toList();
  }

  @override
  Future<domain.CheckIn?> getCheckinForDate(String habitId, String dateKey) async {
    final row = await _db.getCheckinForDate(habitId, dateKey);
    if (row == null) return null;

    return domain.CheckIn(
      id: row.id,
      habitId: row.habitId,
      dateKey: row.dateKey,
      status: row.status,
      createdAt: row.createdAt, date: null,
    );
  }

  @override
  Future<void> upsertCheckinForDate(String habitId, String dateKey, int status) async {
    await _db.upsertCheckinForDate(habitId, dateKey, status);
  }
}
