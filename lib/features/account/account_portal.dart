import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
bool get isSupabaseConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
bool supabaseInitialized = false;
bool get isSupabaseAvailable => isSupabaseConfigured && supabaseInitialized;

class AccountPortalScreen extends StatefulWidget {
  const AccountPortalScreen({super.key});
  @override
  State<AccountPortalScreen> createState() => _AccountPortalScreenState();
}
class _AccountPortalScreenState extends State<AccountPortalScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  bool signUp = false, busy = false;
  String? message;
  @override
  void dispose() { email.dispose(); password.dispose(); name.dispose(); super.dispose(); }

  Future<void> submit() async {
    if (!isSupabaseAvailable) return;
    setState(() { busy = true; message = null; });
    try {
      final auth = Supabase.instance.client.auth;
      if (signUp) {
        await auth.signUp(email: email.text.trim(), password: password.text, data: {'display_name': name.text.trim()});
        if (mounted) setState(() => message = 'Account created. Check your email to verify it.');
      } else {
        await auth.signInWithPassword(email: email.text.trim(), password: password.text);
        if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AccountHomeScreen()));
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => message = e.message);
    } catch (_) {
      if (mounted) setState(() => message = 'Unable to complete the request. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resetPassword() async {
    if (email.text.trim().isEmpty) { setState(() => message = 'Enter your email first.'); return; }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email.text.trim());
      if (mounted) setState(() => message = 'If the account exists, password recovery instructions have been sent.');
    } on AuthException catch (e) {
      if (mounted) setState(() => message = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('PageClock account')),
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
          const Icon(Icons.menu_book_rounded, size: 48),
          const SizedBox(height: 12),
          Text(signUp ? 'Create your account' : 'Welcome back', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Your reading sessions and notes stay on this device.', textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant)),
          const SizedBox(height: 24),
          if (!isSupabaseAvailable)
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.cloud_off_outlined),
              const SizedBox(height: 8),
              const Text('Online accounts are unavailable', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(isSupabaseConfigured
                ? 'The account service could not be initialized. You can continue using PageClock offline.'
                : 'The account service has not been configured. You can continue using PageClock offline.')
            ])))
          else ...[
            if (signUp) ...[
              TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Your name', border: OutlineInputBorder())),
              const SizedBox(height: 12),
            ],
            TextField(controller: email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: password, obscureText: true, autofillHints: [signUp ? AutofillHints.newPassword : AutofillHints.password], decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
            if (message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(message!, style: TextStyle(color: colors.primary))),
            const SizedBox(height: 16),
            FilledButton(onPressed: busy ? null : submit, child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(signUp ? 'Create account' : 'Sign in')),
            TextButton(onPressed: busy ? null : () => setState(() { signUp = !signUp; message = null; }), child: Text(signUp ? 'Already registered? Sign in' : 'Create an account')),
            if (!signUp) TextButton(onPressed: busy ? null : resetPassword, child: const Text('Forgot password?')),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back), label: const Text('Continue offline')),
        ]),
      )),
    );
  }
}

class AccountHomeScreen extends StatefulWidget {
  const AccountHomeScreen({super.key});
  @override
  State<AccountHomeScreen> createState() => _AccountHomeScreenState();
}
class _AccountHomeScreenState extends State<AccountHomeScreen> {
  final newPassword = TextEditingController();
  bool busy = false;
  String? message;
  @override
  void dispose() { newPassword.dispose(); super.dispose(); }

  Future<void> updatePassword() async {
    if (newPassword.text.length < 8) { setState(() => message = 'Use a password with at least 8 characters.'); return; }
    setState(() { busy = true; message = null; });
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPassword.text));
      newPassword.clear();
      if (mounted) setState(() => message = 'Password updated successfully.');
    } on AuthException catch (e) {
      if (mounted) setState(() => message = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text('This permanently deletes your online account. Your local reading history remains on this device. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() { busy = true; message = null; });
    try {
      await Supabase.instance.client.functions.invoke('delete-account');
      await Supabase.instance.client.auth.signOut();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on FunctionException catch (e) {
      if (mounted) setState(() => message = 'Account deletion failed (${e.status ?? 'network error'}). Please try again or contact support.');
    } catch (_) {
      if (mounted) setState(() => message = 'Account deletion failed. Please try again or contact support.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Your PageClock account'), actions: [
        IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: busy ? null : () async {
          await Supabase.instance.client.auth.signOut();
          if (context.mounted) Navigator.of(context).pop();
        }),
      ]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(user?.email ?? 'Signed in', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const ListTile(leading: Icon(Icons.privacy_tip_outlined), title: Text('Privacy-first account'), subtitle: Text('Reading sessions and notes remain on this device.')),
        const Divider(),
        Text('Set a new password', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(controller: newPassword, obscureText: true, autofillHints: const [AutofillHints.newPassword], decoration: const InputDecoration(labelText: 'New password (8+ characters)', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: busy ? null : updatePassword, child: const Text('Update password')),
        if (message != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(message!)),
        const Divider(height: 32),
        const ListTile(leading: Icon(Icons.devices_outlined), title: Text('Connected devices'), subtitle: Text('Device inventory is not collected in this release.')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: busy ? null : deleteAccount,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete account'),
          style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
        ),
        if (busy) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
      ]),
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}
class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const pageSize = 25;
  final search = TextEditingController();
  final clients = <Map<String, dynamic>>[];
  bool loading = true, loadingMore = false, admin = false, hasMore = true;
  String? error;
  int offset = 0;

  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { search.dispose(); super.dispose(); }

  Future<void> load({bool reset = false}) async {
    if (!isSupabaseAvailable) {
      setState(() { loading = false; error = 'Account service is unavailable.'; });
      return;
    }
    if (reset) { offset = 0; clients.clear(); hasMore = true; }
    setState(() { if (offset == 0) loading = true; else loadingMore = true; error = null; });
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw const AuthException('Sign in with your administrator account.');
      final role = await client.from('admin_roles').select('role').eq('user_id', user.id).maybeSingle();
      if (role == null || !['super_admin', 'admin'].contains(role['role'])) {
        if (mounted) setState(() { admin = false; loading = false; loadingMore = false; });
        return;
      }
      admin = true;
      var query = client.from('profiles').select('id, display_name, email, created_at');
      final term = search.text.trim();
      if (term.isNotEmpty) query = query.ilike('email', '%$term%');
      final rows = await query.order('created_at', ascending: false).range(offset, offset + pageSize - 1);
      if (mounted) setState(() {
        clients.addAll(rows);
        offset += rows.length;
        hasMore = rows.length == pageSize;
        loading = false;
        loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() { error = 'Unable to load client accounts. Check admin access and backend setup.'; loading = false; loadingMore = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('PageClock Admin'), actions: [
      IconButton(tooltip: 'Refresh', onPressed: loading ? null : () => load(reset: true), icon: const Icon(Icons.refresh)),
    ]),
    body: loading
      ? const Center(child: CircularProgressIndicator())
      : !admin
        ? const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_outline, size: 48),
              SizedBox(height: 12),
              Text('Administrator access required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('This account has not been granted an administrator role.'),
            ]),
          ))
        : Column(children: [
            Padding(padding: const EdgeInsets.all(16), child: TextField(
              controller: search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => load(reset: true),
              decoration: InputDecoration(
                labelText: 'Search clients by email',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () { search.clear(); load(reset: true); }),
                border: const OutlineInputBorder(),
              ),
            )),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
              Text('Client accounts', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text('${clients.length} loaded', style: Theme.of(context).textTheme.bodySmall),
            ])),
            if (error != null) Padding(padding: const EdgeInsets.all(16), child: Text(error!)),
            Expanded(child: clients.isEmpty
              ? const Center(child: Text('No client accounts found.'))
              : ListView.separated(
                  itemCount: clients.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final row = clients[index];
                    final created = DateTime.tryParse('${row['created_at']}')?.toLocal();
                    final displayName = (row['display_name'] as String?)?.trim();
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                      title: Text(displayName?.isNotEmpty == true ? displayName! : 'PageClock client'),
                      subtitle: Text('${row['email'] ?? 'No email'}\nJoined: ${created?.toString().split('.').first ?? 'Unknown'}'),
                      isThreeLine: true,
                    );
                  },
                ),
            ),
            if (hasMore && clients.isNotEmpty) Padding(padding: const EdgeInsets.all(12), child: OutlinedButton(
              onPressed: loadingMore ? null : () => load(),
              child: loadingMore ? const CircularProgressIndicator() : const Text('Load more clients'),
            )),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('Only account email, display name and registration date are visible. Reading history and notes are never exposed.', textAlign: TextAlign.center),
            ),
          ]),
  );
}
