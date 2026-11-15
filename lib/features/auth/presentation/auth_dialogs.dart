import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/account/account_scope.dart';
import '../../../core/engine/stopwatch_engine.dart';
import '../../../core/repository/session_repository.dart';
import '../../../core/services/export_service.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sync/sync_coordinator.dart';
import '../../../core/sync/sync_meta.dart';
import '../../../core/sync/sync_status.dart';
import '../application/auth_controller.dart';
import '../domain/auth_models.dart';

/// Shows the Sign-in dialog (Google primary, email OTP secondary).
Future<void> showSignInDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => const SignInDialog(),
  );
}

/// Shows the Account / Sync management menu for signed-in users.
Future<void> showAccountMenuDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => const AccountMenuDialog(),
  );
}

/// Shows the guest import dialog on first sign-in.
Future<GuestImportChoice?> showGuestImportDialog(BuildContext context) {
  return showDialog<GuestImportChoice>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const GuestImportDialog(),
  );
}

// -------------------------------------------------------------
// Sign In Dialog
// -------------------------------------------------------------
class SignInDialog extends ConsumerStatefulWidget {
  const SignInDialog({super.key});

  @override
  ConsumerState<SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends ConsumerState<SignInDialog> {
  final _emailController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _onGoogleSignIn() async {
    final authController = ref.read(authControllerProvider.notifier);
    if (authController.isTimerActive()) {
      _showTimerActiveAlert();
      return;
    }
    setState(() => _isSubmitting = true);
    final success = await authController.signInWithGoogle();
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) Navigator.of(context).pop();
    }
  }

  void _onSendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    final authController = ref.read(authControllerProvider.notifier);
    if (authController.isTimerActive()) {
      _showTimerActiveAlert();
      return;
    }

    setState(() => _isSubmitting = true);
    final success = await authController.sendOtp(email);
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
        showDialog(
          context: context,
          builder: (ctx) => OtpVerificationDialog(email: email),
        );
      }
    }
  }

  void _showTimerActiveAlert() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AuthController.timerBlockedMessage),
        backgroundColor: Colors.amber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final isTimerRunning =
        ref.watch(stopwatchProvider).status != StopwatchStatus.idle;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_sync_outlined, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Back up & Sync',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Sign in to sync your completed reading sessions across your devices. Guest mode remains fully functional.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
            if (isTimerRunning) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stop or discard your running timer before switching accounts.',
                        style: TextStyle(fontSize: 12, color: Colors.amber),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Primary: Google Sign In
            ElevatedButton.icon(
              onPressed: (_isSubmitting || isTimerRunning) ? null : _onGoogleSignIn,
              icon: const Icon(Icons.account_circle, size: 20),
              label: const Text('Continue with Google'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or',
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            // Secondary: Email OTP
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email address',
                hintText: 'name@example.com',
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: !_isSubmitting && !isTimerRunning,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: (_isSubmitting || isTimerRunning) ? null : _onSendOtp,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send 6-digit code'),
            ),
            if (authState.hasError && authState.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                authState.errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Stay in Guest Mode'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => _showPrivacyPolicy(context),
              child: Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// OTP Verification Dialog
// -------------------------------------------------------------
class OtpVerificationDialog extends ConsumerStatefulWidget {
  final String email;

  const OtpVerificationDialog({super.key, required this.email});

  @override
  ConsumerState<OtpVerificationDialog> createState() =>
      _OtpVerificationDialogState();
}

class _OtpVerificationDialogState
    extends ConsumerState<OtpVerificationDialog> {
  final _codeController = TextEditingController();
  bool _isVerifying = false;
  Timer? _countdownTimer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    final deadline =
        ref.read(authControllerProvider).otpCooldownDeadlineMs;
    if (deadline != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final diff = ((deadline - now) / 1000).ceil();
      _secondsLeft = diff > 0 ? diff : 0;
    } else {
      _secondsLeft = 60;
    }

    _countdownTimer?.cancel();
    if (_secondsLeft > 0) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_secondsLeft > 0) {
            _secondsLeft--;
          } else {
            timer.cancel();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _onVerify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) return;

    setState(() => _isVerifying = true);
    final success =
        await ref.read(authControllerProvider.notifier).verifyOtp(code);
    if (mounted) {
      setState(() => _isVerifying = false);
      if (success) {
        Navigator.of(context).pop();
        // Check if guest import is prompted
        final coordinator = ref.read(syncCoordinatorProvider.notifier);
        if (coordinator.shouldPromptGuestImport()) {
          final choice = await showGuestImportDialog(context);
          if (choice != null) {
            await coordinator.handleGuestImport(choice);
          }
        }
      }
    }
  }

  void _onResend() async {
    if (_secondsLeft > 0) return;
    await ref.read(authControllerProvider.notifier).sendOtp(widget.email);
    _startCountdown();
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2 || parts[0].isEmpty) return email;
    final name = parts[0];
    final masked = name.length <= 2
        ? '${name[0]}*'
        : '${name[0]}${'*' * (name.length - 2)}${name[name.length - 1]}';
    return '$masked@${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter verification code',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We sent a 6-digit code to ${_maskEmail(widget.email)}. It expires in 10 minutes.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: '6-digit code',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              maxLength: 6,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                letterSpacing: 6,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isVerifying ? null : _onVerify,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isVerifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verify & Sign In'),
            ),
            if (authState.hasError && authState.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                authState.errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: _secondsLeft == 0 ? _onResend : null,
                  child: Text(
                    _secondsLeft > 0
                        ? 'Resend code ($_secondsLeft s)'
                        : 'Resend code',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Account Menu Dialog
// -------------------------------------------------------------
class AccountMenuDialog extends ConsumerWidget {
  const AccountMenuDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final syncState = ref.watch(syncCoordinatorProvider);
    final user = authState.user;
    final theme = Theme.of(context);

    if (user == null) {
      return const SizedBox.shrink();
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? Text(
                          user.displayName?.isNotEmpty == true
                              ? user.displayName![0].toUpperCase()
                              : user.email[0].toUpperCase(),
                          style: const TextStyle(fontSize: 20),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName ?? 'PageClock Reader',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        user.email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color
                              ?.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Sync status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: syncState.statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: syncState.statusColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    syncState.isSyncing
                        ? Icons.sync
                        : syncState.isSynced
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                    color: syncState.statusColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      syncState.message ?? syncState.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: syncState.statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Actions
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Sync now'),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                ref.read(syncCoordinatorProvider.notifier).sync();
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh_outlined),
              title: const Text('Full resync'),
              subtitle: const Text('Pulls all cloud sessions from start'),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                ref.read(syncCoordinatorProvider.notifier).fullResync();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Export data'),
              subtitle: const Text('Copy JSON v2 backup to clipboard'),
              contentPadding: EdgeInsets.zero,
              onTap: () async {
                try {
                  final sessions = await ref.read(sessionRepositoryProvider).getAllSessions();
                  final settingsJson = ref.read(settingsProvider).toJson();
                  final jsonStr = SessionExportService.exportJsonBackupV2(
                    sessions: sessions,
                    settings: settingsJson,
                  );
                  await Clipboard.setData(ClipboardData(text: jsonStr));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('JSON v2 Backup with ${sessions.length} sessions copied to clipboard.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Policy'),
              subtitle: const Text('Offline-first & honest cloud data terms'),
              contentPadding: EdgeInsets.zero,
              onTap: () => _showPrivacyPolicy(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.amber),
              title: const Text('Sign out'),
              subtitle: const Text('Returns to local guest mode'),
              contentPadding: EdgeInsets.zero,
              onTap: () async {
                final auth = ref.read(authControllerProvider.notifier);
                if (auth.isTimerActive()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(AuthController.timerBlockedMessage),
                      backgroundColor: Colors.amber,
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop();
                await auth.signOut();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text('Delete account',
                  style: TextStyle(color: Colors.redAccent)),
              subtitle: const Text('Permanently remove account and cloud data'),
              contentPadding: EdgeInsets.zero,
              onTap: () async {
                final auth = ref.read(authControllerProvider.notifier);
                if (auth.isTimerActive()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(AuthController.timerBlockedMessage),
                      backgroundColor: Colors.amber,
                    ),
                  );
                  return;
                }
                if (syncState.isOffline) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Account deletion requires an active internet connection to purge cloud records. Please reconnect and try again.',
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Account Permanently?'),
                    content: const Text(
                      'This will permanently delete your account and all cloud-synced sessions across all devices. Local data will be cleared and you will return to Guest mode.\n\nThis action cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        child: const Text('Delete Permanently'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && context.mounted) {
                  Navigator.of(context).pop();
                  final success = await auth.deleteAccount();
                  if (context.mounted) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Your account and all cloud data have been permanently deleted.'),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not delete account. Please check your connection and try again.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Guest Import Dialog
// -------------------------------------------------------------
class GuestImportDialog extends StatelessWidget {
  const GuestImportDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.move_to_inbox_outlined, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Existing Reading History',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'This browser contains reading history created in guest mode. Would you like to merge it into your account?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(GuestImportChoice.merge),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text("Merge this browser's history into my account"),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).pop(GuestImportChoice.cloudOnly),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text("Use my account's cloud history only"),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(GuestImportChoice.notNow),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal dialog providing honest, mode-aware privacy information in accordance with M5.
void _showPrivacyPolicy(BuildContext context) {
  final theme = Theme.of(context);
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.privacy_tip_outlined, size: 24),
          SizedBox(width: 10),
          Text('PageClock Privacy'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '100% Offline-First by Default',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'PageClock is built to respect your focus and privacy. Mobile apps (Android/iOS) run 100% offline with zero cloud synchronization, zero telemetry, and zero trackers. Web runs locally in Guest mode by default.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Optional Cloud Sync',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Web users may optionally sign in using Google or email OTP (via Resend) to sync completed reading sessions across devices using Supabase Postgres. Running timers, visual themes, and settings stay strictly on your device.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Data Sovereignty & Deletion',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'You own your data. You can export complete backups at any time. Deleting your account permanently cascades and removes all database records and authentication credentials immediately from the cloud.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Free Tier Periodic Backups',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Free cloud tiers do not provide enterprise disaster-recovery snapshots. We recommend periodically exporting a local JSON or CSV backup to keep your reading records safe.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
