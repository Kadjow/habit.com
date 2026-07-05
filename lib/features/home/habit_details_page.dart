import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_controller.dart';

class HabitDetailsPage extends ConsumerWidget {
  final String habitId;
  final String title;
  final int difficulty;

  const HabitDetailsPage({
    super.key,
    required this.habitId,
    required this.title,
    required this.difficulty,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHome = ref.watch(homeControllerProvider);
    final ctrl = ref.read(homeControllerProvider.notifier);
    final doneToday = ctrl.isDoneToday(habitId);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Dificuldade: $difficulty',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Hoje:',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(width: 8),
                      Chip(label: Text(doneToday ? 'Feito' : 'Pendente')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: asyncHome.isLoading
                      ? null
                      : () async {
                          try {
                            await ctrl.toggleToday(habitId);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erro ao salvar: $e')),
                              );
                            }
                          }
                        },
                  icon: Icon(
                    doneToday ? Icons.undo : Icons.check_circle_outline,
                  ),
                  label: Text(doneToday ? 'Desmarcar hoje' : 'Marcar hoje'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Proximo passo: historico + consistencia (ultimos 7 dias).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
