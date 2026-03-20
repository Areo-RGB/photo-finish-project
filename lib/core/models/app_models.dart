class LastRunResult {
  const LastRunResult({
    required this.startedAtEpochMs,
    required this.splitMicros,
  });

  final int startedAtEpochMs;
  final List<int> splitMicros;

  Map<String, dynamic> toJson() {
    return {'startedAtEpochMs': startedAtEpochMs, 'splitMicros': splitMicros};
  }

  static LastRunResult? fromJson(dynamic source) {
    if (source is! Map<String, dynamic>) {
      return null;
    }
    final startedAt = source['startedAtEpochMs'];
    final splits = source['splitMicros'];
    if (startedAt is! int || splits is! List) {
      return null;
    }
    final parsedSplits = <int>[];
    for (final value in splits) {
      if (value is int) {
        parsedSplits.add(value);
      }
    }
    return LastRunResult(
      startedAtEpochMs: startedAt,
      splitMicros: parsedSplits,
    );
  }
}
