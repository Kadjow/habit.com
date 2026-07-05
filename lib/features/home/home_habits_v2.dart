import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'habit_details_page.dart';
import 'home_controller.dart';

class HomeHabitsV2 extends ConsumerWidget {
  final VoidCallback? onCreateHabit;

  const HomeHabitsV2({super.key, this.onCreateHabit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHome = ref.watch(homeControllerProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: asyncHome.when(
        loading: () => const _HabitsLoading(),
        error: (e, _) => _HabitsError(
          message: e.toString(),
          onRetry: () async {
            final notifier = ref.read(homeControllerProvider.notifier);
            await notifier.load();
            await notifier.refreshTodayStatus();
            await notifier.refreshWeekStatus();
          },
        ),
        data: (home) {
          final list = home.habits;
          return RefreshIndicator(
            onRefresh: () async {
              final notifier = ref.read(homeControllerProvider.notifier);
              await notifier.load();
              await notifier.refreshTodayStatus();
              await notifier.refreshWeekStatus();
            },
            child: list.isEmpty
                ? _HabitsEmpty(onCreateHabit: onCreateHabit)
                : _HabitsList(habits: list),
          );
        },
      ),
    );
  }
}

class _HabitsLoading extends StatelessWidget {
  const _HabitsLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        const _HeaderCard(title: 'Seus habitos', subtitle: 'Carregando...'),
        const SizedBox(height: 14),
        for (var i = 0; i < 6; i++) ...[
          const _SkeletonCard(),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _HabitsError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _HabitsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        const _HeaderCard(
          title: 'Seus habitos',
          subtitle: 'Ocorreu um erro ao carregar.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Erro', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await onRetry();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HabitsEmpty extends StatelessWidget {
  final VoidCallback? onCreateHabit;

  const _HabitsEmpty({this.onCreateHabit});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      children: [
        const _HeaderCard(
          title: 'Seus habitos',
          subtitle: 'Ainda nao ha habitos cadastrados.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comece agora',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Crie seu primeiro habito e acompanhe sua consistencia dia a dia.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onCreateHabit,
                    icon: const Icon(Icons.add),
                    label: const Text('Criar habito'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HabitsList extends ConsumerWidget {
  final List<dynamic> habits;

  const _HabitsList({required this.habits});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(homeControllerProvider.notifier);
    final keys = ctrl.last7DateKeys();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: habits.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return const _HeaderCard(
            title: 'Seus habitos',
            subtitle: 'Ultimos 7 dias. Puxe para atualizar.',
          );
        }

        final h = habits[index - 1];
        final id = _idOf(h);
        final title = _titleOf(h);
        final diff = _difficultyOf(h);
        final flags = keys
            .map((dateKey) => ctrl.isChecked7d(id, dateKey))
            .toList(growable: false);
        final done7 = flags.where((v) => v).length;

        final card = _HabitCard(
          title: title,
          difficulty: diff,
          done7: done7,
          weekFlags: flags,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HabitDetailsPage(
                  habitId: id,
                  title: title,
                  difficulty: diff,
                ),
              ),
            );
          },
        );

        if (id.isNotEmpty) {
          return Dismissible(
            key: ValueKey(id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _confirmDelete(context, title),
            onDismissed: (_) {
              ref.read(homeControllerProvider.notifier).deleteHabit(id);
            },
            background: const SizedBox.shrink(),
            secondaryBackground: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            child: card,
          );
        }

        return card;
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String title) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excluir habito'),
            content: Text('Deseja excluir "$title"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HeaderCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Theme.of(context).colorScheme.primary.withOpacity(0.75),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final String title;
  final int difficulty;
  final int done7;
  final List<bool> weekFlags;
  final VoidCallback onTap;

  const _HabitCard({
    required this.title,
    required this.difficulty,
    required this.done7,
    required this.weekFlags,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: cs.primary.withOpacity(0.10),
                ),
                child: Icon(Icons.check_circle_outline, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Dificuldade: $difficulty',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Spacer(),
                        _CountPill(done7: done7),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _WeekDots(flags: weekFlags),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: cs.onSurface.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final int done7;

  const _CountPill({required this.done7});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
      ),
      child: Text('$done7/7', style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _WeekDots extends StatelessWidget {
  final List<bool> flags;

  const _WeekDots({required this.flags});

  @override
  Widget build(BuildContext context) {
    final on = Theme.of(context).colorScheme.primary.withOpacity(0.85);
    final off = Theme.of(context).colorScheme.onSurface.withOpacity(0.10);

    return Row(
      children: [
        for (var i = 0; i < flags.length; i++) ...[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: flags[i] ? on : off,
            ),
          ),
          if (i < flags.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface.withOpacity(0.06);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: base,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 120,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _titleOf(dynamic h) {
  try {
    final v = (h as dynamic).title;
    if (v != null) return v.toString();
  } catch (_) {}
  try {
    final v = (h as dynamic).name;
    if (v != null) return v.toString();
  } catch (_) {}
  try {
    final m = (h as dynamic).toJson();
    if (m is Map && m['title'] != null) return m['title'].toString();
    if (m is Map && m['name'] != null) return m['name'].toString();
  } catch (_) {}
  if (h is Map) {
    if (h['title'] != null) return h['title'].toString();
    if (h['name'] != null) return h['name'].toString();
  }
  return 'Habito';
}

String _idOf(dynamic h) {
  try {
    final v = (h as dynamic).id;
    if (v != null) return v.toString();
  } catch (_) {}
  try {
    final v = (h as dynamic).habitId;
    if (v != null) return v.toString();
  } catch (_) {}
  try {
    final m = (h as dynamic).toJson();
    if (m is Map && m['id'] != null) return m['id'].toString();
    if (m is Map && m['habitId'] != null) return m['habitId'].toString();
  } catch (_) {}
  if (h is Map) {
    if (h['id'] != null) return h['id'].toString();
    if (h['habitId'] != null) return h['habitId'].toString();
  }
  return '';
}

int _difficultyOf(dynamic h) {
  try {
    final v = (h as dynamic).difficulty;
    if (v is int) return v;
    if (v != null) return int.tryParse(v.toString()) ?? 1;
  } catch (_) {}
  try {
    final m = (h as dynamic).toJson();
    if (m is Map && m['difficulty'] != null) {
      return int.tryParse(m['difficulty'].toString()) ?? 1;
    }
  } catch (_) {}
  if (h is Map && h['difficulty'] != null) {
    return int.tryParse(h['difficulty'].toString()) ?? 1;
  }
  return 1;
}
