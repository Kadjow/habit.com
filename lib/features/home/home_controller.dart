import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/time/date_only.dart';
import '../../data/repositories/providers.dart';
import '../../domain/models/checkin.dart' as domain;
import '../../domain/models/habit.dart' as domain;
import '../../domain/repositories/habit_repository.dart';

final homeControllerProvider = StateNotifierProvider<HomeController, AsyncValue<HomeState>>(
  (ref) => HomeController(ref.watch(habitRepositoryProvider)),
);

class HomeState {
  final List<domain.Habit> habits;
  final Map<String, int> todayStatusByHabitId;
  final Map<String, double> rhythm14DaysByHabitId;

  const HomeState({
    required this.habits,
    required this.todayStatusByHabitId,
    required this.rhythm14DaysByHabitId,
  });
}

class HomeController extends StateNotifier<AsyncValue<HomeState>> {
  final HabitRepository _repository;

  HomeController(this._repository) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final habits = await _repository.listHabits();
      final today = todayLocal();
      final todayKey = toDateKey(today);
      final Map<String, int> todayStatusByHabitId = {};
      final Map<String, double> rhythm14DaysByHabitId = {};

      for (final habit in habits) {
        final checkins = await _repository.lastCheckins(habit.id, 14, todayKey);
        final checkinsByDate = <String, domain.CheckIn>{
          for (final checkin in checkins) checkin.dateKey: checkin,
        };

        var doneCount = 0;
        for (var i = 0; i < 14; i += 1) {
          final dayKey = toDateKey(today.subtract(Duration(days: i)));
          final status = checkinsByDate[dayKey]?.status ?? 0;
          if (status == 1 || status == 2) {
            doneCount += 1;
          }
        }
        rhythm14DaysByHabitId[habit.id] = doneCount / 14.0;

        final todayCheckin = await _repository.getCheckinForDate(habit.id, todayKey);
        todayStatusByHabitId[habit.id] = todayCheckin?.status ?? 0;
      }

      state = AsyncValue.data(HomeState(
        habits: habits,
        todayStatusByHabitId: todayStatusByHabitId,
        rhythm14DaysByHabitId: rhythm14DaysByHabitId,
      ));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> toggleCheckin(String habitId, int status) async {
    final currentState = state.value;
    if (currentState == null) {
      return;
    }
    final todayKey = toDateKey(todayLocal());
    final current = currentState.todayStatusByHabitId[habitId] ?? 0;
    final nextStatus = current == status ? 0 : status;
    await _repository.upsertCheckinForDate(habitId, todayKey, nextStatus);

    final today = todayLocal();
    final checkins = await _repository.lastCheckins(habitId, 14, todayKey);
    final checkinsByDate = <String, domain.CheckIn>{
      for (final checkin in checkins) checkin.dateKey: checkin,
    };
    var doneCount = 0;
    for (var i = 0; i < 14; i += 1) {
      final dayKey = toDateKey(today.subtract(Duration(days: i)));
      final status = checkinsByDate[dayKey]?.status ?? 0;
      if (status == 1 || status == 2) {
        doneCount += 1;
      }
    }
    final updatedTodayStatusByHabitId = Map<String, int>.from(currentState.todayStatusByHabitId)
      ..[habitId] = nextStatus;
    final updatedRhythm14DaysByHabitId = Map<String, double>.from(currentState.rhythm14DaysByHabitId)
      ..[habitId] = doneCount / 14.0;

    state = AsyncValue.data(HomeState(
      habits: currentState.habits,
      todayStatusByHabitId: updatedTodayStatusByHabitId,
      rhythm14DaysByHabitId: updatedRhythm14DaysByHabitId,
    ));
  }

  Future<void> createHabit(String title, int difficulty) async {
    final now = DateTime.now();
    final habit = domain.Habit(
      id: const Uuid().v4(),
      title: title,
      isActive: true,
      difficulty: difficulty,
      createdAt: now,
    );
    await _repository.upsertHabit(habit);
    await load();
  }
}
