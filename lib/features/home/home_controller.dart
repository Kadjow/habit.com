import 'package:flutter/foundation.dart'; // compute, kIsWeb
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/time/date_only.dart';
import '../../domain/models/habit.dart';
import '../../domain/repositories/habit_repository.dart';

// compute() so aceita payloads "sendable" (primitivos / List / Map).
// Entao vamos mandar apenas listas/maps com os dados necessarios.
Map<String, dynamic> _buildHomeMetrics(Map<String, dynamic> input) {
  final todayKey = input['todayKey'] as String;
  final todayMillis = input['todayMillis'] as int;
  final today = DateTime.fromMillisecondsSinceEpoch(todayMillis);
  final habitIds = (input['habitIds'] as List).cast<String>();
  final checkins = (input['checkins'] as List).cast<Map>();

  // byHabit[habitId][dateKey] = status
  final byHabit = <String, Map<String, int>>{};
  for (final raw in checkins) {
    final habitId = raw['habitId'] as String;
    final dateKey = raw['dateKey'] as String;
    final status = raw['status'] as int;
    (byHabit[habitId] ??= <String, int>{})[dateKey] = status;
  }

  final todayStatusByHabitId = <String, int>{};
  final rhythm14DaysByHabitId = <String, double>{};

  for (final hid in habitIds) {
    final map = byHabit[hid] ?? const <String, int>{};
    todayStatusByHabitId[hid] = map[todayKey] ?? 0;

    var doneCount = 0;
    for (var i = 0; i < 14; i++) {
      final dayKey = toDateKey(today.subtract(Duration(days: i)));
      final s = map[dayKey] ?? 0;
      if (s == 1 || s == 2) doneCount++;
    }
    rhythm14DaysByHabitId[hid] = doneCount / 14.0;
  }

  return {
    'todayStatusByHabitId': todayStatusByHabitId,
    'rhythm14DaysByHabitId': rhythm14DaysByHabitId,
  };
}

class HomeState {
  final List<Habit> habits;
  final Map<String, int> todayStatusByHabitId;
  final Map<String, double> rhythm14DaysByHabitId;

  const HomeState({
    required this.habits,
    required this.todayStatusByHabitId,
    required this.rhythm14DaysByHabitId,
  });
}

final homeControllerProvider =
    StateNotifierProvider.autoDispose<HomeController, AsyncValue<HomeState>>(
  (ref) {
    // Recria quando user muda (login/logout) e reseta estado
    final uid = ref.watch(userIdProvider);
    return HomeController(ref.watch(habitRepositoryProvider), uid);
  },
);

class HomeController extends StateNotifier<AsyncValue<HomeState>> {
  final HabitRepository _repository;
  final String? _uid;
  bool _loading = false;

  HomeController(this._repository, this._uid)
      : super(const AsyncValue.loading()) {
    if (_uid == null) {
      state = const AsyncValue.data(HomeState(
        habits: [],
        todayStatusByHabitId: {},
        rhythm14DaysByHabitId: {},
      ));
      return;
    }
    load();
  }

  bool get isRefreshing => _loading;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    // UX: evita "piscar" a tela toda vez que carrega.
    // Se ja ha dados, mantemos e carregamos em background.
    final previous = state.value;
    if (previous == null) {
      state = const AsyncValue.loading();
    }
    try {
      if (_uid == null) {
        state = const AsyncValue.data(HomeState(
          habits: [],
          todayStatusByHabitId: {},
          rhythm14DaysByHabitId: {},
        ));
        return;
      }

      final habits = await _repository.listHabits();
      if (!mounted) return;
      if (habits.isEmpty) {
        state = const AsyncValue.data(HomeState(
          habits: [],
          todayStatusByHabitId: {},
          rhythm14DaysByHabitId: {},
        ));
        return;
      }

      final today = todayLocal();
      final todayKey = toDateKey(today);

      final habitIds = habits.map((h) => h.id).toList();
      final allCheckins =
          await _repository.lastCheckinsForHabits(habitIds, 14, todayKey);
      if (!mounted) return;

      // Payload serializavel pro isolate
      final payload = <String, dynamic>{
        'habitIds': habitIds,
        'todayKey': todayKey,
        'todayMillis': today.millisecondsSinceEpoch,
        'checkins': allCheckins
            .map((c) => {
                  'habitId': c.habitId,
                  'dateKey': c.dateKey,
                  'status': c.status,
                })
            .toList(),
      };

      // Web pode nao suportar isolate como esperado; fallback sync.
      final out = kIsWeb
          ? _buildHomeMetrics(payload)
          : await compute(_buildHomeMetrics, payload);
      if (!mounted) return;

      final todayStatusByHabitId =
          (out['todayStatusByHabitId'] as Map).cast<String, int>();
      final rhythm14DaysByHabitId =
          (out['rhythm14DaysByHabitId'] as Map).cast<String, double>();

      state = AsyncValue.data(HomeState(
        habits: habits,
        todayStatusByHabitId: todayStatusByHabitId,
        rhythm14DaysByHabitId: rhythm14DaysByHabitId,
      ));
    } catch (e, st) {
      if (!mounted) return;
      // Se ja havia dados, preserva e evita "tela de erro total".
      if (previous != null) {
        state = AsyncValue.data(previous);
      } else {
        state = AsyncValue.error(e, st);
      }
      rethrow;
    } finally {
      _loading = false;
    }
  }

  Future<void> toggleCheckin(String habitId, int status) async {
    final currentState = state.value;
    if (currentState == null || _uid == null) return;

    final todayKey = toDateKey(todayLocal());
    final current = currentState.todayStatusByHabitId[habitId] ?? 0;
    final nextStatus = current == status ? 0 : status;

    // UX: optimistic update (responde na hora)
    final optimisticStatus =
        Map<String, int>.from(currentState.todayStatusByHabitId)
          ..[habitId] = nextStatus;

    // Recalcula ritmo localmente para NAO precisar recarregar tudo.
    // (mantem simples: assume 14 dias e ajusta so o "hoje")
    final optimisticRhythm =
        Map<String, double>.from(currentState.rhythm14DaysByHabitId);

    // Aproximacao: ajusta o ritmo com base no estado do "hoje" apenas.
    // Como ainda temos os checkins no backend, faremos um refresh silencioso depois.
    final prevRhythm = optimisticRhythm[habitId] ?? 0.0;
    // Nao tentamos calcular com precisao perfeita aqui; so melhora UX.
    // O refresh silencioso logo apos garante consistencia.
    optimisticRhythm[habitId] = prevRhythm;

    state = AsyncValue.data(HomeState(
      habits: currentState.habits,
      todayStatusByHabitId: optimisticStatus,
      rhythm14DaysByHabitId: optimisticRhythm,
    ));

    try {
      await _repository.upsertCheckinForDate(habitId, todayKey, nextStatus);
      if (!mounted) return;
      // Refresh silencioso para ficar 100% consistente (sem piscar)
      await load();
    } catch (_) {
      if (!mounted) return;
      // Reverte se falhar
      state = AsyncValue.data(currentState);
      rethrow;
    }
  }

  Future<void> createHabit(String title, int difficulty) async {
    if (_uid == null) return;
    await _repository.createHabit(title, difficulty);
    if (!mounted) return;
    await load();
  }
}
