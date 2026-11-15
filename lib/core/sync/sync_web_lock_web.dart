import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

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
      final nav = html.window.navigator;
      if (js_util.hasProperty(nav, 'locks')) {
        final locks = js_util.getProperty(nav, 'locks');
        final completer = Completer<T?>();
        final options = js_util.newObject();
        js_util.setProperty(options, 'ifAvailable', true);

        final callback = js_util.allowInterop((lock) async {
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
        });

        js_util.callMethod(locks, 'request', [lockName, options, callback]);
        return await completer.future;
      }
    } catch (_) {
      // Fallback
    }
    return action();
  }
}
