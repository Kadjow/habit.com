import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_controller.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsState = ref.watch(homeControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit AI'),
      ),
      body: habitsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (state) {
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.habits.length,
            separatorBuilder: (_, __) => const Divider(height: 24),
            itemBuilder: (context, index) {
              final habit = state.habits[index];
              final status = state.todayStatusByHabitId[habit.id] ?? 0;
              final rhythm = state.rhythm14DaysByHabitId[habit.id] ?? 0.0;
              final rhythmPercent = (rhythm * 100).round();
              final isDone = status == 1;
              final isMinDone = status == 2;

              return Card(
                elevation: 0,
                color: colorScheme.surfaceVariant.withOpacity(0.4),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text('Ritmo 14 dias: $rhythmPercent%'),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: rhythm,
                          minHeight: 8,
                          backgroundColor: colorScheme.surfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                ref
                                    .read(homeControllerProvider.notifier)
                                    .toggleCheckin(habit.id, 1);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: isDone
                                    ? colorScheme.primary
                                    : colorScheme.surfaceVariant,
                                foregroundColor: isDone
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurfaceVariant,
                              ),
                              child: const Text('Feito'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                ref
                                    .read(homeControllerProvider.notifier)
                                    .toggleCheckin(habit.id, 2);
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: isMinDone
                                      ? colorScheme.primary
                                      : colorScheme.outline,
                                ),
                                foregroundColor: isMinDone
                                    ? colorScheme.primary
                                    : colorScheme.onSurface,
                              ),
                              child: const Text('Mínimo'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateHabitSheet(context, ref),
        label: const Text('Novo hábito'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateHabitSheet(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();
    var difficulty = 1.0;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Novo hábito',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do hábito',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Dificuldade: ${difficulty.round()}'),
                  Slider(
                    value: difficulty,
                    min: 1,
                    max: 3,
                    divisions: 2,
                    label: difficulty.round().toString(),
                    onChanged: (value) => setState(() => difficulty = value),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final title = textController.text.trim();
                        if (title.isEmpty) {
                          return;
                        }
                        await ref
                            .read(homeControllerProvider.notifier)
                            .createHabit(title, difficulty.round());
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('Salvar'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
