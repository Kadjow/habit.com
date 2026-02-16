import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:habit_ai/features/home/home_controller.dart';
import 'package:habit_ai/features/home/home_page.dart';

import 'package:habit_ai/domain/repositories/habit_repository.dart';
import 'package:habit_ai/domain/models/habit.dart';
import 'package:habit_ai/domain/models/checkin.dart';

// Providers do app que hoje encostam no Supabase.instance
import 'package:habit_ai/app/providers.dart';

/// Repo fake (sem rede) que implementa a interface real do app.
class FakeHabitRepository implements HabitRepository {
  FakeHabitRepository({
    required this.habits,
    Map<String, Map<String, int>>? checkinsByHabitId,
  }) : _checkinsByHabitId = checkinsByHabitId ?? <String, Map<String, int>>{};

  final List<Habit> habits;

  /// habitId -> (dateKey -> status)
  final Map<String, Map<String, int>> _checkinsByHabitId;

  @override
  Future<List<Habit>> listHabits() async => habits;

  @override
  Future<void> createHabit(String title, int difficulty) async {
    // no-op em teste
  }

  @override
  Future<void> deleteHabit(String habitId) async {
    habits.removeWhere((h) => h.id == habitId);
    _checkinsByHabitId.remove(habitId);
  }

  @override
  Future<CheckIn?> getCheckinForDate(String habitId, String dateKey) async {
    final map = _checkinsByHabitId[habitId];
    final v = map == null ? null : map[dateKey];
    if (v == null) return null;

    final now = DateTime.now();

    // Construtor do CheckIn no seu domain pede mais campos.
    // Ajuste aqui se o seu model tiver nomes diferentes.
    return CheckIn(
      id: 'c_${habitId}_$dateKey',
      habitId: habitId,
      dateKey: dateKey,
      status: v,
      date: now,
      createdAt: now,
    );
  }

  @override
  Future<List<CheckIn>> lastCheckins(
    String habitId,
    int days,
    String todayDateKey,
  ) async {
    return <CheckIn>[];
  }

  @override
  Future<List<CheckIn>> lastCheckinsForHabits(
    List<String> habitIds,
    int days,
    String todayDateKey,
  ) async {
    return <CheckIn>[];
  }

  @override
  Future<void> upsertCheckinForDate(
    String habitId,
    String dateKey,
    int status,
  ) async {
    final map = _checkinsByHabitId.putIfAbsent(habitId, () => <String, int>{});
    map[dateKey] = status;
  }

  @override
  Future<void> upsertCheckinForDateKey(
    String habitId,
    String dateKey,
    int status,
  ) async {
    final map = _checkinsByHabitId.putIfAbsent(habitId, () => <String, int>{});
    map[dateKey] = status;
  }
}

/// Controller fake: ja nasce com state pronto.
/// Importante: assim o HomePage nao fica em loading infinito.
class TestHomeController extends HomeController {
  TestHomeController(super.repo, super.uid, HomeState initial) {
    state = AsyncValue.data(initial);
  }

  @override
  Future<void> load() async {
    // no-op para smoke
  }
}

/// Monta o app para smoke tests (Home -> Details) sem rede e sem Supabase real.
Widget buildSmokeTestApp({
  required HomeState homeState,
  Widget home = const HomePage(),
}) {
  final HabitRepository repo = FakeHabitRepository(
    habits: homeState.habits,
    checkinsByHabitId: homeState.checkinsByHabitId,
  );

  const String uid = 'test-user';

  return ProviderScope(
    overrides: [
      // Evita providers que encostam no Supabase auth.
      // Mantem a UI funcional em teste.
      authUserIdProvider.overrideWith((ref) => uid),
      authUserEmailProvider.overrideWith((ref) => 'test@local'),

      // Override do controller para nao disparar load() / debounce timers.
      homeControllerProvider.overrideWith((ref) {
        return TestHomeController(repo, uid, homeState);
      }),
    ],
    child: MaterialApp(home: home),
  );
}
