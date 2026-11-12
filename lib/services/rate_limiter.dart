class FailureRateLimiter {
  FailureRateLimiter({
    this.baseDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 30),
    this.graceFailures = 2,
  });

  final Duration baseDelay;
  final Duration maxDelay;
  final int graceFailures;

  final Map<String, _FailureState> _states = {};
  static const int _maxTrackedClients = 4096;

  bool shouldReject(String clientKey) {
    final state = _states[clientKey];
    if (state == null || state.failures <= graceFailures) return false;
    final elapsed = DateTime.now().difference(state.lastFailureAt);
    return elapsed < delayFor(state.failures);
  }

  void registerFailure(String clientKey) {
    _pruneIfNeeded();
    final state = _states.putIfAbsent(clientKey, _FailureState.new);
    if (state.failures < 64) state.failures++;
    state.lastFailureAt = DateTime.now();
  }

  void registerSuccess(String clientKey) {
    _states.remove(clientKey);
  }

  Duration delayFor(int failures) {
    if (failures <= graceFailures) return Duration.zero;
    final shift = (failures - graceFailures - 1).clamp(0, 24);
    final milliseconds = baseDelay.inMilliseconds * (1 << shift);
    if (milliseconds > maxDelay.inMilliseconds) return maxDelay;
    return Duration(milliseconds: milliseconds);
  }

  void _pruneIfNeeded() {
    if (_states.length < _maxTrackedClients) return;
    final cutoff = DateTime.now().subtract(maxDelay * 2);
    _states.removeWhere((_, state) => state.lastFailureAt.isBefore(cutoff));
  }
}

class _FailureState {
  int failures = 0;
  DateTime lastFailureAt = DateTime.now();
}
