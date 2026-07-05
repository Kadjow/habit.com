import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/time/date_only.dart';
import '../../domain/models/checkin.dart';
import '../../domain/models/habit.dart';
import '../../domain/repositories/habit_repository.dart';

/// Repositório local, persistido em SharedPreferences. Sem rede/backend.
///
/// Estado guardado em duas chaves JSON:
/// - [_habitsKey]: lista de hábitos.
/// - [_checkinsKey]: lista de checkins {habitId, dateKey, status}.
/// Só status 1/2 são persistidos; status 0 remove o registro.
class LocalHabitRepository implements HabitRepository {
  LocalHabitRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _uuid = Uuid();

  static const String _habitsKey = 'local_habits';
  static const String _checkinsKey = 'local_checkins';

  // ---- habits ----

  List<Map<String, dynamic>> _readHabits() {
    final raw = _prefs.getString(_habitsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> _writeHabits(List<Map<String, dynamic>> habits) async {
    await _prefs.setString(_habitsKey, jsonEncode(habits));
  }

  Habit _toHabit(Map<String, dynamic> r) => Habit(
        id: r['id'] as String,
        title: r['title'] as String,
        isActive: (r['isActive'] as bool?) ?? true,
        difficulty: (r['difficulty'] as int?) ?? 1,
        createdAt: DateTime.parse(r['createdAt'] as String),
      );

  @override
  Future<List<Habit>> listHabits() async {
    final rows = _readHabits()..sort((a, b) {
        return (b['createdAt'] as String).compareTo(a['createdAt'] as String);
      });
    return rows.map(_toHabit).toList();
  }

  @override
  Future<void> createHabit(String title, int difficulty) async {
    final habits = _readHabits();
    habits.add({
      'id': _uuid.v4(),
      'title': title,
      'difficulty': difficulty,
      'isActive': true,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _writeHabits(habits);
  }

  @override
  Future<void> deleteHabit(String habitId) async {
    final habits = _readHabits()..removeWhere((h) => h['id'] == habitId);
    await _writeHabits(habits);
    final checkins = _readCheckins()..removeWhere((c) => c['habitId'] == habitId);
    await _writeCheckins(checkins);
  }

  // ---- checkins ----

  List<Map<String, dynamic>> _readCheckins() {
    final raw = _prefs.getString(_checkinsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> _writeCheckins(List<Map<String, dynamic>> checkins) async {
    await _prefs.setString(_checkinsKey, jsonEncode(checkins));
  }

  CheckIn _toCheckin(Map<String, dynamic> r) {
    final dateKey = r['dateKey'] as String;
    return CheckIn(
      id: '${r['habitId']}_$dateKey',
      habitId: r['habitId'] as String,
      date: fromDateKey(dateKey),
      dateKey: dateKey,
      status: r['status'] as int,
      createdAt: fromDateKey(dateKey),
    );
  }

  bool _isDone(int status) => status == 1 || status == 2;

  @override
  Future<List<CheckIn>> lastCheckins(
    String habitId,
    int days,
    String todayDateKey,
  ) async {
    final cutoff = toDateKey(
      fromDateKey(todayDateKey).subtract(Duration(days: days - 1)),
    );
    return _readCheckins()
        .where((c) =>
            c['habitId'] == habitId &&
            (c['dateKey'] as String).compareTo(cutoff) >= 0)
        .map(_toCheckin)
        .toList();
  }

  @override
  Future<List<CheckIn>> lastCheckinsForHabits(
    List<String> habitIds,
    int days,
    String todayDateKey,
  ) async {
    if (habitIds.isEmpty) return [];
    final ids = habitIds.toSet();
    final cutoff = toDateKey(
      fromDateKey(todayDateKey).subtract(Duration(days: days - 1)),
    );
    return _readCheckins()
        .where((c) =>
            ids.contains(c['habitId']) &&
            (c['dateKey'] as String).compareTo(cutoff) >= 0)
        .map(_toCheckin)
        .toList();
  }

  @override
  Future<CheckIn?> getCheckinForDate(String habitId, String dateKey) async {
    for (final c in _readCheckins()) {
      if (c['habitId'] == habitId && c['dateKey'] == dateKey) {
        return _toCheckin(c);
      }
    }
    return null;
  }

  @override
  Future<Set<String>> listCheckedHabitIdsForDateKey({
    required String dateKey,
  }) async {
    final out = <String>{};
    for (final c in _readCheckins()) {
      if (c['dateKey'] == dateKey && _isDone(c['status'] as int)) {
        out.add(c['habitId'] as String);
      }
    }
    return out;
  }

  @override
  Future<Set<String>> listCheckedPairsForDateKeys({
    required List<String> dateKeys,
  }) async {
    if (dateKeys.isEmpty) return <String>{};
    final keys = dateKeys.toSet();
    final out = <String>{};
    for (final c in _readCheckins()) {
      final dateKey = c['dateKey'] as String;
      if (keys.contains(dateKey) && _isDone(c['status'] as int)) {
        out.add('${c['habitId']}|$dateKey');
      }
    }
    return out;
  }

  @override
  Future<void> setCheckinForDateKey({
    required String habitId,
    required String dateKey,
  }) =>
      upsertCheckinForDateKey(habitId, dateKey, 1);

  @override
  Future<void> deleteCheckinForDateKey({
    required String habitId,
    required String dateKey,
  }) =>
      upsertCheckinForDateKey(habitId, dateKey, 0);

  @override
  Future<void> upsertCheckinForDate(
    String habitId,
    String dateKey,
    int status,
  ) =>
      upsertCheckinForDateKey(habitId, dateKey, status);

  @override
  Future<void> upsertCheckinForDateKey(
    String habitId,
    String dateKey,
    int status,
  ) async {
    final checkins = _readCheckins()
      ..removeWhere((c) => c['habitId'] == habitId && c['dateKey'] == dateKey);
    if (status != 0) {
      checkins.add({'habitId': habitId, 'dateKey': dateKey, 'status': status});
    }
    await _writeCheckins(checkins);
  }
}
