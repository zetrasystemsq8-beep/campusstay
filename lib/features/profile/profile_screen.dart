import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/error_views.dart';
import '../../core/widgets/logo.dart';
import '../../data/auth_service.dart';
import '../../data/profile_models.dart';
import '../../data/repository.dart';
import '../splash/splash_screen.dart';
import 'profile_settings_screens.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<ProfileData> _f = Services.profile.load();
  late final Future<PackageInfo> _pkg = PackageInfo.fromPlatform();

  void _reload() => setState(() => _f = Services.profile.load());

  Future<void> _edit(ProfileData p) async {
    final saved = await showEditProfileSheet(context, p);
    if (saved == true) _reload();
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to use CampusStay.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Stay signed in')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: CS.danger), onPressed: () => Navigator.pop(c, true), child: const Text('Log out')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AuthService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const SplashScreen()), (r) => false);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _open(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) => FutureBuilder<ProfileData>(
        future: _f,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (s.hasError) return ErrorView(error: s.error!, onRetry: _reload);
          final p = s.data!;
          final accent = Theme.of(context).colorScheme.primary;
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _f;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(CS.s16, CS.s16, CS.s16, CS.s24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Text('Profile', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 32)),
                const SizedBox(height: 16),
                _Header(profile: p, accent: accent, onEdit: () => _edit(p)),
                const _SectionTitle('Account Information'),
                _Card(children: [
                  _InfoRow(icon: Icons.person, label: 'Full Name', value: p.name.isEmpty ? 'Add your name' : p.name, muted: p.name.isEmpty, accent: accent, onTap: () => _edit(p)),
                  _InfoRow(icon: Icons.mail, label: 'Email Address', value: p.email, accent: accent),
                  _InfoRow(icon: Icons.phone, label: 'Phone Number', value: p.phone ?? 'Add your phone number', muted: p.phone == null, accent: accent, onTap: () => _edit(p)),
                  _InfoRow(icon: Icons.badge, label: 'Account Role', value: p.roleLabel, accent: accent),
                  _InfoRow(icon: Icons.shield, label: 'Account Status', chip: _StatusChip(active: !p.suspended), accent: accent),
                ]),
                const _SectionTitle('Settings'),
                _Card(children: [
                  _SettingRow(icon: Icons.notifications, title: 'Notifications', subtitle: 'See your recent alerts', accent: accent, onTap: () => _open(const NotificationsScreen())),
                  _SettingRow(icon: Icons.lock, title: 'Change Password', subtitle: 'Update your account password', accent: accent, onTap: () => _open(ChangePasswordScreen(email: p.email))),
                  _SettingRow(icon: Icons.shield_outlined, title: 'Privacy & Security', subtitle: 'Blocked people and how your data is used', accent: accent, onTap: () => _open(const PrivacyScreen())),
                  _SettingRow(icon: Icons.help, title: 'Help & Support', subtitle: 'Safety tips, FAQ and contact', accent: accent, onTap: () => _open(const HelpScreen())),
                  _SettingRow(icon: Icons.info, title: 'About the App', subtitle: 'Version, licences and policies', accent: accent, onTap: () => _open(const AboutScreen())),
                ]),
                const _SectionTitle('App Information'),
                Container(
                  padding: const EdgeInsets.all(CS.s16),
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(CS.rMd)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: const Center(child: LogoMark(size: 38)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('CampusStay', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        FutureBuilder<PackageInfo>(
                          future: _pkg,
                          builder: (c, s) => Text(s.hasData ? 'Version ${s.data!.version} (${s.data!.buildNumber})' : 'Version', style: Theme.of(context).textTheme.bodyMedium),
                        ),
                        const SizedBox(height: 4),
                        Text('Find student accommodation and talk directly to landlords. Find Your Space. Live Your Dreams.', style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                Material(
                  color: CS.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(CS.rMd),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(CS.rMd),
                    onTap: _logout,
                    child: Padding(
                      padding: const EdgeInsets.all(CS.s16),
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: CS.danger.withValues(alpha: 0.12), shape: BoxShape.circle),
                          child: const Icon(Icons.logout, color: CS.danger),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Log out', style: TextStyle(color: CS.danger, fontWeight: FontWeight.w800, fontSize: 16)),
                            Text('Sign out of your account', style: TextStyle(color: CS.muted, fontSize: 13)),
                          ]),
                        ),
                        const Icon(Icons.chevron_right, color: CS.danger),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _Header extends StatelessWidget {
  final ProfileData profile;
  final Color accent;
  final VoidCallback onEdit;
  const _Header({required this.profile, required this.accent, required this.onEdit});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(CS.s16),
        decoration: BoxDecoration(color: accent.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(CS.rMd)),
        child: LayoutBuilder(builder: (c, box) {
          final narrow = box.maxWidth < 380;
          final button = FilledButton.tonalIcon(
            style: FilledButton.styleFrom(foregroundColor: accent, backgroundColor: accent.withValues(alpha: 0.12)),
            onPressed: onEdit,
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w700)),
          );
          final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(profile.name.isEmpty ? 'Welcome' : profile.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(profile.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            _StatusChip(active: !profile.suspended),
          ]);
          final top = Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            CircleAvatar(radius: 38, backgroundColor: accent, child: Text(profile.initials, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800))),
            const SizedBox(width: 14),
            Expanded(child: info),
            if (!narrow) ...[const SizedBox(width: 8), button],
          ]);
          if (!narrow) return top;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [top, const SizedBox(height: 12), SizedBox(width: double.infinity, child: button)]);
        }),
      );
}

class _StatusChip extends StatelessWidget {
  final bool active;
  const _StatusChip({required this.active});
  @override
  Widget build(BuildContext context) {
    final color = active ? CS.green : CS.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 6),
        Text(active ? 'Active' : 'Suspended', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(4, 22, 0, 10), child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)));
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: CS.bg, borderRadius: BorderRadius.circular(CS.rMd), border: Border.all(color: CS.line)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: CS.line),
            children[i],
          ],
        ]),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? chip;
  final bool muted;
  final Color accent;
  final VoidCallback? onTap;
  const _InfoRow({required this.icon, required this.label, this.value, this.chip, this.muted = false, required this.accent, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CS.s16, vertical: 12),
          child: Row(children: [
            Icon(icon, color: accent.withValues(alpha: 0.9), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                if (chip != null) chip! else Text(value ?? '', style: TextStyle(fontSize: 15.5, color: muted ? CS.muted : CS.ink)),
              ]),
            ),
            if (onTap != null) const Icon(Icons.chevron_right, color: CS.muted),
          ]),
        ),
      );
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color accent;
  final VoidCallback onTap;
  const _SettingRow({required this.icon, required this.title, required this.subtitle, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CS.s16, vertical: 12),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            const Icon(Icons.chevron_right, color: CS.muted),
          ]),
        ),
      );
}
