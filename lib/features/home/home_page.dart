import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers.dart';
import '../../ui/widgets/app_badge.dart';
import '../../ui/widgets/empty_state.dart';
import '../../ui/widgets/metric_card.dart';
import '../../ui/widgets/product_header.dart';
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const ProductHeader(
                title: 'Seu progresso, na prática',
                subtitle:
                    'Acompanhe consistência e ritmo. Pequenas vitórias, todos os dias.',
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _HomeBody(
                    key: ValueKey(_homeBodyKey(state)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateHabitSheet(context, ref),
        label: const Text('Novo hábito'),
        icon: const Icon(Icons.add),
      ),
    );
  }

}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeControllerProvider);
    final controller = ref.read(homeControllerProvider.notifier);

    return state.when(
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
        final total = s.habits.length;
        final active = s.habits.where((h) => h.isActive).length;
        final todayDone =
            s.todayStatusByHabitId.values.where((v) => v == 1).length;
        final rhythmAvg = s.rhythm14DaysByHabitId.isEmpty
            ? 0.0
            : (s.rhythm14DaysByHabitId.values.reduce((a, b) => a + b) /
                s.rhythm14DaysByHabitId.length);

        return RefreshIndicator(
          onRefresh: () async => controller.load(),
          child: s.habits.isEmpty
              ? ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const SizedBox(height: 24),
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
              : ListView(
                  key: const ValueKey('home_body'),
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MetricCard(
                            title: 'Hoje',
                            value: '$todayDone/$active',
                            subtitle: 'hábitos feitos',
                            icon: Icons.check_circle_rounded,
                            accent: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MetricCard(
                            title: 'Ritmo',
                            value: '${(rhythmAvg * 100).round()}%',
                            subtitle: 'últimos 14 dias',
                            icon: Icons.auto_graph_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    MetricCard(
                      title: 'Ativos',
                      value: '$active',
                      subtitle: 'de $total hábitos',
                      icon: Icons.bolt_rounded,
                      trailing: AppBadge(
                        text: active > 0 ? 'Em andamento' : 'Crie um hábito',
                        color: active > 0 ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Seus hábitos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    ...s.habits.map((habit) {
                      final status = s.todayStatusByHabitId[habit.id] ?? 0;
                      final rhythm = s.rhythm14DaysByHabitId[habit.id] ?? 0.0;
                      final rhythmPercent = (rhythm * 100).round();
                      final isDone = status == 1;
                      final isMinDone = status == 2;

                      final badgeText = status == 1
                          ? 'Feito hoje'
                          : status == 2
                              ? 'Mínimo'
                              : 'Pendente';

                      final badgeColor = status == 1
                          ? Colors.green
                          : status == 2
                              ? Colors.orange
                              : Colors.grey;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
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
                                      AppBadge(
                                        text: badgeText,
                                        color: badgeColor,
                                      ),
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
                                                      'Falha ao salvar. Tente novamente.',
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          child:
                                              Text(isDone ? 'Feito ✓' : 'Feito'),
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
                                                      'Falha ao salvar. Tente novamente.',
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          child: Text(
                                            isMinDone ? 'Mínimo ✓' : 'Mínimo',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
        );
      },
    );
  }
}

String _homeBodyKey(AsyncValue<HomeState> state) {
  if (state.isLoading) return 'loading';
  if (state.hasError) return 'error';
  return 'data-${state.value?.habits.length ?? 0}';
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
