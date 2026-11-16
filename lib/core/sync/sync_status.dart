import 'package:flutter/material.dart';

/// User-visible sync state categories.
enum SyncStatus {
  localOnly,
  syncing,
  synced,
  offline,
  needsAttention,
}

/// Comprehensive, observable snapshot of sync engine status.
class SyncState {
  final SyncStatus status;
  final String? message;
  final DateTime? lastSyncedAt;
  final int quarantinedCount;
  final bool hasStorageCapError;

  const SyncState({
    required this.status,
    this.message,
    this.lastSyncedAt,
    this.quarantinedCount = 0,
    this.hasStorageCapError = false,
  });

  const SyncState.localOnly()
      : this(
          status: SyncStatus.localOnly,
          message: 'Saved locally on this device',
        );

  const SyncState.syncing({String? detail})
      : this(
          status: SyncStatus.syncing,
          message: detail ?? 'Syncing…',
        );

  SyncState.synced({DateTime? timestamp})
      : this(
          status: SyncStatus.synced,
          message: 'Synced',
          lastSyncedAt: timestamp ?? DateTime.now(),
        );

  const SyncState.offline({String? reason})
      : this(
          status: SyncStatus.offline,
          message: reason ?? 'Offline — changes saved on this device',
        );

  const SyncState.needsAttention({
    required String message,
    int quarantinedCount = 0,
    bool hasStorageCapError = false,
  }) : this(
          status: SyncStatus.needsAttention,
          message: message,
          quarantinedCount: quarantinedCount,
          hasStorageCapError: hasStorageCapError,
        );

  bool get isSyncing => status == SyncStatus.syncing;
  bool get isSynced => status == SyncStatus.synced;
  bool get isOffline => status == SyncStatus.offline;
  bool get isLocalOnly => status == SyncStatus.localOnly;
  bool get needsAttention => status == SyncStatus.needsAttention;

  String get label {
    switch (status) {
      case SyncStatus.localOnly:
        return 'Local only';
      case SyncStatus.syncing:
        return 'Syncing…';
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.offline:
        return 'Offline';
      case SyncStatus.needsAttention:
        return 'Sync needs attention';
    }
  }

  Color get statusColor {
    switch (status) {
      case SyncStatus.localOnly:
        return const Color(0xFF71717A); // Zinc neutral
      case SyncStatus.syncing:
        return const Color(0xFF38BDF8); // Sky blue
      case SyncStatus.synced:
        return const Color(0xFF34D399); // Emerald green
      case SyncStatus.offline:
        return const Color(0xFFFBBF24); // Amber
      case SyncStatus.needsAttention:
        return const Color(0xFFF87171); // Rose / Red
    }
  }
}
