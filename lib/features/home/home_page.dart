import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers.dart';
import '../../ui/widgets/empty_state.dart';
import '../../ui/widgets/habit_status_chip.dart';
import '../../ui/widgets/section_header.dart';
import 'home_controller.dart';
import 'habit_details_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeControllerProvider);
    final controller = ref.read(homeControllerProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final v = ref.read(homeControllerProvider);
      if (v is AsyncLoading || v.value == null) {
        controller.load();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Habits'),
            Consumer(
              builder: (context, ref, _) {
                final uid = ref.watch(authUserIdProvider);
                final email = ref.watch(authUserEmailProvider);
                return Text(
                  '${email ?? '-'} | ${uid?.substring(0, 8) ?? '-'}',
                  style: Theme.of(context).textTheme.labelSmall,
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await Supabase.instance.client.auth
                  .signOut(scope: SignOutScope.global);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          title: 'Falha ao carregar',
          subtitle: e.toString(),
          icon: Icons.error_outline,
          action: FilledButton(
            onPressed: () => controller.load(),
            child: const Text('Tentar novamente'),
          ),
        ),
        data: (s) {
          return RefreshIndicator(
            onRefresh: () async => controller.load(),
            child: s.habits.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      EmptyState(
                        title: 'Nenhum hábito ainda',
                        subtitle: 'Crie seu primeiro hábito para começar.',
                        icon: Icons.auto_awesome_outlined,
                        action: FilledButton(
                          onPressed: () => _showCreateHabitSheet(context, ref),
                          child: const Text('Novo hábito'),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: s.habits.length + 1,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const SectionHeader('Hoje');
                      }

                      final habit = s.habits[index - 1];
                      final status = s.todayStatusByHabitId[habit.id] ?? 0;
                      final rhythm = s.rhythm14DaysByHabitId[habit.id] ?? 0.0;
                      final rhythmPercent = (rhythm * 100).round();

                      final isDone = status == 1;
                      final isMinDone = status == 2;

                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    HabitDetailsPage(habit: habit),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      habit.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                  HabitStatusChip(status: status),
                                  if (controller.isRefreshing) ...[
                                    const SizedBox(width: 8),
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Ritmo 14 dias: $rhythmPercent%'),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(value: rhythm),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () async {
                                        try {
                                          await ref
                                              .read(homeControllerProvider
                                                  .notifier)
                                              .toggleCheckin(habit.id, 1);
                                        } catch (_) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Falha ao salvar. Tente novamente.'),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      child: Text(isDone ? 'Feito \u2713' : 'Feito'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        try {
                                          await ref
                                              .read(homeControllerProvider
                                                  .notifier)
                                              .toggleCheckin(habit.id, 2);
                                        } catch (_) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Falha ao salvar. Tente novamente.'),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      child: Text(
                                          isMinDone ? 'Mínimo \u2713' : 'Mínimo'),
                                    ),
                                  ),
                                ],
                              ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateHabitSheet(context, ref),
        label: const Text('Novo h\u00e1bito'),
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
                    'Novo h\u00e1bito',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do h\u00e1bito',
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
                        if (title.isEmpty) return;
                        await ref
                            .read(homeControllerProvider.notifier)
                            .createHabit(title, difficulty.round());
                        if (context.mounted) Navigator.of(context).pop();
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
