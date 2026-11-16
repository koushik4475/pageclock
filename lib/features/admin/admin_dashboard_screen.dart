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
  String section = 'Overview';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminDashboardProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF10111A) : const Color(0xFFF7F8FC),
      body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1050;
        return Row(children: [
          if (wide) _AdminRail(selected: section, onSelect: (v) => setState(() => section = v)),
          Expanded(child: Column(children: [
            _AdminHeader(wide: wide, onRefresh: () => ref.invalidate(adminDashboardProvider),
              onWorkspace: () => Navigator.pop(context)),
            if (!wide) _AdminMobileNav(selected: section, onSelect: (v) => setState(() => section = v)),
            Expanded(child: async.when(
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
                  onRefresh: () => ref.refresh(adminDashboardProvider.future).then((_) {}),
                  child: ListView(padding: EdgeInsets.fromLTRB(wide ? 30 : 18, 25, wide ? 30 : 18, 36),
                    children: [
                      _AdminHeading(section: section),
                      const SizedBox(height: 22),
                      if (section == 'Overview' || section == 'Analytics') ...[
                        _AdminMetrics(data: data),
                        const SizedBox(height: 18),
                        _AdminChartPanel(points: data.dailyFocus),
                        if (section == 'Overview') ...[
                          const SizedBox(height: 16),
                          const _AdminPrivacy(),
                        ],
                      ],
                      if (section == 'Overview' || section == 'Clients') ...[
                        const SizedBox(height: 25),
                        _AdminClientDirectory(clients: clients, onSearch: (v) => setState(() => query = v)),
                      ],
                      if (section == 'Activity' || section == 'Settings')
                        _AdminPlannedPanel(section: section),
                    ]),
                );
              },
            )),
          ])),
        ]);
      })),
    );
  }
}

class _AdminRail extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _AdminRail({required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Colors.white : const Color(0xFF171A35);
    final muted = dark ? Colors.white54 : const Color(0xFF858BA2);
    return Container(width: 232,
      decoration: BoxDecoration(color: dark ? const Color(0xFF171927) : Colors.white,
        border: Border(right: BorderSide(color: dark ? Colors.white10 : const Color(0xFFE8EAF2)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(21, 25, 12, 30),
          child: Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(
              color: const Color(0xFF5146E5), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.auto_stories_rounded, color: Colors.white)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PageClock', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: fg)),
              Text('ADMIN CONSOLE', style: TextStyle(fontSize: 9, letterSpacing: 1.4,
                fontWeight: FontWeight.w800, color: muted)),
            ]),
          ])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Text('WORKSPACE', style: TextStyle(fontSize: 10, letterSpacing: 1.4,
            fontWeight: FontWeight.w900, color: muted))),
        const SizedBox(height: 9),
        for (final item in ['Overview', 'Clients', 'Analytics', 'Activity', 'Settings'])
          _AdminNavItem(label: item, selected: selected == item,
            onTap: () => onSelect(item)),
        const Spacer(),
        Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: dark ? Colors.white.withOpacity(.045) : const Color(0xFFF3F2FF),
            borderRadius: BorderRadius.circular(14), border: Border.all(
              color: dark ? Colors.white10 : const Color(0xFFE8E5FF))),
          child: Row(children: [
            const CircleAvatar(radius: 17, backgroundColor: Color(0xFF5146E5),
              child: Text('K', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Koushik HY', style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
              Text('Owner · Admin', style: TextStyle(color: muted, fontSize: 10)),
            ])),
            const Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF5146E5)),
          ])),
      ]),
    );
  }
}

class _AdminNavItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AdminNavItem({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? Colors.white60 : const Color(0xFF747A94);
    final icon = switch (label) {
      'Overview' => Icons.grid_view_rounded,
      'Clients' => Icons.people_alt_outlined,
      'Analytics' => Icons.query_stats_rounded,
      'Activity' => Icons.shield_outlined,
      _ => Icons.tune_rounded,
    };
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(color: selected
        ? (dark ? const Color(0xFF5146E5).withOpacity(.22) : const Color(0xFFEFEEFF))
        : Colors.transparent, borderRadius: BorderRadius.circular(11),
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(11),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(children: [
              Icon(icon, size: 18, color: selected ? const Color(0xFF5146E5) : muted),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: selected
                ? FontWeight.w800 : FontWeight.w600,
                color: selected ? const Color(0xFF5146E5) : (dark ? Colors.white70 : const Color(0xFF414761)))),
              if (label == 'Activity' || label == 'Settings') ...[
                const Spacer(),
                Text('Soon', style: TextStyle(fontSize: 9, color: muted)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _AdminHeader extends StatelessWidget {
  final bool wide;
  final VoidCallback onRefresh, onWorkspace;
  const _AdminHeader({required this.wide, required this.onRefresh, required this.onWorkspace});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(height: 66, padding: EdgeInsets.symmetric(horizontal: wide ? 27 : 15),
      decoration: BoxDecoration(color: dark ? const Color(0xFF171927) : Colors.white,
        border: Border(bottom: BorderSide(color: dark ? Colors.white10 : const Color(0xFFE8EAF2)))),
      child: Row(children: [
        if (!wide) const Icon(Icons.auto_stories_rounded, color: Color(0xFF5146E5)),
        if (!wide) const SizedBox(width: 8),
        Text('PageClock Admin', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
          color: dark ? Colors.white : const Color(0xFF171A35))),
        const Spacer(),
        IconButton(onPressed: onRefresh, tooltip: 'Refresh analytics',
          icon: Icon(Icons.refresh_rounded, color: dark ? Colors.white : const Color(0xFF414761))),
        const SizedBox(width: 6),
        OutlinedButton.icon(onPressed: onWorkspace,
          icon: const Icon(Icons.person_outline_rounded, size: 17),
          label: const Text('Client workspace'),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF5146E5),
            side: const BorderSide(color: Color(0xFFCECBFF)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
      ]),
    );
  }
}

class _AdminMobileNav extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _AdminMobileNav({required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(12, 9, 12, 3),
    child: Row(children: [
      for (final item in ['Overview', 'Clients', 'Analytics', 'Activity', 'Settings'])
        Padding(padding: const EdgeInsets.only(right: 7),
          child: ChoiceChip(label: Text(item), selected: selected == item,
            onSelected: (_) => onSelect(item))),
    ]),
  );
}

class _AdminHeading extends StatelessWidget {
  final String section;
  const _AdminHeading({required this.section});
  @override
  Widget build(BuildContext context) {
    final title = section == 'Clients' ? 'Client directory'
      : section == 'Analytics' ? 'Community analytics'
      : section == 'Activity' ? 'Activity & audit'
      : section == 'Settings' ? 'Admin settings' : 'Your reading community';
    final subtitle = section == 'Clients' ? 'Explore client accounts and reading statistics.'
      : section == 'Analytics' ? 'Understand focus trends across the PageClock community.'
      : section == 'Activity' ? 'Administrative history and security events.'
      : section == 'Settings' ? 'Preferences and dashboard configuration.'
      : 'A focused reading community, powered by PageClock.';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(section.toUpperCase(), style: const TextStyle(fontSize: 10, letterSpacing: 1.5,
        color: Color(0xFF5146E5), fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w900, letterSpacing: -.7)),
      const SizedBox(height: 4),
      Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
  }
}

class _AdminMetrics extends StatelessWidget {
  final AdminDashboardData data;
  const _AdminMetrics({required this.data});
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final columns = w >= 1250 ? 4 : 2;
    return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: columns, crossAxisSpacing: 12, mainAxisSpacing: 12,
      childAspectRatio: w >= 1250 ? 2.15 : (w >= 700 ? 2.2 : 1.65),
      children: [
        _AdminMetric(label: 'Total clients', value: data.totalClients.toString(),
          icon: Icons.people_alt_outlined, tint: const Color(0xFF5146E5), foot: 'Registered accounts'),
        _AdminMetric(label: 'Active today', value: data.activeToday.toString(),
          icon: Icons.bolt_rounded, tint: const Color(0xFF16A36A), foot: 'Today'),
        _AdminMetric(label: 'Active · 7 days', value: data.activeSevenDays.toString(),
          icon: Icons.calendar_month_outlined, tint: const Color(0xFF1688D4), foot: 'Last 7 days'),
        _AdminMetric(label: 'Total focus time', value: formatAdminDuration(data.totalFocusMs),
          icon: Icons.timer_outlined, tint: const Color(0xFF8755D9),
          foot: data.totalSessions.toString() + ' recorded sessions'),
      ],
    );
  }
}

class _AdminMetric extends StatelessWidget {
  final String label, value, foot;
  final IconData icon;
  final Color tint;
  const _AdminMetric({required this.label, required this.value, required this.icon,
    required this.tint, required this.foot});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Colors.white : const Color(0xFF171A35);
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: dark ? const Color(0xFF191C2B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? Colors.white10 : const Color(0xFFE7E9F2)),
        boxShadow: dark ? null : [BoxShadow(color: const Color(0xFF28305B).withOpacity(.035),
          blurRadius: 14, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(
            color: tint.withOpacity(.11), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: tint, size: 19)),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(value,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900,
                letterSpacing: -.6, color: fg))),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
            Text(foot, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, color: dark ? Colors.white54 : const Color(0xFF858BA2))),
          ]),
        ]),
    );
  }
}

class _AdminChartPanel extends StatelessWidget {
  final List<AdminDailyPoint> points;
  const _AdminChartPanel({required this.points});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(padding: const EdgeInsets.fromLTRB(18, 17, 18, 13),
      decoration: BoxDecoration(color: dark ? const Color(0xFF191C2B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dark ? Colors.white10 : const Color(0xFFE7E9F2)),
        boxShadow: dark ? null : [BoxShadow(color: const Color(0xFF28305B).withOpacity(.035),
          blurRadius: 14, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(
            color: const Color(0xFF5146E5).withOpacity(.10), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.bar_chart_rounded, color: Color(0xFF5146E5), size: 19)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Community focus time', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            Text('Daily focus across all clients · last 30 days',
              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: const Color(0xFFEFEEFF), borderRadius: BorderRadius.circular(8)),
            child: const Text('30 DAYS', style: TextStyle(color: Color(0xFF5146E5),
              fontSize: 9, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 18),
        SizedBox(height: 205, child: _AdminFocusChart(points: points)),
      ]),
    );
  }
}

class _AdminFocusChart extends StatelessWidget {
  final List<AdminDailyPoint> points;
  const _AdminFocusChart({required this.points});
  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const Center(child: Text('No focus activity recorded yet.'));
    final cs = Theme.of(context).colorScheme;
    final maxHours = points.fold<double>(1, (m, p) =>
      p.focusMs / 3600000 > m ? p.focusMs / 3600000 : m);
    return BarChart(BarChartData(maxY: maxHours * 1.2,
      gridData: FlGridData(show: true, drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withOpacity(.45))),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32,
          getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0) + 'h',
            style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 23,
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= points.length || i % 5 != 0) return const SizedBox.shrink();
            return Padding(padding: const EdgeInsets.only(top: 6),
              child: Text(points[i].date.day.toString(),
                style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)));
          })),
      ),
      barGroups: [for (var i = 0; i < points.length; i++)
        BarChartGroupData(x: i, barRods: [BarChartRodData(
          toY: points[i].focusMs / 3600000, width: points.length > 20 ? 6 : 12,
          color: const Color(0xFF6257E8),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        )])],
    ));
  }
}

class _AdminClientDirectory extends StatelessWidget {
  final List<AdminClient> clients;
  final ValueChanged<String> onSearch;
  const _AdminClientDirectory({required this.clients, required this.onSearch});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? Colors.white54 : const Color(0xFF858BA2);
    return Container(padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: dark ? const Color(0xFF191C2B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dark ? Colors.white10 : const Color(0xFFE7E9F2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Clients', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            SizedBox(height: 3),
            Text('Registered accounts and reading analytics', style: TextStyle(fontSize: 10)),
          ])),
          Text(clients.length.toString() + ' shown', style: TextStyle(fontSize: 10, color: muted)),
        ]),
        const SizedBox(height: 13),
        TextField(onChanged: onSearch, decoration: InputDecoration(
          hintText: 'Search by name or email', prefixIcon: const Icon(Icons.search_rounded, size: 19),
          isDense: true, filled: true,
          fillColor: dark ? Colors.white.withOpacity(.045) : const Color(0xFFF7F8FC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide(color: dark ? Colors.white12 : const Color(0xFFE8EAF2))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide(color: dark ? Colors.white12 : const Color(0xFFE8EAF2))),
        )),
        const SizedBox(height: 10),
        if (clients.isEmpty) Padding(padding: const EdgeInsets.all(24),
          child: Center(child: Text('No clients match your search.', style: TextStyle(color: muted))))
        else ...clients.map((c) => _AdminClientRow(client: c, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminClientDetailScreen(client: c))))),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF5146E5)),
          const SizedBox(width: 6),
          Expanded(child: Text('Analytics only · private reading notes and session content are never displayed.',
            style: TextStyle(fontSize: 10, color: muted))),
        ]),
      ]),
    );
  }
}

class _AdminClientRow extends StatelessWidget {
  final AdminClient client;
  final VoidCallback onTap;
  const _AdminClientRow({required this.client, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? Colors.white54 : const Color(0xFF858BA2);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10),
        child: Row(children: [
        CircleAvatar(radius: 18, backgroundColor: const Color(0xFF5146E5).withOpacity(.12),
          backgroundImage: client.avatarUrl == null || client.avatarUrl!.isEmpty
            ? null : NetworkImage(client.avatarUrl!),
          child: client.avatarUrl == null || client.avatarUrl!.isEmpty
            ? Text(client.name.isEmpty ? '?' : client.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Color(0xFF5146E5), fontWeight: FontWeight.w900)) : null),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(client.name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          Text(client.email, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: muted)),
        ])),
        if (MediaQuery.sizeOf(context).width > 540) ...[
          Text(formatAdminDuration(client.totalFocusMs),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(width: 13),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xFFE8F8EF), borderRadius: BorderRadius.circular(8)),
            child: Text(client.currentStreak.toString() + 'd streak',
              style: const TextStyle(fontSize: 9, color: Color(0xFF16834A), fontWeight: FontWeight.w900))),
        ],
        Icon(Icons.chevron_right_rounded, size: 18, color: muted),
        ]),
      ),
    );
  }
}

class _AdminPrivacy extends StatelessWidget {
  const _AdminPrivacy();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: const Color(0xFFEFEEFF), borderRadius: BorderRadius.circular(11)),
    child: const Row(children: [
      Icon(Icons.verified_user_outlined, color: Color(0xFF5146E5), size: 17),
      SizedBox(width: 9),
      Expanded(child: Text('Privacy first · Only aggregated reading statistics are visible in the admin portal.',
        style: TextStyle(color: Color(0xFF34306F), fontSize: 10, fontWeight: FontWeight.w700))),
    ]),
  );
}

class _AdminPlannedPanel extends StatelessWidget {
  final String section;
  const _AdminPlannedPanel({required this.section});
  @override
  Widget build(BuildContext context) => Center(child: Container(
    constraints: const BoxConstraints(maxWidth: 430),
    padding: const EdgeInsets.all(27),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.construction_rounded, size: 32, color: Color(0xFF5146E5)),
      const SizedBox(height: 12),
      Text(section + ' is planned', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      const SizedBox(height: 7),
      const Text('This area will be enabled after its backend data, permissions and workflows are implemented and verified.',
        textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
    ]),
  ));
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
