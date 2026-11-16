import 'dart:async';
import 'dart:js' as js;

/// Web implementation of cross-tab leader election using Web Locks API.
///
/// Prevents concurrent tabs from pushing overlapping batches simultaneously.
/// If Web Locks is unavailable or rejected by the browser sandbox, executes
/// directly as merges are fully idempotent.
class SyncWebLock {
  const SyncWebLock._();

  static Future<T?> runWithLock<T>(
    String lockName,
    Future<T> Function() action,
  ) async {
    try {
      if (js.context.hasProperty('navigator')) {
        final nav = js.context['navigator'];
        if (nav != null && nav.hasProperty('locks')) {
          final locks = nav['locks'];
          final completer = Completer<T?>();
          final options = js.JsObject.jsify({'ifAvailable': true});

          void callback(dynamic lock) async {
            if (lock == null) {
              // Another tab is actively holding the sync lock
              completer.complete(null);
              return;
            }
            try {
              final res = await action();
              completer.complete(res);
            } catch (e, st) {
              completer.completeError(e, st);
            }
          }

          locks.callMethod('request', [lockName, options, callback]);
          return await completer.future;
        }
      }
    } catch (_) {
      // Fallback
    }
    return action();
  }
}
