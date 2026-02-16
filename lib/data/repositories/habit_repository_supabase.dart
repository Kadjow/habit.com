import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/time/date_only.dart';
import '../../domain/models/checkin.dart';
import '../../domain/models/habit.dart';
import '../../domain/repositories/habit_repository.dart';

class HabitRepositorySupabase implements HabitRepository {
  final SupabaseClient _client;
  HabitRepositorySupabase(this._client);

  String _uidOrThrow() {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    return user.id;
  }

  @override
  Future<List<Habit>> listHabits() async {
    final uid = _uidOrThrow();
    final rows = await _client
        .from('habits')
        .select('id,title,is_active,difficulty,created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false);

    return (rows as List)
        .map(
          (r) => Habit(
            id: r['id'] as String,
            title: r['title'] as String,
            isActive: (r['is_active'] as bool?) ?? true,
            difficulty: (r['difficulty'] as int?) ?? 1,
            createdAt: DateTime.parse(r['created_at'] as String),
          ),
        )
        .toList();
  }

  @override
  Future<void> createHabit(String title, int difficulty) async {
    final uid = _uidOrThrow();
    await _client.from('habits').insert({
      'user_id': uid,
      'title': title,
      'difficulty': difficulty,
      'is_active': true,
    });
  }

  @override
  Future<List<CheckIn>> lastCheckins(
    String habitId,
    int days,
    String todayDateKey,
  ) async {
    final uid = _uidOrThrow();
    final cutoffDate = fromDateKey(
      todayDateKey,
    ).subtract(Duration(days: days - 1));
    final cutoffDateValue = cutoffDate.toIso8601String().substring(0, 10);

    final rows = await _client
        .from('checkins')
        .select('id,habit_id,date,date_key,status,created_at')
        .eq('user_id', uid)
        .eq('habit_id', habitId)
        .gte('date', cutoffDateValue)
        .order('date', ascending: false)
        .limit(days + 5);

    return (rows as List)
        .map(
          (r) => CheckIn(
            id: r['id'] as String,
            habitId: r['habit_id'] as String,
            date: DateTime.parse(r['date'] as String),
            dateKey: r['date_key'] as String,
            status: r['status'] as int,
            createdAt: DateTime.parse(r['created_at'] as String),
          ),
        )
        .toList();
  }

  @override
  Future<List<CheckIn>> lastCheckinsForHabits(
    List<String> habitIds,
    int days,
    String todayDateKey,
  ) async {
    if (habitIds.isEmpty) return [];
    final uid = _uidOrThrow();
    final cutoffDate = fromDateKey(
      todayDateKey,
    ).subtract(Duration(days: days - 1));
    final cutoffKey = toDateKey(cutoffDate);

    final rows = await _client
        .from('checkins')
        .select('id,habit_id,date,date_key,status,created_at')
        .eq('user_id', uid)
        .inFilter('habit_id', habitIds)
        .gte('date_key', cutoffKey)
        .order('date_key', ascending: false)
        .limit(habitIds.length * (days + 5));

    return (rows as List)
        .map(
          (r) => CheckIn(
            id: r['id'] as String,
            habitId: r['habit_id'] as String,
            date: DateTime.parse(r['date'] as String),
            dateKey: r['date_key'] as String,
            status: r['status'] as int,
            createdAt: DateTime.parse(r['created_at'] as String),
          ),
        )
        .toList();
  }

  @override
  Future<CheckIn?> getCheckinForDate(String habitId, String dateKey) async {
    final uid = _uidOrThrow();
    final row = await _client
        .from('checkins')
        .select()
        .eq('user_id', uid)
        .eq('habit_id', habitId)
        .eq('date_key', dateKey)
        .maybeSingle();
    if (row == null) return null;

    return CheckIn(
      id: row['id'] as String,
      habitId: row['habit_id'] as String,
      date: DateTime.parse(row['date'] as String),
      dateKey: row['date_key'] as String,
      status: row['status'] as int,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  @override
  Future<void> upsertCheckinForDate(
    String habitId,
    String dateKey,
    int status,
  ) async {
    final uid = _uidOrThrow();

    if (status == 0) {
      await _client
          .from('checkins')
          .delete()
          .eq('user_id', uid)
          .eq('habit_id', habitId)
          .eq('date_key', dateKey);
      return;
    }

    await _client.from('checkins').upsert({
      'user_id': uid,
      'habit_id': habitId,
      'date_key': dateKey,
      'date': dateKey,
      'status': status,
    }, onConflict: 'user_id,habit_id,date_key');
  }

  @override
  Future<void> upsertCheckinForDateKey(
    String habitId,
    String dateKey,
    int status,
  ) async {
    final uid = _uidOrThrow();

    await _client.from('checkins').upsert({
      'user_id': uid,
      'habit_id': habitId,
      'date_key': dateKey,
      'date': fromDateKey(dateKey).toIso8601String(),
      'status': status,
    }, onConflict: 'user_id,habit_id,date_key');
  }

  @override
  Future<void> deleteHabit(String habitId) async {
    await _client.from('habits').delete().eq('id', habitId);
  }
}
