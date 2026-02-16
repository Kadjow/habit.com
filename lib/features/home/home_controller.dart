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
    'checkinsByHabitId': byHabit,
  };
}

class HomeState {
  final List<Habit> habits;
  final Map<String, int> todayStatusByHabitId;
  final Map<String, double> rhythm14DaysByHabitId;
  final Map<String, Map<String, int>> checkinsByHabitId;

  const HomeState({
    required this.habits,
    required this.todayStatusByHabitId,
    required this.rhythm14DaysByHabitId,
    required this.checkinsByHabitId,
  });
}

final homeControllerProvider =
    StateNotifierProvider.autoDispose<HomeController, AsyncValue<HomeState>>((
      ref,
    ) {
      // Recria quando user muda (login/logout) e reseta estado
      final uid = ref.watch(userIdProvider);
      return HomeController(ref.watch(habitRepositoryProvider), uid);
    });

class HomeController extends StateNotifier<AsyncValue<HomeState>> {
  final HabitRepository _repository;
  final String? _uid;
  bool _loading = false;
  bool _syncPending = false;
  bool _inLoad = false;

  // Debug counters (useful for tests)
  @visibleForTesting
  int debugLoadCalls = 0;

  @visibleForTesting
  int debugSilentRefreshRuns = 0;

  HomeController(this._repository, this._uid)
    : super(const AsyncValue.loading()) {
    if (_uid == null) {
      state = const AsyncValue.data(
        HomeState(
          habits: [],
          todayStatusByHabitId: {},
          rhythm14DaysByHabitId: {},
          checkinsByHabitId: {},
        ),
      );
      return;
    }
  }

  bool get isRefreshing => _loading;

  // Evita load() pesado em sequÃªncia (ex: vÃ¡rios taps no grid).
  // Faz um refresh silencioso com debounce.
  void scheduleSilentRefresh({
    Duration delay = const Duration(milliseconds: 600),
  }) {
    if (_syncPending) return;
    _syncPending = true;
    Future.delayed(delay, () async {
      _syncPending = false;
      if (!mounted) return;
      try {
        debugSilentRefreshRuns++;
        await load(); // refresh geral (silencioso)
      } catch (_) {
        // Sem crash: refresh Ã© "best effort"
      }
    });
  }

  Future<void> load() async {
    // ValidaÃ§Ã£o automÃ¡tica: se existir recursÃ£o (load chamando load),
    // isso quebra em debug/test e fica Ã³bvio.
    assert(
      !_inLoad,
      'HomeController.load() called recursively. '
      'Never call load() from inside load(). Use scheduleSilentRefresh().',
    );
    if (_loading) return;
    _inLoad = true;
    debugLoadCalls++;
    _loading = true;
    // UX: evita "piscar" a tela toda vez que carrega.
    // Se ja ha dados, mantemos e carregamos em background.
    final previous = state.value;
    if (previous == null) {
      state = const AsyncValue.loading();
    }
    try {
      if (_uid == null) {
        state = const AsyncValue.data(
          HomeState(
            habits: [],
            todayStatusByHabitId: {},
            rhythm14DaysByHabitId: {},
            checkinsByHabitId: {},
          ),
        );
        return;
      }

      final habits = await _repository.listHabits();
      if (!mounted) return;
      if (habits.isEmpty) {
        state = const AsyncValue.data(
          HomeState(
            habits: [],
            todayStatusByHabitId: {},
            rhythm14DaysByHabitId: {},
            checkinsByHabitId: {},
          ),
        );
        return;
      }

      final today = todayLocal();
      final todayKey = toDateKey(today);

      final habitIds = habits.map((h) => h.id).toList();
      final allCheckins = await _repository.lastCheckinsForHabits(
        habitIds,
        14,
        todayKey,
      );
      if (!mounted) return;

      // Payload serializavel pro isolate
      final payload = <String, dynamic>{
        'habitIds': habitIds,
        'todayKey': todayKey,
        'todayMillis': today.millisecondsSinceEpoch,
        'checkins': allCheckins
            .map(
              (c) => {
                'habitId': c.habitId,
                'dateKey': c.dateKey,
                'status': c.status,
              },
            )
            .toList(),
      };

      // Web pode nao suportar isolate como esperado; fallback sync.
      final out = kIsWeb
          ? _buildHomeMetrics(payload)
          : await compute(_buildHomeMetrics, payload);
      if (!mounted) return;

      final todayStatusByHabitId = (out['todayStatusByHabitId'] as Map)
          .cast<String, int>();
      final rhythm14DaysByHabitId = (out['rhythm14DaysByHabitId'] as Map)
          .cast<String, double>();
      final checkinsByHabitId = (out['checkinsByHabitId'] as Map)
          .map<String, Map<String, int>>(
            (hid, v) => MapEntry(hid as String, (v as Map).cast<String, int>()),
          );

      state = AsyncValue.data(
        HomeState(
          habits: habits,
          todayStatusByHabitId: todayStatusByHabitId,
          rhythm14DaysByHabitId: rhythm14DaysByHabitId,
          checkinsByHabitId: checkinsByHabitId,
        ),
      );
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
      _inLoad = false;
    }
  }

  Future<void> toggleCheckin(String habitId, int status) async {
    final currentState = state.value;
    if (currentState == null || _uid == null) return;

    final todayKey = toDateKey(todayLocal());
    final current = currentState.todayStatusByHabitId[habitId] ?? 0;
    final nextStatus = (current == status) ? 0 : status;

    await setCheckinForDate(habitId, todayKey, nextStatus);
  }

  Future<void> setCheckinForDate(
    String habitId,
    String dateKey,
    int nextStatus,
  ) async {
    final currentState = state.value;
    if (currentState == null || _uid == null) return;

    final updatedByHabit = Map<String, Map<String, int>>.from(
      currentState.checkinsByHabitId,
    );
    final byDate = Map<String, int>.from(
      updatedByHabit[habitId] ?? <String, int>{},
    );

    // optimistic
    byDate[dateKey] = nextStatus;
    updatedByHabit[habitId] = byDate;

    final today = todayLocal();
    final todayKey = toDateKey(today);

    // today status
    final updatedToday = Map<String, int>.from(
      currentState.todayStatusByHabitId,
    )..[habitId] = byDate[todayKey] ?? 0;

    // rhythm 14d
    var doneCount = 0;
    for (var i = 0; i < 14; i++) {
      final dk = toDateKey(today.subtract(Duration(days: i)));
      final s = byDate[dk] ?? 0;
      if (s == 1 || s == 2) doneCount++;
    }
    final updatedRhythm = Map<String, double>.from(
      currentState.rhythm14DaysByHabitId,
    )..[habitId] = doneCount / 14.0;

    state = AsyncValue.data(
      HomeState(
        habits: currentState.habits,
        todayStatusByHabitId: updatedToday,
        rhythm14DaysByHabitId: updatedRhythm,
        checkinsByHabitId: updatedByHabit,
      ),
    );

    try {
      await _repository.upsertCheckinForDateKey(habitId, dateKey, nextStatus);
      if (!mounted) return;
      // NÃƒO faz load() aqui â€” evita travar a UI.
      // Se quiser consistÃªncia 100% do backend, use scheduleSilentRefresh()
    } catch (_) {
      if (!mounted) return;
      state = AsyncValue.data(currentState); // rollback
      rethrow;
    }
  }

  Future<void> createHabit(String title, int difficulty) async {
    if (_uid == null) return;
    await _repository.createHabit(title, difficulty);
    if (!mounted) return;
    await load();
  }

  Future<void> deleteHabit(String habitId) async {
    await _repository.deleteHabit(habitId);
    await load();
  }
}
