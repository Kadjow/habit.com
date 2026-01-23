class DecisionOutput {
  final int? suggestedDifficulty;
  final bool suggestMinimumVersion;
  final int? changePromptTimeByMinutes;
  final String note;

  const DecisionOutput({
    required this.suggestedDifficulty,
    required this.suggestMinimumVersion,
    required this.changePromptTimeByMinutes,
    required this.note,
  });
}
