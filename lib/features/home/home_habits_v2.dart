import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'habit_details_page.dart';
import 'home_controller.dart';

class HomeHabitsV2 extends ConsumerStatefulWidget {
  const HomeHabitsV2({super.key});

  static const _orderKey = 'home_habits_order_v2';
  static const _pinsKey = 'home_habits_pins_v2';

  @override
  ConsumerState<HomeHabitsV2> createState() => _HomeHabitsV2State();
}

class _HomeHabitsV2State extends ConsumerState<HomeHabitsV2> {
  bool _prefsReady = false;
  List<String> _order = const [];
  Set<String> _pinned = const <String>{};
  List<dynamic> _visibleHabits = const [];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final order =
        prefs.getStringList(HomeHabitsV2._orderKey) ?? const <String>[];
    final pins =
        (prefs.getStringList(HomeHabitsV2._pinsKey) ?? const <String>[])
            .toSet();
    if (!mounted) return;
    setState(() {
      _order = order;
      _pinned = pins;
      _prefsReady = true;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(HomeHabitsV2._orderKey, _order);
    await prefs.setStringList(HomeHabitsV2._pinsKey, _pinned.toList());
  }

  String _habitId(dynamic habit) {
    final id = habit.id;
    if (id is String) return id;
    return '$id';
  }

  String _habitTitle(dynamic habit) {
    try {
      final title = habit.title;
      if (title is String && title.isNotEmpty) return title;
    } catch (_) {}
    try {
      final name = habit.name;
      if (name is String && name.isNotEmpty) return name;
    } catch (_) {}
    return 'Habito';
  }

  List<dynamic> _applyOrderAndPins(List<dynamic> habits) {
    final byId = <String, dynamic>{for (final h in habits) _habitId(h): h};

    final pinnedOrdered = <dynamic>[];
    for (final id in _order) {
      if (_pinned.contains(id) && byId.containsKey(id)) {
        pinnedOrdered.add(byId[id]);
      }
    }

    for (final id in _pinned) {
      if (!_order.contains(id) && byId.containsKey(id)) {
        pinnedOrdered.add(byId[id]);
      }
    }

    final ordered = <dynamic>[];
    for (final id in _order) {
      if (!_pinned.contains(id) && byId.containsKey(id)) {
        ordered.add(byId[id]);
      }
    }

    final used = <String>{..._pinned, ..._order};
    final rest = habits.where((h) => !used.contains(_habitId(h))).toList();

    return <dynamic>[...pinnedOrdered, ...ordered, ...rest];
  }

  Future<bool> _confirmDelete(BuildContext context, dynamic habit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir habito?'),
        content: Text('Deseja excluir "${_habitTitle(habit)}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  void _openDetails(BuildContext context, dynamic habit) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => HabitDetailsPage(habit: habit)));
  }

  @override
  Widget build(BuildContext context) {
    final homeAsync = ref.watch(homeControllerProvider);
    final controller = ref.read(homeControllerProvider.notifier);

    return SafeArea(
      child: homeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Erro ao carregar habitos.'),
              const SizedBox(height: 8),
              Text(e.toString(), maxLines: 4, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: controller.load,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (state) {
          final baseHabits = state.habits.cast<dynamic>();
          final ordered = _prefsReady
              ? _applyOrderAndPins(baseHabits)
              : baseHabits;
          _visibleHabits = List<dynamic>.from(ordered);

          if (_visibleHabits.isEmpty) {
            return RefreshIndicator(
              onRefresh: controller.load,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                children: const [
                  SizedBox(height: 48),
                  Icon(Icons.auto_awesome_outlined, size: 40),
                  SizedBox(height: 12),
                  Text(
                    'Nenhum habito ainda',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Crie seu primeiro habito no botao +.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: controller.load,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 18,
                          spreadRadius: -6,
                          offset: Offset(0, 10),
                          color: Colors.black12,
                        ),
                      ],
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.tertiary,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Seus habitos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Arraste para priorizar. Direita fixa, esquerda exclui.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, _) {
                          final t = Curves.easeInOut.transform(animation.value);
                          final elev = lerpDouble(0, 8, t) ?? 0;
                          return Material(
                            elevation: elev,
                            borderRadius: BorderRadius.circular(18),
                            child: child,
                          );
                        },
                        child: child,
                      );
                    },
                    itemCount: _visibleHabits.length,
                    onReorder: (oldIndex, newIndex) async {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _visibleHabits.removeAt(oldIndex);
                        _visibleHabits.insert(newIndex, item);
                        _order = _visibleHabits.map(_habitId).toList();
                      });
                      await _savePrefs();
                    },
                    itemBuilder: (context, index) {
                      final habit = _visibleHabits[index];
                      final id = _habitId(habit);
                      final pinned = _pinned.contains(id);

                      return Dismissible(
                        key: ValueKey('habit_$id'),
                        direction: DismissDirection.horizontal,
                        background: _SwipeBackground(
                          alignLeft: true,
                          icon: pinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          label: pinned ? 'Desafixar' : 'Fixar',
                        ),
                        secondaryBackground: const _SwipeBackground(
                          alignLeft: false,
                          icon: Icons.delete_outline,
                          label: 'Excluir',
                        ),
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.startToEnd) {
                            setState(() {
                              if (_pinned.contains(id)) {
                                _pinned.remove(id);
                              } else {
                                _pinned.add(id);
                                if (!_order.contains(id)) {
                                  _order = <String>[id, ..._order];
                                }
                              }
                              _visibleHabits = _applyOrderAndPins(
                                _visibleHabits,
                              );
                            });
                            await _savePrefs();
                            if (!context.mounted) return false;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  pinned
                                      ? 'Habito desafixado'
                                      : 'Habito fixado no topo',
                                ),
                              ),
                            );
                            return false;
                          }

                          final ok = await _confirmDelete(context, habit);
                          if (!ok) return false;

                          setState(() {
                            _visibleHabits.removeAt(index);
                            _order = _visibleHabits.map(_habitId).toList();
                            _pinned.remove(id);
                          });
                          await _savePrefs();

                          try {
                            await (controller as dynamic).deleteHabit(id);
                          } catch (_) {}

                          controller.load();
                          return true;
                        },
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => _openDetails(context, habit),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(99),
                                        gradient: LinearGradient(
                                          colors: [
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            Theme.of(
                                              context,
                                            ).colorScheme.secondary,
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _habitTitle(habit),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              AnimatedSwitcher(
                                                duration: const Duration(
                                                  milliseconds: 180,
                                                ),
                                                child: pinned
                                                    ? const Icon(
                                                        Icons.push_pin,
                                                        key: ValueKey('pinned'),
                                                        size: 18,
                                                      )
                                                    : const SizedBox(
                                                        key: ValueKey(
                                                          'unpinned',
                                                        ),
                                                        width: 18,
                                                        height: 18,
                                                      ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            pinned
                                                ? 'Fixado no topo'
                                                : 'Arraste para priorizar',
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: Icon(
                                        Icons.drag_handle_rounded,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.55),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  final bool alignLeft;
  final IconData icon;
  final String label;

  const _SwipeBackground({
    required this.alignLeft,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            spreadRadius: -6,
            offset: Offset(0, 10),
            color: Colors.black12,
          ),
        ],
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.25),
            Theme.of(context).colorScheme.error.withOpacity(0.25),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: alignLeft
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (!alignLeft) ...[
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
          ],
          Icon(icon),
          if (alignLeft) ...[
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}
