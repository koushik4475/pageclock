import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_service.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminDashboardProvider);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PageClock Admin'),
        actions: [
          IconButton(onPressed: () => ref.invalidate(adminDashboardProvider),
            icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh'),
          TextButton.icon(onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back), label: const Text('Client workspace')),
          const SizedBox(width: 8),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: 12),
          const Text('Could not load admin analytics'),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => ref.invalidate(adminDashboardProvider),
            child: const Text('Try again')),
        ])),
        data: (data) {
          final q = query.trim().toLowerCase();
          final clients = data.clients.where((c) =>
            c.name.toLowerCase().contains(q) || c.email.toLowerCase().contains(q)).toList();
          return RefreshIndicator(
            onRefresh: () async { await ref.refresh(adminDashboardProvider.future); },
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 36), children: [
              Text('OVERVIEW', style: TextStyle(color: cs.primary, fontSize: 11,
                fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const SizedBox(height: 5),
              Text('Your reading community', style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900, letterSpacing: -0.7)),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, box) {
                final cols = box.maxWidth > 900 ? 4 : 2;
                return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12,
                  childAspectRatio: box.maxWidth > 900 ? 1.9 : 1.55,
                  children: [
                    _Metric('Clients', data.totalClients.toString(), Icons.people_outline, cs.primary),
                    _Metric('Active today', data.activeToday.toString(), Icons.bolt, const Color(0xFF16A34A)),
                    _Metric('Active · 7 days', data.activeSevenDays.toString(), Icons.calendar_today, const Color(0xFF0EA5E9)),
                    _Metric('Total focus', formatAdminDuration(data.totalFocusMs), Icons.timer_outlined, const Color(0xFF8B5CF6)),
                  ]);
              }),
              const SizedBox(height: 22),
              _Panel(title: 'Community focus time', subtitle: 'Daily focus · last 30 days',
                child: SizedBox(height: 205, child: _Chart(data.dailyFocus))),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: Text('Clients', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900))),
                Text(clients.length.toString() + ' shown',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              ]),
              const SizedBox(height: 10),
              TextField(onChanged: (v) => setState(() => query = v),
                decoration: InputDecoration(hintText: 'Search name or Gmail',
                  prefixIcon: const Icon(Icons.search), filled: true,
                  fillColor: cs.surfaceContainerHighest.withOpacity(.55),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none))),
              const SizedBox(height: 12),
              if (clients.isEmpty)
                const Padding(padding: EdgeInsets.all(28),
                  child: Center(child: Text('No clients match your search.')))
              else
                ...clients.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _ClientRow(client: c, onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => AdminClientDetailScreen(client: c)))),
                )),
              const SizedBox(height: 12),
              Text('Analytics only · private reading notes are never displayed.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ]),
          );
        },
      ),
    );
  }
}

class AdminClientDetailScreen extends StatelessWidget {
  final AdminClient client;
  const AdminClientDetailScreen({super.key, required this.client});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = client.dailyFocusMs.entries.toList()..sort((a,b) => a.key.compareTo(b.key));
    final points = entries.take(30).map((e) =>
      AdminDailyPoint(DateTime.tryParse(e.key) ?? DateTime.now(), e.value)).toList();
    return Scaffold(appBar: AppBar(title: const Text('Client analytics')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Column(children: [
          _Avatar(url: client.avatarUrl, name: client.name, radius: 38),
          const SizedBox(height: 12),
          Text(client.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(client.email, style: TextStyle(color: cs.onSurfaceVariant)),
          Text('Joined ' + _date(client.createdAt), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ]),
        const SizedBox(height: 22),
        LayoutBuilder(builder: (context, box) => GridView.count(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: box.maxWidth > 650 ? 4 : 2,
          crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.7,
          children: [
            _Metric('Lifetime focus', formatAdminDuration(client.totalFocusMs), Icons.timer, cs.primary),
            _Metric('This week', formatAdminDuration(client.weekFocusMs), Icons.date_range, const Color(0xFF0EA5E9)),
            _Metric('Current streak', client.currentStreak.toString() + ' days', Icons.local_fire_department, const Color(0xFFF97316)),
            _Metric('Best streak', client.bestStreak.toString() + ' days', Icons.emoji_events, const Color(0xFF8B5CF6)),
          ])),
        const SizedBox(height: 18),
        _Panel(title: 'Daily focus activity', subtitle: 'Based on completed sessions',
          child: SizedBox(height: 220, child: _Chart(points))),
        const SizedBox(height: 18),
        _Panel(title: 'Account activity', subtitle: 'Usage metadata only',
          child: Column(children: [
            _Info('Completed sessions', client.sessionCount.toString()),
            _Info('Last active', _dateTime(client.lastActiveAt)),
            _Info('Last sign-in', _dateTime(client.lastSignInAt)),
          ])),
      ]));
  }
}

class _Metric extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _Metric(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(17),
        border: Border.all(color: cs.outlineVariant.withOpacity(.7))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icon, color: color, size: 20),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ]),
        ]));
  }
}

class _Panel extends StatelessWidget {
  final String title, subtitle;
  final Widget child;
  const _Panel({required this.title, required this.subtitle, required this.child});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(19),
        border: Border.all(color: cs.outlineVariant.withOpacity(.7))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(subtitle, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        const SizedBox(height: 16), child,
      ]));
  }
}

class _ClientRow extends StatelessWidget {
  final AdminClient client;
  final VoidCallback onTap;
  const _ClientRow({required this.client, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(color: cs.surface, borderRadius: BorderRadius.circular(15),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(15),
        child: Container(padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(15),
            border: Border.all(color: cs.outlineVariant.withOpacity(.7))),
          child: Row(children: [
            _Avatar(url: client.avatarUrl, name: client.name, radius: 23),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(client.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              Text(client.email, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              const SizedBox(height: 5),
              Wrap(spacing: 12, children: [
                Text(formatAdminDuration(client.totalFocusMs),
                  style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w800)),
                Text(client.currentStreak.toString() + ' day streak',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ]),
            ])),
            const Icon(Icons.chevron_right_rounded),
          ]))));
  }
}

class _Avatar extends StatelessWidget {
  final String? url, name;
  final double radius;
  const _Avatar({required this.url, required this.name, required this.radius});
  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(radius: radius,
      child: Text((name == null || name!.isEmpty) ? '?' : name!.substring(0,1).toUpperCase()));
    if (url == null || url!.isEmpty) return fallback;
    return CircleAvatar(radius: radius, backgroundImage: NetworkImage(url!));
  }
}

class _Chart extends StatelessWidget {
  final List<AdminDailyPoint> points;
  const _Chart(this.points);
  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const Center(child: Text('No activity recorded yet.'));
    final cs = Theme.of(context).colorScheme;
    final maxHours = points.fold<double>(1, (m,p) =>
      p.focusMs / 3600000 > m ? p.focusMs / 3600000 : m);
    return BarChart(BarChartData(maxY: maxHours * 1.2,
      gridData: FlGridData(show: true, drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withOpacity(.4))),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30,
          getTitlesWidget: (v,_) => Text(v.toStringAsFixed(0),
            style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 25,
          getTitlesWidget: (v,_) {
            final i = v.toInt();
            if (i < 0 || i >= points.length || i % 5 != 0) return const SizedBox.shrink();
            return Padding(padding: const EdgeInsets.only(top: 6),
              child: Text(points[i].date.day.toString(),
                style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)));
          })),
      ),
      barGroups: [for (var i=0; i<points.length; i++) BarChartGroupData(x:i,
        barRods: [BarChartRodData(toY: points[i].focusMs / 3600000,
          width: points.length > 20 ? 5 : 12, color: cs.primary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))])],
    ));
  }
}

class _Info extends StatelessWidget {
  final String label, value;
  const _Info(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontSize: 12,
        color: Theme.of(context).colorScheme.onSurfaceVariant))),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
    ]));
}

String _date(DateTime? d) => d == null ? '—' :
  d.day.toString().padLeft(2,'0') + '/' + d.month.toString().padLeft(2,'0') + '/' + d.year.toString();
String _dateTime(DateTime? d) => d == null ? '—' :
  _date(d) + ' · ' + d.hour.toString().padLeft(2,'0') + ':' + d.minute.toString().padLeft(2,'0');
