import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'home_controller.dart';
import 'home_habits_v2.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _didInitialLoad = false;
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(authUserIdProvider, (prev, next) {
      if (_didInitialLoad) return;
      if (next == null || next.isEmpty) return;
      _didInitialLoad = true;
      Future.microtask(() async {
        final notifier = ref.read(homeControllerProvider.notifier);
        await notifier.load();
        await notifier.refreshTodayStatus();
        await notifier.refreshWeekStatus();
      });
    });

    final uidNow = ref.watch(authUserIdProvider);
    if (!_didInitialLoad && uidNow != null && uidNow.isNotEmpty) {
      _didInitialLoad = true;
      Future.microtask(() async {
        final notifier = ref.read(homeControllerProvider.notifier);
        await notifier.load();
        await notifier.refreshTodayStatus();
        await notifier.refreshWeekStatus();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits'),
        actions: [
          IconButton(
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: HomeHabitsV2(
        onCreateHabit: () => _showCreateHabitSheet(context, ref),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateHabitSheet(context, ref),
        label: const Text('Novo habito'),
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
                    'Novo habito',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do habito',
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
