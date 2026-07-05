# Gamificação Local (Fase 1) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar gamificação offline (XP, níveis, streak, badges, meta semanal) derivada do histórico de check-ins, sem backend.

**Architecture:** Regras puras em `lib/domain/gamification/` (sem I/O, testáveis isoladas). Persistência do não-derivável (meta semanal, badges vistos) via `GamificationRepository` local em `SharedPreferences`. Um `gamificationControllerProvider` combina histórico + regras → `GamificationSnapshot` que a UI (em `lib/shared/ui/`) consome. Tudo travado por `FeatureFlags.gamification`.

**Tech Stack:** Flutter, Dart, flutter_riverpod, shared_preferences, flutter_test.

## Global Constraints

- Dart SDK: `^3.10.0`. Sem novas dependências (usar shared_preferences + uuid já presentes).
- **NÃO commitar nem dar push.** Onde o fluxo normal commitaria, apenas deixar as mudanças staged; o usuário commita. (Ver memória `no-commit-no-push`.)
- Persistência local apenas (`SharedPreferences`). Sem rede, sem Supabase.
- Datas sempre via `dateKey` `YYYY-MM-DD` de `lib/core/time/date_only.dart` (`toDateKey`/`fromDateKey`/`todayLocal`). Nunca comparar `DateTime` cru.
- Check-in `status`: `0` não feito, `1`/`2` feito. Um dia é "ativo" se ≥1 hábito tem status 1 ou 2 nele.
- Testes de widget passam por `test/test_app.dart` (sem rede). Suíte inteira deve ficar verde.
- Sistema de UI canônico: `lib/shared/ui/`. Código novo vai pra lá.
- XP v1: `xp = nºCheckins * 10` (sem peso de dificuldade — futuro). Streak é global (dias ativos). Janela de histórico: 365 dias.

---

### Task 1: Feature flag `gamification`

**Files:**
- Modify: `lib/config/feature_flags.dart`
- Test: `test/gamification/feature_flags_test.dart`

**Interfaces:**
- Produces: `FeatureFlags.gamification` (bool, default `true`).

- [ ] **Step 1: Write the failing test**

```dart
// test/gamification/feature_flags_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_ai/config/feature_flags.dart';

void main() {
  test('gamification flag default is true', () {
    const flags = FeatureFlags();
    expect(flags.gamification, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/gamification/feature_flags_test.dart`
Expected: FAIL — `The getter 'gamification' isn't defined`.

- [ ] **Step 3: Implement**

Em `lib/config/feature_flags.dart`, adicionar o campo:

```dart
class FeatureFlags {
  final bool coachingLLM;
  final bool adaptivePrompts;
  final bool autoWeeklyPlan;
  final bool syncEnabled;
  final bool gamification;

  const FeatureFlags({
    this.coachingLLM = false,
    this.adaptivePrompts = true,
    this.autoWeeklyPlan = false,
    this.syncEnabled = false,
    this.gamification = true,
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/gamification/feature_flags_test.dart`
Expected: PASS.

- [ ] **Step 5: Checkpoint (stage; usuário commita)**

Run: `git add lib/config/feature_flags.dart test/gamification/feature_flags_test.dart`
Não commitar. Deixar staged pro usuário.

---

### Task 2: Modelos de valor da gamificação

**Files:**
- Create: `lib/domain/gamification/models.dart`
- Test: `test/gamification/models_test.dart`

**Interfaces:**
- Produces:
  - `LevelInfo({required int level, required int xpIntoLevel, required int xpForNextLevel})`
  - `StreakInfo({required int current, required int longest})`
  - `enum BadgeId { firstCheckin, streak7, streak30, checkins100, weeklyGoalMet }`
  - `Badge({required BadgeId id, required String title, required String description})`
  - `WeeklyGoal({required int targetDays})` com `static const WeeklyGoal defaultGoal = WeeklyGoal(targetDays: 5)`
  - `WeeklyProgress({required int done, required int target})` com `bool get met` e `double get fraction`
  - `GamificationSnapshot({required int totalXp, required LevelInfo level, required StreakInfo streak, required Set<BadgeId> unlockedBadges, required WeeklyProgress weekly})`

- [ ] **Step 1: Write the failing test**

```dart
// test/gamification/models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_ai/domain/gamification/models.dart';

void main() {
  test('WeeklyProgress met and fraction', () {
    const p = WeeklyProgress(done: 5, target: 5);
    expect(p.met, isTrue);
    expect(p.fraction, 1.0);

    const partial = WeeklyProgress(done: 2, target: 5);
    expect(partial.met, isFalse);
    expect(partial.fraction, closeTo(0.4, 1e-9));
  });

  test('WeeklyProgress fraction clamps and handles target 0', () {
    const over = WeeklyProgress(done: 9, target: 5);
    expect(over.fraction, 1.0);
    const zero = WeeklyProgress(done: 3, target: 0);
    expect(zero.fraction, 0.0);
  });

  test('WeeklyGoal default is 5 days', () {
    expect(WeeklyGoal.defaultGoal.targetDays, 5);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/gamification/models_test.dart`
Expected: FAIL — arquivo/target não existe.

- [ ] **Step 3: Implement**

```dart
// lib/domain/gamification/models.dart
class LevelInfo {
  final int level;
  final int xpIntoLevel;
  final int xpForNextLevel;
  const LevelInfo({
    required this.level,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
  });
}

class StreakInfo {
  final int current;
  final int longest;
  const StreakInfo({required this.current, required this.longest});
}

enum BadgeId { firstCheckin, streak7, streak30, checkins100, weeklyGoalMet }

class Badge {
  final BadgeId id;
  final String title;
  final String description;
  const Badge({
    required this.id,
    required this.title,
    required this.description,
  });
}

class WeeklyGoal {
  final int targetDays;
  const WeeklyGoal({required this.targetDays});
  static const WeeklyGoal defaultGoal = WeeklyGoal(targetDays: 5);
}

class WeeklyProgress {
  final int done;
  final int target;
  const WeeklyProgress({required this.done, required this.target});

  bool get met => target > 0 && done >= target;
  double get fraction {
    if (target <= 0) return 0.0;
    final f = done / target;
    return f > 1.0 ? 1.0 : (f < 0.0 ? 0.0 : f);
  }
}

class GamificationSnapshot {
  final int totalXp;
  final LevelInfo level;
  final StreakInfo streak;
  final Set<BadgeId> unlockedBadges;
  final WeeklyProgress weekly;
  const GamificationSnapshot({
    required this.totalXp,
    required this.level,
    required this.streak,
    required this.unlockedBadges,
    required this.weekly,
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/gamification/models_test.dart`
Expected: PASS.

- [ ] **Step 5: Checkpoint (stage; usuário commita)**

Run: `git add lib/domain/gamification/models.dart test/gamification/models_test.dart`

---

### Task 3: Regras — XP e nível

**Files:**
- Create: `lib/domain/gamification/gamification_rules.dart`
- Test: `test/gamification/rules_xp_level_test.dart`

**Interfaces:**
- Consumes: `LevelInfo` (Task 2).
- Produces:
  - `const int xpPerCheckin = 10;`
  - `int totalXpFor(int checkinCount)`
  - `LevelInfo levelInfoFor(int xp)`

Curva de nível: nível `L` (a partir de 1) exige `L * 100` XP incremental. XP cumulativo para completar o nível `L` = `100 * L * (L + 1) / 2`. Nível 1 começa em 0 XP.

- [ ] **Step 1: Write the failing test**

```dart
// test/gamification/rules_xp_level_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_ai/domain/gamification/gamification_rules.dart';

void main() {
  test('totalXpFor multiplies count by xpPerCheckin', () {
    expect(totalXpFor(0), 0);
    expect(totalXpFor(3), 30);
    expect(xpPerCheckin, 10);
  });

  test('levelInfoFor level 1 boundaries', () {
    final l0 = levelInfoFor(0);
    expect(l0.level, 1);
    expect(l0.xpIntoLevel, 0);
    expect(l0.xpForNextLevel, 100); // nível 1 exige 100 XP

    final l99 = levelInfoFor(99);
    expect(l99.level, 1);
    expect(l99.xpIntoLevel, 99);
  });

  test('levelInfoFor crosses to level 2 at 100 xp', () {
    final l = levelInfoFor(100);
    expect(l.level, 2);
    expect(l.xpIntoLevel, 0);
    expect(l.xpForNextLevel, 200); // nível 2 exige 200 XP
  });

  test('levelInfoFor level 3 at cumulative 300', () {
    // nível1=100, nível2=200 -> cumulativo 300 para entrar no nível 3
    final l = levelInfoFor(300);
    expect(l.level, 3);
    expect(l.xpIntoLevel, 0);
    expect(l.xpForNextLevel, 300);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/gamification/rules_xp_level_test.dart`
Expected: FAIL — target não existe.

- [ ] **Step 3: Implement**

```dart
// lib/domain/gamification/gamification_rules.dart
import 'models.dart';

const int xpPerCheckin = 10;

int totalXpFor(int checkinCount) => checkinCount * xpPerCheckin;

/// Nível L exige (L * 100) XP para ser concluído.
int _xpToCompleteLevel(int level) => level * 100;

LevelInfo levelInfoFor(int xp) {
  var level = 1;
  var remaining = xp;
  while (remaining >= _xpToCompleteLevel(level)) {
    remaining -= _xpToCompleteLevel(level);
    level++;
  }
  return LevelInfo(
    level: level,
    xpIntoLevel: remaining,
    xpForNextLevel: _xpToCompleteLevel(level),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/gamification/rules_xp_level_test.dart`
Expected: PASS.

- [ ] **Step 5: Checkpoint (stage; usuário commita)**

Run: `git add lib/domain/gamification/gamification_rules.dart test/gamification/rules_xp_level_test.dart`

---

### Task 4: Regras — Streak

**Files:**
- Modify: `lib/domain/gamification/gamification_rules.dart`
- Test: `test/gamification/rules_streak_test.dart`

**Interfaces:**
- Consumes: `StreakInfo` (Task 2), `toDateKey` de `lib/core/time/date_only.dart`.
- Produces: `StreakInfo streakFrom(Set<String> doneDateKeys, DateTime today)`

Regra:
- `current`: conta dias consecutivos ativos terminando em hoje. Se hoje **não** está em `doneDateKeys` mas ontem está, ancora em ontem (streak "vivo"). Se nem hoje nem ontem, `current = 0`.
- `longest`: maior sequência consecutiva de dias ativos em todo o conjunto.

- [ ] **Step 1: Write the failing test**

```dart
// test/gamification/rules_streak_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_ai/core/time/date_only.dart';
import 'package:habit_ai/domain/gamification/gamification_rules.dart';

void main() {
  final today = DateTime(2026, 7, 4);
  String key(int daysAgo) => toDateKey(today.subtract(Duration(days: daysAgo)));

  test('empty set gives zero streak', () {
    final s = streakFrom(<String>{}, today);
    expect(s.current, 0);
    expect(s.longest, 0);
  });

  test('today + 2 previous days = current 3', () {
    final s = streakFrom({key(0), key(1), key(2)}, today);
    expect(s.current, 3);
    expect(s.longest, 3);
  });

  test('anchored on yesterday when today missing', () {
    final s = streakFrom({key(1), key(2)}, today);
    expect(s.current, 2);
  });

  test('current zero when gap before today and yesterday', () {
    final s = streakFrom({key(3), key(4)}, today);
    expect(s.current, 0);
    expect(s.longest, 2);
  });

  test('longest picks the biggest run', () {
    final s = streakFrom({
      key(10), key(11), key(12), key(13), // run de 4
      key(1), key(2), // run de 2
    }, today);
    expect(s.longest, 4);
    expect(s.current, 2);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/gamification/rules_streak_test.dart`
Expected: FAIL — `streakFrom` não definido.

- [ ] **Step 3: Implement**

Adicionar ao topo de `gamification_rules.dart` o import e a função:

```dart
// no topo do arquivo, junto do import existente:
import '../../core/time/date_only.dart';

// ... resto do arquivo ...

StreakInfo streakFrom(Set<String> doneDateKeys, DateTime today) {
  if (doneDateKeys.isEmpty) {
    return const StreakInfo(current: 0, longest: 0);
  }

  final todayOnly = DateTime(today.year, today.month, today.day);

  // current: ancora em hoje, senão ontem.
  var current = 0;
  DateTime? anchor;
  if (doneDateKeys.contains(toDateKey(todayOnly))) {
    anchor = todayOnly;
  } else if (doneDateKeys.contains(
      toDateKey(todayOnly.subtract(const Duration(days: 1))))) {
    anchor = todayOnly.subtract(const Duration(days: 1));
  }
  if (anchor != null) {
    var cursor = anchor;
    while (doneDateKeys.contains(toDateKey(cursor))) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
  }

  // longest: varre datas ordenadas.
  final dates = doneDateKeys.map(fromDateKey).toList()..sort();
  var longest = 1;
  var run = 1;
  for (var i = 1; i < dates.length; i++) {
    final diff = dates[i].difference(dates[i - 1]).inDays;
    if (diff == 1) {
      run++;
    } else if (diff > 1) {
      run = 1;
    }
    if (run > longest) longest = run;
  }

  return StreakInfo(current: current, longest: longest);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/gamification/rules_streak_test.dart`
Expected: PASS.

- [ ] **Step 5: Checkpoint (stage; usuário commita)**

Run: `git add lib/domain/gamification/gamification_rules.dart test/gamification/rules_streak_test.dart`

---

### Task 5: Regras — Meta semanal e badges

**Files:**
- Modify: `lib/domain/gamification/gamification_rules.dart`
- Test: `test/gamification/rules_weekly_badges_test.dart`

**Interfaces:**
- Consumes: `WeeklyGoal`, `WeeklyProgress`, `StreakInfo`, `BadgeId` (Task 2).
- Produces:
  - `WeeklyProgress weeklyProgressFor(Set<String> doneDateKeys, WeeklyGoal goal, DateTime today)` — conta dias ativos nos últimos 7 dias (janela rolante incluindo hoje).
  - `Set<BadgeId> unlockedBadgesFor({required int checkinCount, required StreakInfo streak, required bool weeklyMet})`

Regra de badges:
- `firstCheckin`: `checkinCount >= 1`
- `streak7`: `streak.longest >= 7`
- `streak30`: `streak.longest >= 30`
- `checkins100`: `checkinCount >= 100`
- `weeklyGoalMet`: `weeklyMet == true`

- [ ] **Step 1: Write the failing test**

```dart
// test/gamification/rules_weekly_badges_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_ai/core/time/date_only.dart';
import 'package:habit_ai/domain/gamification/gamification_rules.dart';
import 'package:habit_ai/domain/gamification/models.dart';

void main() {
  final today = DateTime(2026, 7, 4);
  String key(int daysAgo) => toDateKey(today.subtract(Duration(days: daysAgo)));

  test('weeklyProgressFor counts last 7 days only', () {
    final done = {key(0), key(1), key(6), key(7), key(8)}; // 7 e 8 fora
    final p = weeklyProgressFor(done, const WeeklyGoal(targetDays: 5), today);
    expect(p.done, 3);
    expect(p.target, 5);
    expect(p.met, isFalse);
  });

  test('weeklyProgressFor met when enough days', () {
    final done = {key(0), key(1), key(2), key(3), key(4)};
    final p = weeklyProgressFor(done, const WeeklyGoal(targetDays: 5), today);
    expect(p.done, 5);
    expect(p.met, isTrue);
  });

  test('unlockedBadgesFor thresholds', () {
    final none = unlockedBadgesFor(
      checkinCount: 0,
      streak: const StreakInfo(current: 0, longest: 0),
      weeklyMet: false,
    );
    expect(none, isEmpty);

    final some = unlockedBadgesFor(
      checkinCount: 1,
      streak: const StreakInfo(current: 7, longest: 7),
      weeklyMet: true,
    );
    expect(some, containsAll(<BadgeId>{
      BadgeId.firstCheckin,
      BadgeId.streak7,
      BadgeId.weeklyGoalMet,
    }));
    expect(some.contains(BadgeId.streak30), isFalse);
    expect(some.contains(BadgeId.checkins100), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/gamification/rules_weekly_badges_test.dart`
Expected: FAIL — funções não definidas.

- [ ] **Step 3: Implement**

Adicionar a `gamification_rules.dart`:

```dart
WeeklyProgress weeklyProgressFor(
  Set<String> doneDateKeys,
  WeeklyGoal goal,
  DateTime today,
) {
  final todayOnly = DateTime(today.year, today.month, today.day);
  var done = 0;
  for (var i = 0; i < 7; i++) {
    final k = toDateKey(todayOnly.subtract(Duration(days: i)));
    if (doneDateKeys.contains(k)) done++;
  }
  return WeeklyProgress(done: done, target: goal.targetDays);
}

Set<BadgeId> unlockedBadgesFor({
  required int checkinCount,
  required StreakInfo streak,
  required bool weeklyMet,
}) {
  final out = <BadgeId>{};
  if (checkinCount >= 1) out.add(BadgeId.firstCheckin);
  if (streak.longest >= 7) out.add(BadgeId.streak7);
  if (streak.longest >= 30) out.add(BadgeId.streak30);
  if (checkinCount >= 100) out.add(BadgeId.checkins100);
  if (weeklyMet) out.add(BadgeId.weeklyGoalMet);
  return out;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/gamification/rules_weekly_badges_test.dart`
Expected: PASS.

- [ ] **Step 5: Checkpoint (stage; usuário commita)**

Run: `git add lib/domain/gamification/gamification_rules.dart test/gamification/rules_weekly_badges_test.dart`

---

### Task 6: `GamificationRepository` (interface + impl local)

**Files:**
- Create: `lib/domain/gamification/gamification_repository.dart`
- Create: `lib/data/repositories/gamification_repository_local.dart`
- Test: `test/gamification/gamification_repository_local_test.dart`

**Interfaces:**
- Consumes: `WeeklyGoal`, `BadgeId` (Task 2); `toDateKey`/`fromDateKey`.
- Produces (`abstract class GamificationRepository`):
  - `Future<Set<String>> doneDateKeys({int windowDays = 365})` — dias com ≥1 hábito feito.
  - `Future<int> totalCheckins()` — total de check-ins com status 1/2.
  - `Future<WeeklyGoal> getWeeklyGoal()`
  - `Future<void> setWeeklyGoal(WeeklyGoal goal)`
  - `Future<Set<BadgeId>> getSeenBadges()`
  - `Future<void> markBadgeSeen(BadgeId id)`
- `LocalGamificationRepository(SharedPreferences prefs)` — lê os check-ins da mesma chave `'local_checkins'` usada por `LocalHabitRepository`; grava meta em `'gamification_weekly_goal'` e vistos em `'gamification_seen_badges'`.

Nota de acoplamento: a chave `'local_checkins'` é compartilhada com `LocalHabitRepository`. Documentar no arquivo.

- [ ] **Step 1: Write the failing test**

```dart
// test/gamification/gamification_repository_local_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:habit_ai/core/time/date_only.dart';
import 'package:habit_ai/data/repositories/gamification_repository_local.dart';
import 'package:habit_ai/domain/gamification/models.dart';

void main() {
  final today = DateTime(2026, 7, 4);
  String key(int daysAgo) => toDateKey(today.subtract(Duration(days: daysAgo)));

  Future<LocalGamificationRepository> build(List<Map<String, Object>> checkins) async {
    SharedPreferences.setMockInitialValues({
      'local_checkins': jsonEncode(checkins),
    });
    final prefs = await SharedPreferences.getInstance();
    return LocalGamificationRepository(prefs);
  }

  test('doneDateKeys collapses habits into active days', () async {
    final repo = await build([
      {'habitId': 'a', 'dateKey': key(0), 'status': 1},
      {'habitId': 'b', 'dateKey': key(0), 'status': 2},
      {'habitId': 'a', 'dateKey': key(1), 'status': 1},
      {'habitId': 'a', 'dateKey': key(2), 'status': 0}, // não conta
    ]);
    final days = await repo.doneDateKeys();
    expect(days, {key(0), key(1)});
  });

  test('totalCheckins counts only done status', () async {
    final repo = await build([
      {'habitId': 'a', 'dateKey': key(0), 'status': 1},
      {'habitId': 'b', 'dateKey': key(0), 'status': 2},
      {'habitId': 'a', 'dateKey': key(1), 'status': 0},
    ]);
    expect(await repo.totalCheckins(), 2);
  });

  test('weekly goal defaults then persists', () async {
    final repo = await build([]);
    expect((await repo.getWeeklyGoal()).targetDays, WeeklyGoal.defaultGoal.targetDays);
    await repo.setWeeklyGoal(const WeeklyGoal(targetDays: 3));
    expect((await repo.getWeeklyGoal()).targetDays, 3);
  });

  test('seen badges persist', () async {
    final repo = await build([]);
    expect(await repo.getSeenBadges(), isEmpty);
    await repo.markBadgeSeen(BadgeId.streak7);
    expect(await repo.getSeenBadges(), {BadgeId.streak7});
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/gamification/gamification_repository_local_test.dart`
Expected: FAIL — arquivos não existem.

- [ ] **Step 3: Implement a interface**

```dart
// lib/domain/gamification/gamification_repository.dart
import 'models.dart';

abstract class GamificationRepository {
  Future<Set<String>> doneDateKeys({int windowDays = 365});
  Future<int> totalCheckins();
  Future<WeeklyGoal> getWeeklyGoal();
  Future<void> setWeeklyGoal(WeeklyGoal goal);
  Future<Set<BadgeId>> getSeenBadges();
  Future<void> markBadgeSeen(BadgeId id);
}
```

- [ ] **Step 4: Implement a impl local**

```dart
// lib/data/repositories/gamification_repository_local.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/time/date_only.dart';
import '../../domain/gamification/gamification_repository.dart';
import '../../domain/gamification/models.dart';

/// Impl local. Lê os check-ins da MESMA chave `local_checkins` gravada por
/// LocalHabitRepository (fonte de verdade dos check-ins) e persiste apenas o
/// não-derivável: meta semanal e badges vistos.
class LocalGamificationRepository implements GamificationRepository {
  LocalGamificationRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _checkinsKey = 'local_checkins';
  static const String _weeklyGoalKey = 'gamification_weekly_goal';
  static const String _seenBadgesKey = 'gamification_seen_badges';

  List<Map<String, dynamic>> _readCheckins() {
    final raw = _prefs.getString(_checkinsKey);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  bool _isDone(int status) => status == 1 || status == 2;

  @override
  Future<Set<String>> doneDateKeys({int windowDays = 365}) async {
    final cutoff = toDateKey(
      todayLocal().subtract(Duration(days: windowDays - 1)),
    );
    final out = <String>{};
    for (final c in _readCheckins()) {
      final dateKey = c['dateKey'] as String;
      if (_isDone(c['status'] as int) && dateKey.compareTo(cutoff) >= 0) {
        out.add(dateKey);
      }
    }
    return out;
  }

  @override
  Future<int> totalCheckins() async {
    var count = 0;
    for (final c in _readCheckins()) {
      if (_isDone(c['status'] as int)) count++;
    }
    return count;
  }

  @override
  Future<WeeklyGoal> getWeeklyGoal() async {
    final v = _prefs.getInt(_weeklyGoalKey);
    if (v == null) return WeeklyGoal.defaultGoal;
    return WeeklyGoal(targetDays: v);
  }

  @override
  Future<void> setWeeklyGoal(WeeklyGoal goal) async {
    await _prefs.setInt(_weeklyGoalKey, goal.targetDays);
  }

  @override
  Future<Set<BadgeId>> getSeenBadges() async {
    final list = _prefs.getStringList(_seenBadgesKey) ?? const [];
    return list
        .map((name) => BadgeId.values.asNameMap()[name])
        .whereType<BadgeId>()
        .toSet();
  }

  @override
  Future<void> markBadgeSeen(BadgeId id) async {
    final list = (_prefs.getStringList(_seenBadgesKey) ?? const []).toSet()
      ..add(id.name);
    await _prefs.setStringList(_seenBadgesKey, list.toList());
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/gamification/gamification_repository_local_test.dart`
Expected: PASS.

- [ ] **Step 6: Checkpoint (stage; usuário commita)**

Run: `git add lib/domain/gamification/gamification_repository.dart lib/data/repositories/gamification_repository_local.dart test/gamification/gamification_repository_local_test.dart`

---

### Task 7: Provider do snapshot de gamificação

**Files:**
- Modify: `lib/app/providers.dart`
- Create: `lib/features/gamification/gamification_controller.dart`
- Test: `test/gamification/gamification_controller_test.dart`

**Interfaces:**
- Consumes: `GamificationRepository` (Task 6), regras (Tasks 3-5), `sharedPreferencesProvider` e `homeControllerProvider` existentes.
- Produces:
  - Em `providers.dart`: `final gamificationRepositoryProvider = Provider<GamificationRepository>(...)`.
  - Em `gamification_controller.dart`: `final gamificationControllerProvider = FutureProvider.autoDispose<GamificationSnapshot>(...)` — recomputa quando `homeControllerProvider` muda.
  - `GamificationSnapshot buildSnapshot({required Set<String> doneDateKeys, required int totalCheckins, required WeeklyGoal goal, required DateTime today})` — função pura de montagem (facilita teste).

- [ ] **Step 1: Write the failing test**

```dart
// test/gamification/gamification_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_ai/core/time/date_only.dart';
import 'package:habit_ai/domain/gamification/models.dart';
import 'package:habit_ai/features/gamification/gamification_controller.dart';

void main() {
  final today = DateTime(2026, 7, 4);
  String key(int daysAgo) => toDateKey(today.subtract(Duration(days: daysAgo)));

  test('buildSnapshot aggregates rules', () {
    final snap = buildSnapshot(
      doneDateKeys: {key(0), key(1), key(2)},
      totalCheckins: 3,
      goal: const WeeklyGoal(targetDays: 3),
      today: today,
    );
    expect(snap.totalXp, 30);
    expect(snap.level.level, 1);
    expect(snap.streak.current, 3);
    expect(snap.weekly.done, 3);
    expect(snap.weekly.met, isTrue);
    expect(snap.unlockedBadges, contains(BadgeId.firstCheckin));
    expect(snap.unlockedBadges, contains(BadgeId.weeklyGoalMet));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/gamification/gamification_controller_test.dart`
Expected: FAIL — `buildSnapshot` não definido.

- [ ] **Step 3: Implement o provider do repo**

Em `lib/app/providers.dart`, adicionar imports e provider (perto de `habitRepositoryProvider`):

```dart
import '../data/repositories/gamification_repository_local.dart';
import '../domain/gamification/gamification_repository.dart';
```

```dart
final gamificationRepositoryProvider = Provider<GamificationRepository>((ref) {
  return LocalGamificationRepository(ref.watch(sharedPreferencesProvider));
});
```

- [ ] **Step 4: Implement o controller**

```dart
// lib/features/gamification/gamification_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/time/date_only.dart';
import '../../domain/gamification/gamification_rules.dart';
import '../../domain/gamification/models.dart';
import '../home/home_controller.dart';

GamificationSnapshot buildSnapshot({
  required Set<String> doneDateKeys,
  required int totalCheckins,
  required WeeklyGoal goal,
  required DateTime today,
}) {
  final streak = streakFrom(doneDateKeys, today);
  final weekly = weeklyProgressFor(doneDateKeys, goal, today);
  final xp = totalXpFor(totalCheckins);
  return GamificationSnapshot(
    totalXp: xp,
    level: levelInfoFor(xp),
    streak: streak,
    weekly: weekly,
    unlockedBadges: unlockedBadgesFor(
      checkinCount: totalCheckins,
      streak: streak,
      weeklyMet: weekly.met,
    ),
  );
}

final gamificationControllerProvider =
    FutureProvider.autoDispose<GamificationSnapshot>((ref) async {
  // Recomputa quando os check-ins mudam.
  ref.watch(homeControllerProvider);
  final repo = ref.watch(gamificationRepositoryProvider);
  final done = await repo.doneDateKeys();
  final total = await repo.totalCheckins();
  final goal = await repo.getWeeklyGoal();
  return buildSnapshot(
    doneDateKeys: done,
    totalCheckins: total,
    goal: goal,
    today: todayLocal(),
  );
});
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/gamification/gamification_controller_test.dart`
Expected: PASS.

- [ ] **Step 6: Checkpoint (stage; usuário commita)**

Run: `git add lib/app/providers.dart lib/features/gamification/gamification_controller.dart test/gamification/gamification_controller_test.dart`

---

### Task 8: Widget de resumo (nível/XP/streak/meta) em `shared/ui`

**Files:**
- Create: `lib/shared/ui/widgets/gamification_summary_card.dart`
- Test: `test/gamification/gamification_summary_card_test.dart`

**Interfaces:**
- Consumes: `GamificationSnapshot` (Task 2).
- Produces: `GamificationSummaryCard({required GamificationSnapshot snapshot})` — `StatelessWidget` puro (recebe snapshot por parâmetro; não lê providers, pra ser testável isolado).

Conteúdo: `Nível X`, barra de progresso (`snapshot.level.xpIntoLevel / snapshot.level.xpForNextLevel`), `🔥 {streak.current}`, `Meta semanal: {weekly.done}/{weekly.target}`.

- [ ] **Step 1: Write the failing test**

```dart
// test/gamification/gamification_summary_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_ai/domain/gamification/models.dart';
import 'package:habit_ai/shared/ui/widgets/gamification_summary_card.dart';

void main() {
  testWidgets('renders level, streak and weekly goal', (tester) async {
    const snapshot = GamificationSnapshot(
      totalXp: 130,
      level: LevelInfo(level: 2, xpIntoLevel: 30, xpForNextLevel: 200),
      streak: StreakInfo(current: 4, longest: 9),
      unlockedBadges: {BadgeId.firstCheckin},
      weekly: WeeklyProgress(done: 3, target: 5),
    );

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: GamificationSummaryCard(snapshot: snapshot)),
    ));

    expect(find.textContaining('Nível 2'), findsOneWidget);
    expect(find.textContaining('4'), findsWidgets); // streak
    expect(find.textContaining('3/5'), findsOneWidget); // meta
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/gamification/gamification_summary_card_test.dart`
Expected: FAIL — arquivo não existe.

- [ ] **Step 3: Implement**

```dart
// lib/shared/ui/widgets/gamification_summary_card.dart
import 'package:flutter/material.dart';

import '../../../domain/gamification/models.dart';

class GamificationSummaryCard extends StatelessWidget {
  final GamificationSnapshot snapshot;
  const GamificationSummaryCard({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final level = snapshot.level;
    final progress = level.xpForNextLevel == 0
        ? 0.0
        : level.xpIntoLevel / level.xpForNextLevel;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nível ${level.level}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('🔥 ${snapshot.streak.current}'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 4),
            Text('${level.xpIntoLevel} / ${level.xpForNextLevel} XP'),
            const SizedBox(height: 8),
            Text(
              'Meta semanal: ${snapshot.weekly.done}/${snapshot.weekly.target}',
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/gamification/gamification_summary_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Checkpoint (stage; usuário commita)**

Run: `git add lib/shared/ui/widgets/gamification_summary_card.dart test/gamification/gamification_summary_card_test.dart`

---

### Task 9: Plugar o card na Home (com gate da feature flag)

**Files:**
- Modify: `lib/features/home/home_page.dart`
- Test: `test/gamification/home_shows_gamification_test.dart`

**Interfaces:**
- Consumes: `gamificationControllerProvider` (Task 7), `GamificationSummaryCard` (Task 8), `FeatureFlags` (Task 1).
- Produces: Home renderiza o `GamificationSummaryCard` acima da lista quando `FeatureFlags().gamification` é true e o snapshot resolveu.

Nota: o `body` da Home hoje é `HomeHabitsV2`. Envolver num `Column` com o card no topo. Usar `ref.watch(gamificationControllerProvider).maybeWhen(data: ..., orElse: SizedBox.shrink)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/gamification/home_shows_gamification_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:habit_ai/app/providers.dart';
import 'package:habit_ai/features/home/home_controller.dart';
import 'package:habit_ai/features/home/home_page.dart';
import 'package:habit_ai/shared/ui/widgets/gamification_summary_card.dart';

import '../test_app.dart';

void main() {
  testWidgets('Home shows gamification summary card', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final homeState = HomeState(
      habits: const [],
      todayStatusByHabitId: const {},
      rhythm14DaysByHabitId: const {},
      checkinsByHabitId: const {},
    );

    await tester.pumpWidget(buildSmokeTestApp(homeState: homeState));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(GamificationSummaryCard), findsOneWidget);
  });
}
```

Nota: `buildSmokeTestApp` (em `test/test_app.dart`) já sobrescreve `homeControllerProvider`. Como o `gamificationControllerProvider` observa o `homeControllerProvider` e usa `gamificationRepositoryProvider` (que lê `sharedPreferencesProvider`), este teste precisa que `sharedPreferencesProvider` esteja disponível. **Ajustar `buildSmokeTestApp`** para sobrescrever `sharedPreferencesProvider` com uma instância mock. Ver Step 3.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/gamification/home_shows_gamification_test.dart`
Expected: FAIL — card não encontrado (e possível erro de `sharedPreferencesProvider` não sobrescrito).

- [ ] **Step 3: Ajustar `buildSmokeTestApp` para prover SharedPreferences**

Em `test/test_app.dart`, tornar `buildSmokeTestApp` assíncrono não é desejável; em vez disso, aceitar um `SharedPreferences` opcional e sobrescrever o provider quando fornecido. Editar a assinatura e os overrides:

```dart
// no topo de test_app.dart:
import 'package:shared_preferences/shared_preferences.dart';

// substituir a função buildSmokeTestApp por:
Widget buildSmokeTestApp({
  required HomeState homeState,
  Widget home = const HomePage(),
  SharedPreferences? prefs,
}) {
  final HabitRepository repo = FakeHabitRepository(
    habits: homeState.habits,
    checkinsByHabitId: homeState.checkinsByHabitId,
  );

  const String uid = 'test-user';

  return ProviderScope(
    overrides: [
      authUserIdProvider.overrideWith((ref) => uid),
      authUserEmailProvider.overrideWith((ref) => 'test@local'),
      if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
      homeControllerProvider.overrideWith((ref) {
        return TestHomeController(repo, uid, homeState);
      }),
    ],
    child: MaterialApp(home: home),
  );
}
```

E o teste passa a obter e injetar o `prefs`:

```dart
// no teste, trocar o corpo por:
SharedPreferences.setMockInitialValues(<String, Object>{});
final prefs = await SharedPreferences.getInstance();
// ...
await tester.pumpWidget(buildSmokeTestApp(homeState: homeState, prefs: prefs));
```

- [ ] **Step 4: Implement o gate na Home**

Em `lib/features/home/home_page.dart`, adicionar imports:

```dart
import '../../config/feature_flags.dart';
import '../../shared/ui/widgets/gamification_summary_card.dart';
import '../gamification/gamification_controller.dart';
```

Trocar o `body: HomeHabitsV2(...)` por uma coluna com o card no topo:

```dart
body: Column(
  children: [
    if (const FeatureFlags().gamification)
      ref.watch(gamificationControllerProvider).maybeWhen(
            data: (snap) => Padding(
              padding: const EdgeInsets.all(12),
              child: GamificationSummaryCard(snapshot: snap),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
    Expanded(
      child: HomeHabitsV2(
        onCreateHabit: () => _showCreateHabitSheet(context, ref),
      ),
    ),
  ],
),
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/gamification/home_shows_gamification_test.dart`
Expected: PASS.

- [ ] **Step 6: Rodar a suíte inteira + analyze**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 7: Checkpoint (stage; usuário commita)**

Run: `git add lib/features/home/home_page.dart test/test_app.dart test/gamification/home_shows_gamification_test.dart`

---

## Notas finais

- `Badge` (título/descrição por `BadgeId`) e uma tela dedicada de badges ficam para uma iteração seguinte — a v1 já expõe `unlockedBadges` no snapshot. YAGNI para a UI completa de badges agora.
- Edição da meta semanal pelo usuário (UI para `setWeeklyGoal`) também fica para iteração seguinte; a v1 usa `WeeklyGoal.defaultGoal` (5) e a infra de persistência já existe.
- Peso de XP por dificuldade: futuro (v1 é `count * 10`).
