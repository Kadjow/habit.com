import 'dart:math';

import '../decision/models/decision_input.dart';
import '../decision/models/decision_output.dart';

class DecisionEngine {
  DecisionOutput evaluate(DecisionInput input) {
    int? suggestedDifficulty;
    bool suggestMinimumVersion = false;
    int? changePromptTimeByMinutes;
    String note = 'Segue firme. Pequeno hoje, consistente sempre.';

    if (input.lastFailureCount7Days >= 2) {
      suggestedDifficulty = max(1, input.habit.difficulty - 1);
      suggestMinimumVersion = true;
      note = 'Vamos reduzir o esforco e manter o ritmo.';
    }

    if (input.ignoredPromptsCount3Days >= 3) {
      changePromptTimeByMinutes = 60;
      if (suggestedDifficulty == null) {
        note = 'Vou testar um horario mais tarde pra encaixar melhor.';
      }
    }

    return DecisionOutput(
      suggestedDifficulty: suggestedDifficulty,
      suggestMinimumVersion: suggestMinimumVersion,
      changePromptTimeByMinutes: changePromptTimeByMinutes,
      note: note,
    );
  }
}
