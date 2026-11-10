import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
bool get isSupabaseConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

class AccountPortalScreen extends StatefulWidget {
  const AccountPortalScreen({super.key});
  @override
  State<AccountPortalScreen> createState() => _AccountPortalScreenState();
}
class _AccountPortalScreenState extends State<AccountPortalScreen> {
  final email = TextEditingController(), password = TextEditingController(), name = TextEditingController();
  bool signUp = false, busy = false;
  String? message;
  @override
  void dispose() { email.dispose(); password.dispose(); name.dispose(); super.dispose(); }
  Future<void> submit() async {
    if (!isSupabaseConfigured) return;
    setState(() { busy = true; message = null; });
    try {
      final auth = Supabase.instance.client.auth;
      if (signUp) {
        await auth.signUp(email: email.text.trim(), password: password.text, data: {'display_name': name.text.trim()});
        setState(() => message = 'Account created. Check your email to verify it.');
      } else {
        await auth.signInWithPassword(email: email.text.trim(), password: password.text);
        if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AccountHomeScreen()));
      }
    } on AuthException catch (e) { setState(() => message = e.message); }
    catch (_) { setState(() => message = 'Unable to complete the request. Please try again.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> resetPassword() async {
    if (email.text.trim().isEmpty) { setState(() => message = 'Enter your email first.'); return; }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email.text.trim());
      setState(() => message = 'Password reset instructions sent if the account exists.');
    } on AuthException catch (e) { setState(() => message = e.message); }
  }
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: const Text('PageClock account')),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
          const Icon(Icons.menu_book_rounded, size: 48),
          const SizedBox(height: 12),
          Text(signUp ? 'Create your account' : 'Welcome back', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Your reading sessions stay on this device unless you separately choose to share data.',
            textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant)),
          const SizedBox(height: 24),
          if (!isSupabaseConfigured)
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.cloud_off_outlined), SizedBox(height: 8),
              Text('Online accounts are not configured yet', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6), Text('PageClock remains fully usable offline. Configure Supabase URL and public anon key to enable accounts.')
            ])))
          else ...[
            if (signUp) ...[TextField(controller: name, decoration: const InputDecoration(labelText: 'Your name', border: OutlineInputBorder())), const SizedBox(height: 12)],
            TextField(controller: email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: password, obscureText: true, autofillHints: [signUp ? AutofillHints.newPassword : AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
            if (message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(message!, style: TextStyle(color: colors.primary))),
            const SizedBox(height: 16),
            FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : Text(signUp ? 'Create account' : 'Sign in')),
            TextButton(onPressed: busy ? null : () => setState(() { signUp = !signUp; message = null; }),
              child: Text(signUp ? 'Already registered? Sign in' : 'Create an account')),
            if (!signUp) TextButton(onPressed: busy ? null : resetPassword, child: const Text('Forgot password?')),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back), label: const Text('Continue offline')),
        ]))));
  }
}

class AccountHomeScreen extends StatelessWidget {
  const AccountHomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return Scaffold(appBar: AppBar(title: const Text('Your PageClock account'), actions: [
      IconButton(icon: const Icon(Icons.logout), onPressed: () async {
        await Supabase.instance.client.auth.signOut();
        if (context.mounted) Navigator.of(context).pop();
      })
    ]), body: ListView(padding: const EdgeInsets.all(20), children: [
      Text(user?.email ?? 'Signed in', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      const ListTile(leading: Icon(Icons.privacy_tip_outlined), title: Text('Privacy-first account'), subtitle: Text('Reading sessions and notes remain on this device.')),
      const ListTile(leading: Icon(Icons.devices_outlined), title: Text('Connected devices'), subtitle: Text('Device management will be added in a later stage.')),
    ]));
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}
class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool loading = true, admin = false;
  int? clients;
  String? error;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final client = Supabase.instance.client, user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw const AuthException('Sign in with your administrator account.');
      final role = await client.from('admin_roles').select('role').eq('user_id', user.id).maybeSingle();
      if (role == null || !['super_admin', 'admin'].contains(role['role'])) { setState(() => loading = false); return; }
      final rows = await client.from('profiles').select('id');
      setState(() { admin = true; clients = rows.length; loading = false; });
    } catch (e) { setState(() { error = e.toString(); loading = false; }); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('PageClock Admin')),
    body: loading ? const Center(child: CircularProgressIndicator()) : !admin
      ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline, size: 48), SizedBox(height: 12),
          Text('Administrator access required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8), Text('This account has not been granted an administrator role.')
        ])))
      : ListView(padding: const EdgeInsets.all(20), children: [
          Text('Overview', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 16),
          Card(child: ListTile(leading: const Icon(Icons.people_outline), title: const Text('Registered clients'),
            trailing: Text('${clients ?? 0}', style: Theme.of(context).textTheme.headlineMedium))),
          const Card(child: ListTile(leading: Icon(Icons.privacy_tip_outlined), title: Text('Privacy-safe administration'),
            subtitle: Text('Only account metadata is shown. Personal reading sessions and notes are not exposed.'))),
          if (error != null) Text(error!),
        ]);
}
