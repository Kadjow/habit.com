# Design — Gamificação local + Roadmap para vertente de Planos

Data: 2026-07-04
Status: rascunho (aguardando review do usuário)

## 1. Contexto e objetivo

O `habit_ai` hoje é um MVP cru: hábitos + check-ins diários, home com grid e "ritmo 14d", auth local (`admin`/`admin`), persistência em `SharedPreferences` (só no device, sem sync). `DecisionEngine` e `FeatureFlags` existem mas não estão plugados.

Objetivo de produto: tornar o app **gamificado** e, no médio prazo, abrir a vertente de **planos (assinatura paga, free vs premium)**. A assinatura paga só faz sentido depois de: (a) gamificação que valha a pena, (b) contas reais + backend. Portanto o trabalho é faseado.

## 2. Roadmap faseado (levantamento)

A ordem é obrigatória — social e pago dependem de backend.

- **Fase 0 — Fundação.** Modelos de domínio adequados, unificar os dois conjuntos de widgets (`lib/ui/` vs `lib/shared/ui/`), decidir destino de `DecisionEngine`/`FeatureFlags` (usar ou remover), cobertura de testes. Escopo mínimo necessário está dobrado dentro deste spec (Fase 1); a limpeza ampla de UI é uma trilha paralela, fora deste plano.
- **Fase 1 — Gamificação local (offline).** Streaks, XP, níveis, badges, metas semanais. Tudo derivado do histórico de check-ins + `SharedPreferences`. Zero backend. **É o foco deste spec.**
- **Fase 2 — Contas + backend + sync.** Reintroduzir backend (Supabase ou outro), conta real, login, sync entre aparelhos. Pré-requisito de social e pago.
- **Fase 3 — Social / ranking / ligas.** Depende da Fase 2.
- **Fase 4 — Assinatura paga (free vs premium).** Paywall, entitlement, billing (App Store/Play/Stripe). Trava mecânicas premium. Depende da Fase 2 e de gamificação madura.

Este documento detalha **Fase 0 (mínima) + Fase 1**. Fases 2–4 ficam como visão; cada uma terá seu próprio spec quando chegar a vez.

## 3. Princípio central da Fase 1: derivar, não duplicar

Streak, XP, nível e badges são **funções puras do histórico de check-ins**, que já é gravado. Não criamos nova fonte de verdade para eles — derivamos sob demanda.

Só persistimos o que **não** é derivável:
- **Meta semanal** escolhida pelo usuário (alvo de dias/semana).
- **Flags de "visto"** para badges (pra disparar animação de desbloqueio só uma vez).

Isso mantém a Fase 1 leve e sem risco de estado inconsistente.

### Consequência técnica
Streak "mais longo" e XP total precisam do histórico **completo**, não só 14 dias. Hoje `HomeController.load()` busca 14d. Adicionamos um método de repositório para todo o histórico (ou uma janela ampla configurável) usado só pelo cálculo de gamificação.

## 4. Arquitetura (Fase 1)

Camadas seguem o padrão atual (`domain` → `data` → `features`, wiring via Riverpod).

### 4.1 `lib/domain/gamification/` — regras puras (sem estado, sem I/O)
- `gamification_rules.dart` — funções puras:
  - `int xpForCheckin(int status, int difficulty)` — XP por check-in (status 1/2 e dificuldade viram pontos).
  - `int levelForXp(int xp)` / `LevelInfo levelInfo(int xp)` — nível + progresso pro próximo.
  - `StreakInfo streakFromDates(Set<String> doneDateKeys, DateTime today)` — streak atual e mais longo a partir das datas feitas.
  - `Set<BadgeId> unlockedBadges(GamificationSnapshot snap)` — badges desbloqueados dado o estado agregado.
  - `WeeklyProgress weeklyProgress(Set<String> doneDateKeys, WeeklyGoal goal, DateTime today)`.
- Modelos de valor: `LevelInfo`, `StreakInfo`, `Badge`/`BadgeId`, `WeeklyGoal`, `WeeklyProgress`, `GamificationSnapshot` (agregado imutável que a UI consome).

Tudo aqui é testável isoladamente sem Flutter/Riverpod.

### 4.2 `lib/data/` — persistência do que não é derivável
- Estender `HabitRepository` (ou criar `GamificationRepository` separado — ver Decisão D2) com:
  - `Future<List<CheckIn>> allCheckins(...)` ou janela ampla, para o cálculo global.
  - `Future<WeeklyGoal?> getWeeklyGoal()` / `setWeeklyGoal(...)`.
  - `Future<Set<String>> getSeenBadges()` / `markBadgeSeen(...)`.
- Impl local em `SharedPreferences`, chaves novas: `gamification_weekly_goal`, `gamification_seen_badges`.

### 4.3 `lib/features/gamification/` — controller + UI
- `gamification_controller.dart` — provider que combina o histórico (repo) + regras puras → `GamificationSnapshot`. Reage às mudanças do `HomeController` (novo check-in recomputa).
- Widgets: barra de nível/XP, "chama" de streak, tela/grade de badges, card de meta semanal com progresso. **Usar um único sistema de widgets** (ver Decisão D1).

## 5. Fluxo de dados

1. Usuário faz check-in → `HomeController.setCheckinForDate` (já existe, otimista).
2. `gamificationController` observa o estado de check-ins → recomputa `GamificationSnapshot` via regras puras.
3. UI reflete XP/nível/streak/meta. Se um badge novo entra em `unlockedBadges` e não está em `seenBadges` → dispara animação e marca como visto.

Nada de novo I/O no caminho crítico do check-in; a recomputação é em memória (funções puras).

## 6. Tratamento de erros

- Regras puras não fazem I/O → não lançam por rede. Entrada inválida (ex: `dateKey` malformado) é responsabilidade do dado já validado na camada atual.
- Leitura de `SharedPreferences` ausente → defaults seguros (`WeeklyGoal` padrão, `seenBadges` vazio).
- Falha ao gravar meta/seen-badge → best-effort, não derruba UI (segue o padrão otimista atual).

## 7. Testes

- **Unitário pesado nas regras puras** (`gamification_rules_test.dart`): streaks com buracos, virada de dia, mais-longo vs atual, XP por dificuldade, thresholds de nível, cada badge, progresso semanal em bordas.
- **Widget smoke** para as novas telas (padrão do `test/test_app.dart`, sem rede).
- Manter suíte atual verde.

## 8. Decisões (fechadas — aprovadas em 2026-07-04)

- **D1 — Sistema de widgets.** `lib/shared/ui/` é o sistema **canônico**. Código novo de gamificação vai pra lá. UI antiga (`lib/ui/widgets/`) não é refatorada agora.
- **D2 — Repositório.** `GamificationRepository` **separado** de `HabitRepository`. Responsabilidade distinta.
- **D3 — XP: global.** XP/nível é do usuário (global, "nível do jogador"), não por hábito.
- **D4 — Feature flag.** `FeatureFlags.gamification` (nova) atua como gate on/off da gamificação. `DecisionEngine` permanece parado por ora (fora de escopo).
- **D5 — Escopo do histórico.** Cálculo global usa janela de **365 dias** (performance no `SharedPreferences`).

## 9. Fora de escopo (deste spec)

- Contas reais, backend, sync (Fase 2).
- Social, ranking, ligas (Fase 3).
- Paywall, billing, entitlement (Fase 4).
- Refatoração ampla da UI antiga não tocada pela gamificação.
