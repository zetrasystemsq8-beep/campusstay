import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/error_views.dart';
import '../../core/widgets/logo.dart';
import '../../core/widgets/state_views.dart';
import '../../data/location_models.dart';
import '../../data/profile_models.dart';
import '../legal/legal_screens.dart';
import '../../data/repository.dart';

Future<void> _openLink(BuildContext context, Uri uri) async {
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showError(context, const AppException(AppErrorKind.invalid, detail: 'No app on this phone could open that link.'));
    }
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

// ---------------------------------------------------------------- Edit profile

Future<bool?> showEditProfileSheet(BuildContext context, ProfileData p) => showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(CS.rLg))),
      builder: (_) => _EditSheet(profile: p),
    );

class _EditSheet extends StatefulWidget {
  final ProfileData profile;
  const _EditSheet({required this.profile});
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.name);
  late final _phone = TextEditingController(text: widget.profile.phone ?? '');
  late String _visibility = widget.profile.phoneVisibility;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Services.profile.save(_name.text.trim(), _phone.text.trim(), _visibility);
      if (mounted) {
        showMessage(context, 'Profile saved.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showError(context, e, onRetry: _save);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(CS.s24, CS.s24, CS.s24, CS.s24 + MediaQuery.of(context).viewInsets.bottom),
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Edit profile', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) {
                final t = (v ?? '').trim();
                return t.length < 2 ? 'Enter your name' : (t.length > 100 ? 'Keep it under 100 characters' : null);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number (optional)', hintText: '08012345678', prefixIcon: Icon(Icons.phone_outlined)),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return widget.profile.isLandlord && _visibility != 'hidden' ? 'Add a number, or set visibility to Hidden' : null;
                return isValidPhone(t) ? null : 'Use digits only, like 08012345678';
              },
            ),
            const SizedBox(height: 6),
            if (!widget.profile.isLandlord)
              Text('Only you and CampusStay reviewers can see your phone number. It is never shown to other users.', style: Theme.of(context).textTheme.bodySmall)
            else ...[
              const SizedBox(height: 6),
              const Text('Who can see my phone number?', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in phoneVisibilityLabels.entries)
                  ChoiceChip(label: Text(e.value), selected: _visibility == e.key, onSelected: (_) => setState(() => _visibility = e.key)),
              ]),
              const SizedBox(height: 6),
              Text(phoneVisibilityHelp[_visibility] ?? '', style: Theme.of(context).textTheme.bodySmall),
              const Text('Your email is never shown. You can change this any time.', style: TextStyle(color: CS.muted, fontSize: 12.5)),
            ],
            const SizedBox(height: 16),
            PrimaryButton(label: 'Save changes', loading: _busy, onPressed: _save),
          ]),
        ),
      );
}

// --------------------------------------------------------------- Notifications

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _f = Services.profile.notifications();
  void _reload() => setState(() => _f = Services.profile.notifications());

  Future<void> _markAll() async {
    try {
      await Services.profile.markAllRead();
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _tap(AppNotification n) async {
    if (n.read) return;
    try {
      await Services.profile.markRead(n.id);
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notifications'), actions: [TextButton(onPressed: _markAll, child: const Text('Mark all read'))]),
        body: FutureBuilder<List<AppNotification>>(
          future: _f,
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (s.hasError) return ErrorView(error: s.error!, onRetry: _reload);
            if (s.data!.isEmpty) {
              return const EmptyState(icon: Icons.notifications_none, title: 'Nothing new', message: 'Alerts about enquiries and your listings will show up here.');
            }
            return RefreshIndicator(
              onRefresh: () async {
                _reload();
                await _f;
              },
              child: ListView.separated(
                itemCount: s.data!.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (c, i) {
                  final n = s.data![i];
                  return ListTile(
                    onTap: () => _tap(n),
                    leading: CircleAvatar(
                      backgroundColor: CS.blueSoft,
                      child: Icon(n.kind == 'enquiry' ? Icons.chat_bubble_outline : Icons.notifications_none, color: CS.blue),
                    ),
                    title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w800)),
                    subtitle: Text('${n.body ?? ''}${n.body == null ? '' : '\n'}${fmtDateTime(n.createdAt)}'),
                    isThreeLine: n.body != null,
                    trailing: n.read ? null : const Icon(Icons.circle, size: 10, color: CS.blue),
                  );
                },
              ),
            );
          },
        ),
      );
}

// ------------------------------------------------------------- Change password

class ChangePasswordScreen extends StatefulWidget {
  final String email;
  const ChangePasswordScreen({super.key, required this.email});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false, _hide = true;
  String? _currentError;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _currentError = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Services.profile.changePassword(_current.text, _next.text);
      if (mounted) {
        showMessage(context, 'Password updated.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      if (classify(e).kind == AppErrorKind.invalidLogin) {
        setState(() => _currentError = 'That is not your current password.');
        _form.currentState!.validate();
      } else {
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Change password')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(CS.s24),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('For your security, enter your current password first.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              TextFormField(
                controller: _current,
                obscureText: _hide,
                decoration: InputDecoration(
                  labelText: 'Current password',
                  suffixIcon: IconButton(tooltip: _hide ? 'Show passwords' : 'Hide passwords', icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _hide = !_hide)),
                ),
                validator: (v) => _currentError ?? ((v ?? '').isEmpty ? 'Enter your current password' : null),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _next,
                obscureText: _hide,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (v) {
                  final t = v ?? '';
                  if (t.length < 8) return 'Use at least 8 characters';
                  if (t == _current.text) return 'Choose a password you have not used just now';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                obscureText: _hide,
                decoration: const InputDecoration(labelText: 'Confirm new password'),
                validator: (v) => v != _next.text ? 'The two passwords do not match' : null,
              ),
              const SizedBox(height: 24),
              PrimaryButton(label: 'Update password', loading: _busy, onPressed: _save),
            ]),
          ),
        ),
      );
}

// ----------------------------------------------------------- Privacy & Security

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});
  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  late Future<List<BlockedPerson>> _f = Services.profile.blocked();
  void _reload() => setState(() => _f = Services.profile.blocked());

  Future<void> _unblock(BlockedPerson b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Unblock this person?'),
        content: const Text('They will be able to message you again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Unblock')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Services.profile.unblock(b.id);
      if (mounted) showMessage(context, 'Unblocked.');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Privacy & Security')),
        body: ListView(padding: const EdgeInsets.all(CS.s16), children: [
          Container(
            padding: const EdgeInsets.all(CS.s16),
            decoration: BoxDecoration(color: CS.blueSoft, borderRadius: BorderRadius.circular(CS.rMd)),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('How your information is handled', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text('• Your email and phone number are never shown to other users.\n'
                  '• Verification documents are visible only to you and CampusStay reviewers.\n'
                  '• You can only message people through a listing, and you can report or block anyone.\n'
                  '• CampusStay never asks you to pay to list or to view a property.'),
            ]),
          ),
          const _H('Blocked people'),
          FutureBuilder<List<BlockedPerson>>(
            future: _f,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              if (s.hasError) return SizedBox(height: 260, child: ErrorView(error: s.error!, onRetry: _reload));
              if (s.data!.isEmpty) return const Padding(padding: EdgeInsets.all(8), child: Text('You have not blocked anyone.', style: TextStyle(color: CS.muted)));
              return Column(children: [
                for (final b in s.data!)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(backgroundColor: CS.surface, child: Icon(Icons.block, color: CS.muted)),
                    title: const Text('Blocked person'),
                    subtitle: Text('Blocked ${fmtDateTime(b.since)} · ID ${b.id.substring(0, 8)}'),
                    trailing: TextButton(onPressed: () => _unblock(b), child: const Text('Unblock')),
                  ),
              ]);
            },
          ),
        ]),
      );
}

class _H extends StatelessWidget {
  final String text;
  const _H(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(4, 22, 0, 8), child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)));
}

// -------------------------------------------------------------- Help & Support

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faq = [
    ('Is CampusStay free?', 'Yes. Listing a property and searching for accommodation are free. There are no listing fees and no commission.'),
    ('How do I contact a landlord?', 'Open a listing and tap Message to chat, or Book viewing to request a time. The landlord confirms or declines.'),
    ('What does Verified mean?', 'Verified means CampusStay reviewers checked the landlord\'s ID and proof of authority. Unverified means that has not happened yet, so be extra careful.'),
    ('How do I report a problem?', 'Use Report this listing on any listing, or the menu in a conversation to report or block a person.'),
  ];

  static const _tips = [
    'Always view the property in person, in daylight, before paying anything.',
    'Never pay to be shown a listing, and be wary of anyone who rushes you.',
    'Pay rent only against a receipt or signed agreement.',
    'Keep conversations inside CampusStay so there is a record if something goes wrong.',
  ];

  @override
  Widget build(BuildContext context) {
    final hasEmail = AppConfig.supportEmail.isNotEmpty;
    final hasWa = AppConfig.supportWhatsapp.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(padding: const EdgeInsets.all(CS.s16), children: [
        const _H('Contact us'),
        if (!hasEmail && !hasWa)
          const Text('Support contact details have not been set up yet. In the meantime, use Report on a listing or conversation and our team will review it.', style: TextStyle(color: CS.muted))
        else
          Row(children: [
            if (hasEmail)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openLink(context, Uri(scheme: 'mailto', path: AppConfig.supportEmail, queryParameters: {'subject': 'CampusStay support'})),
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('Email us'),
                ),
              ),
            if (hasEmail && hasWa) const SizedBox(width: 10),
            if (hasWa)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openLink(context, Uri.parse('https://wa.me/${AppConfig.supportWhatsapp.replaceAll(RegExp(r'[^0-9]'), '')}')),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp'),
                ),
              ),
          ]),
        const _H('Stay safe'),
        for (final t in _tips)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle_outline, size: 18, color: CS.green), const SizedBox(width: 8), Expanded(child: Text(t))])),
        const _H('Common questions'),
        for (final q in _faq)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CS.rMd), side: const BorderSide(color: CS.line)),
            child: ExpansionTile(
              shape: const Border(),
              title: Text(q.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(q.$2)],
            ),
          ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ About

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('About the app')),
        body: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (c, s) {
            final version = s.hasData ? '${s.data!.version} (${s.data!.buildNumber})' : '';
            return ListView(padding: const EdgeInsets.all(CS.s24), children: [
              const Center(child: LogoLockup(size: 64)),
              const SizedBox(height: 20),
              if (version.isNotEmpty) Center(child: Text('Version $version', style: Theme.of(context).textTheme.bodySmall)),
              const SizedBox(height: 20),
              const Text('CampusStay connects Nigerian students directly with landlords. Listings are free, there is no agent commission, and every listing is reviewed before students can see it.'),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms of use'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => AppConfig.termsUrl.isNotEmpty ? _openLink(context, Uri.parse(AppConfig.termsUrl)) : Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermsScreen())),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy policy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => AppConfig.privacyUrl.isNotEmpty ? _openLink(context, Uri.parse(AppConfig.privacyUrl)) : Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.article_outlined),
                title: const Text('Open-source licences'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(context: context, applicationName: 'CampusStay', applicationVersion: version),
              ),
            ]);
          },
        ),
      );
}
