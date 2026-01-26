import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:habit_ai/domain/models/habit.dart';
import 'package:habit_ai/domain/models/checkin.dart';
import 'package:habit_ai/domain/repositories/habit_repository.dart';
import 'package:habit_ai/features/home/habit_details_page.dart';
import 'package:habit_ai/features/home/home_controller.dart';

class FakeHabitRepository implements HabitRepository {
  @override
  Future<void> upsertCheckinForDateKey(String habitId, String dateKey, int status) async {}

  @override
  Future<void> upsertCheckinForDate(String habitId, String dateKey, int status) async {}

  // HomeController.load() chama listHabits()
  @override
  Future<List<Habit>> listHabits() async => <Habit>[];

  // E normalmente puxa checkins em lote (mantemos vazio pra não depender de backend)
  @override
  Future<List<CheckIn>> lastCheckinsForHabits(
    List<String> habitIds,
    int days,
    String todayDateKey,
  ) async =>
      <CheckIn>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Importante: o Provider pede um HomeController.
/// Entao aqui a gente estende HomeController e sobrescreve so o que queremos controlar no teste.
class TestHomeController extends HomeController {
  TestHomeController(HabitRepository repo, String uid) : super(repo, uid) {
    state = AsyncValue.data(HomeState(
      habits: const [],
      todayStatusByHabitId: const {},
      rhythm14DaysByHabitId: const {},
      checkinsByHabitId: const {},
    ));
  }

  int setCalls = 0;
  int silentRefreshCalls = 0;

  @override
  Future<void> setCheckinForDate(String habitId, String dateKey, int nextStatus) async {
    setCalls++;
    final current = state.value!;

    final byHabit = Map<String, Map<String, int>>.from(current.checkinsByHabitId);
    final byDate = Map<String, int>.from(byHabit[habitId] ?? <String, int>{});
    byDate[dateKey] = nextStatus;
    byHabit[habitId] = byDate;

    state = AsyncValue.data(HomeState(
      habits: current.habits,
      todayStatusByHabitId: current.todayStatusByHabitId,
      rhythm14DaysByHabitId: current.rhythm14DaysByHabitId,
      checkinsByHabitId: byHabit,
    ));
  }

  @override
  void scheduleSilentRefresh({Duration delay = const Duration(milliseconds: 600)}) {
    silentRefreshCalls++;
  }
}

void main() {
  testWidgets('HabitDetailsPage renders without layout exceptions and accepts taps', (tester) async {
    final repo = FakeHabitRepository();
    final controller = TestHomeController(repo, 'uid');

    // Seu Habit exige campos obrigatorios (pelo erro: createdAt, difficulty, isActive).
    // Ajuste aqui para o construtor REAL do seu Habit.
    // Pelo log, sabemos pelo menos esses 3 existem.
    final habit = Habit(
      id: 'h1',
      title: 'Atividade fisica!',
      createdAt: DateTime.now(),
      difficulty: 1,
      isActive: true,
    );

    controller.state = AsyncValue.data(HomeState(
      habits: [habit],
      todayStatusByHabitId: const {'h1': 1},
      rhythm14DaysByHabitId: const {'h1': 0.5},
      checkinsByHabitId: const {'h1': {}},
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          home: HabitDetailsPage(habit: habit),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Dispara alguns taps
    final tiles = find.byType(InkWell);
    expect(tiles, findsWidgets);

    for (var i = 0; i < 6; i++) {
      await tester.tap(tiles.at(i));
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(tester.takeException(), isNull);
    expect(controller.silentRefreshCalls, greaterThanOrEqualTo(0));
  });
}
