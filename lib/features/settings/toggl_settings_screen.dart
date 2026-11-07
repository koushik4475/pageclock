import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_provider.dart';
import '../../main.dart';

/// Full Production Settings Screen matching Toggl Track UI
/// References:
/// - photo_2026-11-07_16-19-39.jpg
/// - photo_2026-11-07_16-19-45.jpg
/// - photo_2026-11-07_16-19-50.jpg
/// - photo_2026-11-07_16-19-55.jpg
class TogglSettingsScreen extends ConsumerStatefulWidget {
  const TogglSettingsScreen({super.key});

  @override
  ConsumerState<TogglSettingsScreen> createState() => _TogglSettingsScreenState();
}

class _TogglSettingsScreenState extends ConsumerState<TogglSettingsScreen> {
  bool _hapticFeedback = true;
  bool _showAllEntries = true;
  bool _use24HourClock = false;
  bool _groupSimilar = true;
  bool _smartDailyReminder = true;
  bool _runningTimerNotif = true;
  bool _stoppedTimerNotif = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0B15) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F0B15) : const Color(0xFFF9FAFB),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // WORKSPACE Section
            _buildSectionHeader('WORKSPACE', isDark),
            _buildCard(
              isDark,
              [
                _buildTile(
                  title: 'Workspace',
                  subtitle: 'Workspace',
                  isDark: isDark,
                  onTap: () {},
                ),
                _buildDivider(isDark),
                _buildTile(
                  title: 'Your Plan',
                  subtitle: 'Premium (Offline First)',
                  isDark: isDark,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 24),

            // YOUR PROFILE Section
            _buildSectionHeader('YOUR PROFILE', isDark),
            _buildCard(
              isDark,
              [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal details and preferences',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildProfileRow('Full name', 'Koushik HY', isDark),
                      const SizedBox(height: 10),
                      _buildProfileRow('Email', 'koushik4475@gmail.com', isDark),
                      const SizedBox(height: 10),
                      _buildProfileRow('Reports Timezone', '(GMT+05:30) Asia/Kolkata', isDark),
                      const SizedBox(height: 10),
                      _buildProfileRow('Google Sign-In', 'Enabled', isDark),
                      const SizedBox(height: 10),
                      _buildProfileRow('Apple Sign-In', 'Not Enabled', isDark),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // DATE AND TIME Section
            _buildSectionHeader('DATE AND TIME', isDark),
            _buildCard(
              isDark,
              [
                _buildTile(
                  title: 'Date format',
                  subtitle: 'MM/DD/YYYY',
                  isDark: isDark,
                  onTap: () {},
                ),
                _buildDivider(isDark),
                _buildSwitchTile(
                  title: 'Use 24-hour clock',
                  value: _use24HourClock,
                  onChanged: (v) => setState(() => _use24HourClock = v),
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildTile(
                  title: 'Duration format',
                  subtitle: 'Improved (0:47:06)',
                  isDark: isDark,
                  onTap: () {},
                ),
                _buildDivider(isDark),
                _buildTile(
                  title: 'First day of the week',
                  subtitle: 'Sunday',
                  isDark: isDark,
                  onTap: () {},
                ),
                _buildDivider(isDark),
                _buildSwitchTile(
                  title: 'Group similar time entries',
                  value: _groupSimilar,
                  onChanged: (v) => setState(() => _groupSimilar = v),
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // TIMER DEFAULTS Section
            _buildSectionHeader('TIMER DEFAULTS', isDark),
            _buildCard(
              isDark,
              [
                _buildTile(
                  title: 'Pomodoro settings',
                  subtitle: '25 min focus • 5 min break',
                  isDark: isDark,
                  onTap: () {},
                ),
                _buildDivider(isDark),
                _buildTile(
                  title: 'Prompt running entry override',
                  subtitle: 'Always',
                  isDark: isDark,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 24),

            // NOTIFICATIONS Section
            _buildSectionHeader('NOTIFICATIONS', isDark),
            _buildCard(
              isDark,
              [
                _buildSwitchTile(
                  title: 'Smart Daily Reminder',
                  value: _smartDailyReminder,
                  onChanged: (v) => setState(() => _smartDailyReminder = v),
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildSwitchTile(
                  title: 'Running timer',
                  value: _runningTimerNotif,
                  onChanged: (v) => setState(() => _runningTimerNotif = v),
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildSwitchTile(
                  title: 'Stopped timer',
                  subtitle: 'Displays an icon in the notification area whenever the timer is stopped or running.',
                  value: _stoppedTimerNotif,
                  onChanged: (v) => setState(() => _stoppedTimerNotif = v),
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // GENERAL Section
            _buildSectionHeader('GENERAL', isDark),
            _buildCard(
              isDark,
              [
                _buildTile(
                  title: 'App theme',
                  subtitle: ref.watch(appThemeIdProvider).displayName,
                  isDark: isDark,
                  onTap: () => _showThemeSelector(context),
                ),
                _buildDivider(isDark),
                _buildSwitchTile(
                  title: 'Haptic feedback',
                  value: _hapticFeedback,
                  onChanged: (v) => setState(() => _hapticFeedback = v),
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildSwitchTile(
                  title: 'Show all entries',
                  subtitle: 'List and calendar will show time entries from all workspaces.',
                  value: _showAllEntries,
                  onChanged: (v) => setState(() => _showAllEntries = v),
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildTile(
                  title: 'About',
                  subtitle: '1.0.0 (Production Release)',
                  isDark: isDark,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Bottom Sync Status
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'All data synced',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.check, size: 16, color: Color(0xFFE040FB)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDark ? const Color(0xFF2E2242) : const Color(0xFFE5E7EB),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {},
                child: Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Close Account Danger Link
            Center(
              child: TextButton(
                onPressed: () {},
                child: const Text(
                  'Close account',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
        ),
      ),
    );
  }

  Widget _buildCard(bool isDark, List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15101E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF261D36) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? const Color(0xFF261D36) : const Color(0xFFF3F4F6),
    );
  }

  Widget _buildTile({
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFE040FB),
            activeTrackColor: const Color(0xFFE040FB).withOpacity(0.35),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  void _showThemeSelector(BuildContext context) {
    final currentTheme = ref.read(appThemeIdProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF140E20) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Choose Theme',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildThemeOption(
                  ctx: ctx,
                  themeId: AppThemeId.defaultDark,
                  title: 'Default Dark',
                  subtitle: 'Obsidian & Vercel titanium aesthetic',
                  colorPreview: const [Color(0xFF0F0B15), Color(0xFFE040FB), Color(0xFF2E1B46)],
                  isSelected: currentTheme == AppThemeId.defaultDark,
                ),
                _buildThemeOption(
                  ctx: ctx,
                  themeId: AppThemeId.defaultLight,
                  title: 'Default Light',
                  subtitle: 'Minimalist clean white layout',
                  colorPreview: const [Color(0xFFF9FAFB), Color(0xFFE040FB), Color(0xFFE5E7EB)],
                  isSelected: currentTheme == AppThemeId.defaultLight,
                ),
                _buildThemeOption(
                  ctx: ctx,
                  themeId: AppThemeId.special1,
                  title: 'special1',
                  subtitle: 'Pastel Waves (Cream, Soft Rose, Butter Yellow & Sky Blue)',
                  colorPreview: const [
                    Special1Palette.background,
                    Special1Palette.accentRose,
                    Special1Palette.waveYellow,
                    Special1Palette.waveBlue,
                  ],
                  isSelected: currentTheme == AppThemeId.special1,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext ctx,
    required AppThemeId themeId,
    required String title,
    required String subtitle,
    required List<Color> colorPreview,
    required bool isSelected,
  }) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: () {
          ref.read(appThemeIdProvider.notifier).state = themeId;
          if (themeId == AppThemeId.defaultDark) {
            ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
          } else {
            ref.read(themeModeProvider.notifier).state = ThemeMode.light;
          }
          Navigator.pop(ctx);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF281F3B) : const Color(0xFFFDF2F8))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFE040FB)
                  : (isDark ? const Color(0xFF221832) : const Color(0xFFE5E7EB)),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Palette preview dots
              Row(
                mainAxisSize: MainAxisSize.min,
                children: colorPreview.map((c) {
                  return Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black12,
                        width: 1,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: Color(0xFFE040FB), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
