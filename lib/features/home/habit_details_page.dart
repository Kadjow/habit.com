import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/date_only.dart';
import '../../domain/models/habit.dart';
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
        loading: () => const Center(child: CircularProgressIndicator()),
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
        data: (s) {
          final today = todayLocal();

          // 14 dias: hoje -> 13 dias atras
          final days = List<DateTime>.generate(
            14,
            (i) => today.subtract(Duration(days: i)),
          );

          final statusToday = s.todayStatusByHabitId[habit.id] ?? 0;
          final rhythm = s.rhythm14DaysByHabitId[habit.id] ?? 0.0;
          final rhythmPercent = (rhythm * 100).round();

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
                  // OBS: No seu state atual, voce guarda status "de hoje" + rhythm.
                  // Para detalhar dia-a-dia, precisamos buscar por dia (ou manter cache).
                  // Entao aqui vamos usar um padrao:
                  // - Hoje: usa statusToday
                  // - Outros dias: apenas visual neutro (por enquanto)
                  // E ao clicar, a gente marca o dia no backend e da load().
                  final isToday = index == 0;
                  final status = isToday ? statusToday : 0;

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      // Toggle ciclo: 0 -> 2 (minimo) -> 1 (feito) -> 0
                      final next = _nextStatus(status);
                      try {
                        // Reaproveita o mesmo metodo do controller (salva "hoje").
                        // Para salvar dia especifico, precisaríamos de outro metodo.
                        // Aqui, quando for hoje, funciona 100%.
                        // Proximo passo: criar toggle para dateKey.
                        if (isToday) {
                          await controller.toggleCheckin(habit.id, next == 1 ? 1 : 2);
                        } else {
                          // Placeholder UX: por enquanto so avisa.
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Proximo passo: habilitar toggle por dia (nao so hoje).',
                                ),
                              ),
                            );
                          }
                        }
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Ajusta tamanhos para caber em qualquer tile (evita overflow).
                          final h = constraints.maxHeight;
                          final dayFont = h >= 52 ? 14.0 : (h >= 44 ? 13.0 : 12.0);
                          final weekFont = h >= 52 ? 11.0 : 10.0;
                          final iconSize = h >= 52 ? 18.0 : 16.0;
                          final gap1 = h >= 52 ? 2.0 : 1.0;
                          final gap2 = h >= 52 ? 3.0 : 2.0;

                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${day.day}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(fontSize: dayFont),
                                ),
                                SizedBox(height: gap1),
                                Text(
                                  _shortWeekday(day),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(fontSize: weekFont),
                                ),
                                SizedBox(height: gap2),
                                _statusDot(context, status, size: iconSize),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
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
