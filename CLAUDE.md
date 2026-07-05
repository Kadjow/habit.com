# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Plugins ativos neste projeto

- **Superpowers**: sempre disponível. Antes de qualquer trabalho criativo (features, componentes, mudança de comportamento), invocar a skill `superpowers:brainstorming`. Para bugs/falhas, `superpowers:systematic-debugging` antes de propor fix. Seguir as regras de skills: invocar a skill relevante ANTES de responder.
- **Caveman Ultra**: modo de comunicação **sempre ativo**. Respostas curtas, diretas, fragmentos, sem filler. Exceções (escrever normal): código, commits, PRs, avisos de segurança, confirmações destrutivas, documentação longa. Desativar apenas com `stop caveman` ou `normal mode`.

## Comandos

Projeto Flutter (Dart SDK `^3.10.0`). Rodar da raiz do repo.

```bash
flutter pub get                 # instalar dependências
flutter run                     # rodar app (device/emulador)
flutter analyze                 # lint estático (flutter_lints)
flutter test                    # rodar todos os testes
flutter test test/home_controller_debounce_test.dart   # rodar um arquivo de teste
flutter test --name "<nome>"    # rodar um teste por nome
flutter build apk               # build Android
```

`deprecated_member_use` está silenciado no `analysis_options.yaml`.

## Arquitetura

App de tracking de hábitos. Camadas: `domain` (contratos/modelos) → `data` (impl) → `features` (UI + controllers), com `app` fazendo o wiring via Riverpod.

**State management**: `flutter_riverpod`. Providers globais em `lib/app/providers.dart`. Wiring do app em `lib/app/app.dart` (`MaterialApp` → `AuthGate`). O `lib/app/router.dart` existe mas hoje só resolve `/` → `HomePage`; navegação real usa `MaterialPageRoute` direto.

**Auth (local, sem backend)**: `AuthController` (`StateNotifier<LocalUser?>` em `providers.dart`) com login fixo `admin` / `admin` e `userId` fixo `local-admin`. `AuthGate` observa `authControllerProvider` e decide `AuthPage` vs `HomePage`. `authUserIdProvider` / `userIdProvider` / `authUserEmailProvider` derivam do `LocalUser`. **Importante**: `homeControllerProvider` faz `ref.watch(userIdProvider)`, então login/logout recria o controller e reseta o estado. Não há Supabase/rede no projeto.

**Persistência (local, SharedPreferences)**: interface `domain/repositories/habit_repository.dart`, impl `data/repositories/habit_repository_local.dart`. Estado em duas chaves JSON (`local_habits`, `local_checkins`); a instância de `SharedPreferences` é obtida no `main.dart` e injetada via `sharedPreferencesProvider.overrideWithValue`. Como a classe usa `implements HabitRepository`, **todo** método da interface precisa de override explícito (inclusive os que têm corpo default). Check-in identificado por `(habitId, dateKey)`; `status` int: `0` = não feito (remove o registro), `1`/`2` = feito. Datas usam `dateKey` string `YYYY-MM-DD` via `core/time/date_only.dart` (`toDateKey`/`fromDateKey`/`todayLocal`) — nunca comparar `DateTime` cru.

**HomeController** (`features/home/home_controller.dart`) — coração do app, `StateNotifier<AsyncValue<HomeState>>`:
- `load()` busca hábitos + últimos 14 dias de checkins em batch (`lastCheckinsForHabits`), e agrega métricas (status de hoje, ritmo 14d, mapa por hábito) num isolate via `compute()` (fallback síncrono na web).
- Updates são **otimistas** com rollback: `setCheckinForDate` atualiza state na hora, chama repo, e reverte state + `_checkedPairs7d` se falhar.
- **Nunca chamar `load()` dentro de `load()`** — há um `assert(!_inLoad)` que quebra em debug/test. Para refresh após ação, usar `scheduleSilentRefresh()` (debounce 600ms).
- `_checkedPairs7d` é cache in-memory de pares `habitId|dateKey` feitos nos últimos 7 dias, usado por `isChecked7d`/`doneCount7d`.

**DecisionEngine** (`lib/decision/`): lógica pura sem estado. `evaluate(DecisionInput)` → `DecisionOutput` com sugestões (reduzir dificuldade, versão mínima, mudar horário do prompt) baseadas em falhas/prompts ignorados. Não tocado pela UI ainda; base pra coaching adaptativo.

**Feature flags** (`lib/config/feature_flags.dart`): `coachingLLM`, `adaptivePrompts`, `autoWeeklyPlan`, `syncEnabled` — const, sem infra de toggle runtime ainda.

**UI**: dois conjuntos de widgets compartilhados coexistem — `lib/ui/widgets/` (mais antigo) e `lib/shared/ui/` (tokens + `app_card`). Tema em `lib/ui/theme/app_theme.dart`.

## Testes

`test/test_app.dart` é a base dos testes: `FakeHabitRepository` (impl in-memory da interface, sem rede) + `TestHomeController` (nasce com state pronto, `load()` é no-op pra evitar timers/debounce) + `buildSmokeTestApp()` que faz override dos providers de auth e do `homeControllerProvider`. Widget tests devem passar por esse helper para não encostar no Supabase real.
