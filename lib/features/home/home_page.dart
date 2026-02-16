import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers.dart';
import 'home_controller.dart';
import 'home_habits_v2.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _didLoadOnce = false;

  @override
  void initState() {
    super.initState();

    // Dispara o load uma única vez, com segurança contra dispose.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_didLoadOnce) return;
      _didLoadOnce = true;

      final controller = ref.read(homeControllerProvider.notifier);
      final value = ref.read(homeControllerProvider);

      // Só carrega se ainda não há dados.
      if (value is AsyncLoading || value.value == null) {
        controller.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
              await Supabase.instance.client.auth.signOut(
                scope: SignOutScope.global,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const HomeHabitsV2(),
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
