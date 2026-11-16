import '../models/reading_session.dart';

/// Local persistence contract required by the cloud sync coordinator.
///
/// Both browser storage and native Drift storage implement this interface so
/// the same account-scoped sync engine can run on Web and Android.
abstract class CloudSyncSessionRepository {
  /// Includes completed sessions and tombstones; active timers remain local.
  List<ReadingSession> allForSync();

  /// Applies remote rows using the same last-write-wins/tombstone tie-break.
  Future<void> applyRemote(List<ReadingSession> remoteRows);
}
