import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/property_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../data/favourites_store.dart';
import '../../data/models.dart';
import '../../data/analytics.dart';
import '../../data/repository.dart';

class PropertyDetailScreen extends StatefulWidget {
  final String propertyId;
  const PropertyDetailScreen({super.key, required this.propertyId});
  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  late Future<Property> _f = Services.repo.property(widget.propertyId);
  final _page = PageController();

  @override
  void initState() {
    super.initState();
    Analytics.recordView(widget.propertyId);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _enquire(Property p) async {
    final text = await _askText(context, title: 'Message the landlord', hint: 'Hello, is this room still available?', action: 'Send');
    if (text == null || !mounted) return;
    try {
      await Services.repo.sendEnquiry(p.id, text);
      if (mounted) showMessage(context, 'Message sent. Find the reply under Messages.');
    } catch (e) {
      if (mounted) showMessage(context, _sendError(e), error: true);
    }
  }

  Future<void> _viewing(Property p) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      helpText: 'Preferred viewing date',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 11, minute: 0));
    if (time == null || !mounted) return;
    final note = await _askText(context, title: 'Add a note (optional)', hint: 'Anything the landlord should know', action: 'Request viewing', allowEmpty: true);
    if (note == null || !mounted) return;
    try {
      await Services.repo.requestViewing(p.id, DateTime(date.year, date.month, date.day, time.hour, time.minute), note);
      if (mounted) showMessage(context, 'Viewing requested. The landlord must confirm it before it is booked.');
    } catch (e) {
      if (mounted) showMessage(context, _sendError(e), error: true);
    }
  }

  Future<void> _report(Property p) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(title: const Text('Report this listing'), children: [
        for (final r in const ['Misleading or fake', 'Already rented', 'Suspicious landlord', 'Wrong price or location', 'Other'])
          SimpleDialogOption(onPressed: () => Navigator.pop(c, r), child: Text(r)),
      ]),
    );
    if (reason == null || !mounted) return;
    try {
      await Services.repo.report('property', p.id, reason, '');
      if (mounted) showMessage(context, 'Report sent. Our team will review it.');
    } catch (e) {
      if (mounted) showMessage(context, _sendError(e), error: true);
    }
  }

  String _sendError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('sign in') || s.contains('jwt') || s.contains('auth')) return 'Please sign in first.';
    if (s.contains('rate') || s.contains('too many')) return 'You are sending too fast. Try again later.';
    return 'Could not send. Check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: FutureBuilder<Property>(
          future: _f,
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (s.hasError) {
              return Scaffold(appBar: AppBar(), body: ErrorState(message: 'This listing could not be loaded. It may have been rented or removed.', onRetry: () => setState(() => _f = Services.repo.property(widget.propertyId))));
            }
            final p = s.data!;
            return Column(children: [
              Expanded(
                child: ListView(padding: EdgeInsets.zero, children: [
                  Stack(children: [
                    SizedBox(
                      height: 260,
                      child: p.photoUrls.isEmpty
                          ? const PropertyPhoto(height: 260)
                          : PageView(controller: _page, children: [for (final u in p.photoUrls) PropertyPhoto(url: u, height: 260)]),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(children: [
                          CircleAvatar(backgroundColor: Colors.white, child: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back, color: CS.ink), onPressed: () => Navigator.pop(context))),
                          const Spacer(),
                          ValueListenableBuilder<Set<String>>(
                            valueListenable: FavouritesStore.ids,
                            builder: (c, favs, _) => CircleAvatar(
                              backgroundColor: Colors.white,
                              child: IconButton(
                                tooltip: 'Save listing',
                                icon: Icon(favs.contains(p.id) ? Icons.favorite : Icons.favorite_border, color: favs.contains(p.id) ? CS.danger : CS.ink),
                                onPressed: () => FavouritesStore.toggle(p.id).catchError((_) {
                                  if (mounted) showMessage(context, 'Sign in to save listings.', error: true);
                                }),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                  Padding(
                    padding: const EdgeInsets.all(CS.s20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(p.title, style: Theme.of(context).textTheme.headlineMedium)),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: CS.muted),
                        const SizedBox(width: 4),
                        Expanded(child: Text(p.locationLabel, style: Theme.of(context).textTheme.bodySmall)),
                      ]),
                      const SizedBox(height: 12),
                      Text(p.rentLabel, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: CS.blue)),
                      const SizedBox(height: 10),
                      VerificationBadge(p.verification),
                      if (p.verification != 'verified')
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('Not yet verified by CampusStay. Always view the property before paying anything.', style: TextStyle(color: CS.muted, fontSize: 12.5)),
                        ),
                      const SizedBox(height: 20),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        Chip(label: Text(p.roomTypeLabel)),
                        for (final a in p.amenities) FacilityTile(a),
                      ]),
                      const SizedBox(height: 20),
                      Text('About this property', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(p.description.isEmpty ? 'No description provided.' : p.description, style: Theme.of(context).textTheme.bodyLarge),
                      if ((p.extraFeesNote ?? '').isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('Other compulsory fees', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(p.extraFeesNote!, style: Theme.of(context).textTheme.bodyLarge),
                      ],
                      const SizedBox(height: 16),
                      TextButton.icon(onPressed: () => _report(p), icon: const Icon(Icons.flag_outlined, size: 18), label: const Text('Report this listing')),
                    ]),
                  ),
                ]),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(CS.s16, CS.s8, CS.s16, CS.s12),
                  child: Row(children: [
                    Expanded(child: OutlineActionButton(label: 'Message', onPressed: () => _enquire(p))),
                    const SizedBox(width: 12),
                    Expanded(child: PrimaryButton(label: 'Book viewing', onPressed: () => _viewing(p))),
                  ]),
                ),
              ),
            ]);
          },
        ),
      );
}

Future<String?> _askText(BuildContext context, {required String title, required String hint, required String action, bool allowEmpty = false}) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, maxLines: 4, maxLength: 1000, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final t = c.text.trim();
            if (t.isEmpty && !allowEmpty) return;
            Navigator.pop(ctx, t);
          },
          child: Text(action),
        ),
      ],
    ),
  );
}
