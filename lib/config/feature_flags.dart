class FeatureFlags {
  final bool coachingLLM;
  final bool adaptivePrompts;
  final bool autoWeeklyPlan;
  final bool syncEnabled;

  const FeatureFlags({
    this.coachingLLM = false,
    this.adaptivePrompts = true,
    this.autoWeeklyPlan = false,
    this.syncEnabled = false,
  });
}
