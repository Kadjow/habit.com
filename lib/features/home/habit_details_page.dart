import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/date_only.dart';
import '../../domain/models/habit.dart';
import '../../ui/widgets/habit_status_chip.dart';
import '../../ui/widgets/section_header.dart';
import 'home_controller.dart';

class HabitDetailsPage extends ConsumerWidget {
  final Habit habit;
  const HabitDetailsPage({super.key, required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeControllerProvider);
    final controller = ref.read(homeControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(habit.title),
      ),
      body: state.when(
        loading: () {
          final previous = state.value;
          if (previous != null) {
            return _BodyWithState(
              state: previous,
              habit: habit,
              controller: controller,
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 32),
                const SizedBox(height: 12),
                Text(
                  'Nao foi possivel carregar este habito.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => controller.load(),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
        data: (s) => _BodyWithState(
          state: s,
          habit: habit,
          controller: controller,
        ),
      ),
    );
  }
}

class _BodyWithState extends StatelessWidget {
  final HomeState state;
  final Habit habit;
  final HomeController controller;

  const _BodyWithState({
    required this.state,
    required this.habit,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final today = todayLocal();

    // 14 dias: hoje -> 13 dias atras
    final days = List<DateTime>.generate(
      14,
      (i) => today.subtract(Duration(days: i)),
    );

    final statusToday = state.todayStatusByHabitId[habit.id] ?? 0;
    final rhythm = state.rhythm14DaysByHabitId[habit.id] ?? 0.0;
    final rhythmPercent = (rhythm * 100).round();
    final map = state.checkinsByHabitId[habit.id] ?? const <String, int>{};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('Hoje: ${_statusLabel(statusToday)}'),
                const SizedBox(height: 8),
                Text('Ritmo 14 dias: $rhythmPercent%'),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: rhythm),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Ultimos 14 dias',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const SectionHeader('Legenda'),
        const SizedBox(height: 8),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            HabitStatusChip(status: 1),
            HabitStatusChip(status: 2),
            HabitStatusChip(status: 0),
          ],
        ),
        const SizedBox(height: 12),

        // Grid simples: 7 colunas, 2 linhas
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final day = days[index];
            final key = toDateKey(day);
            final status = map[key] ?? (index == 0 ? statusToday : 0);

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                // Toggle ciclo: 0 -> 2 (minimo) -> 1 (feito) -> 0
                final next = _nextStatus(status);
                try {
                  await controller.setCheckinForDate(habit.id, key, next);
                  // refresh leve (debounce) para puxar backend sem travar UI
                  controller.scheduleSilentRefresh();
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Falha ao salvar.')),
                    );
                  }
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                padding: EdgeInsets.zero,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Tiles podem ficar ~33x33 no crossAxisCount: 7
                    // Stack evita RenderFlex overflow (Column).
                    final h = constraints.maxHeight;
                    final isTiny = h <= 36;

                    final dayFont = isTiny ? 11.0 : (h < 48 ? 12.0 : 14.0);
                    final weekFont = isTiny ? 9.0 : 10.0;
                    final iconSize = isTiny ? 14.0 : 16.0;

                    return Stack(
                      children: [
                        Positioned(
                          left: 4,
                          top: 3,
                          child: Text(
                            '${day.day}',
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(fontSize: dayFont),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 5,
                          child: Text(
                            _shortWeekday(day),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(fontSize: weekFont),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 3,
                          child: Center(
                            child: _statusDot(
                              context,
                              status,
                              size: iconSize,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

int _nextStatus(int current) {
  // 0 -> 2 -> 1 -> 0
  if (current == 0) return 2;
  if (current == 2) return 1;
  return 0;
}

String _statusLabel(int s) {
  if (s == 1) return 'Feito';
  if (s == 2) return 'Minimo';
  return 'Nada';
}

Widget _statusDot(BuildContext context, int status, {double size = 18}) {
  IconData icon;
  if (status == 1) {
    icon = Icons.check_circle;
  } else if (status == 2) {
    icon = Icons.remove_circle;
  } else {
    icon = Icons.circle_outlined;
  }
  return Icon(icon, size: size);
}

String _shortWeekday(DateTime d) {
  // PT-BR curtinho sem intl
  const names = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
  return names[d.weekday % 7];
}
