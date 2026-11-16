/// Platform-independent stub for tab leader election lock.
/// On native and VM test environments, executes the action directly.
class SyncWebLock {
  const SyncWebLock._();

  static Future<T?> runWithLock<T>(
    String lockName,
    Future<T> Function() action,
  ) async {
    return action();
  }
}
