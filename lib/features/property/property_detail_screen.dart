import 'package:flutter/material.dart';
import '../../core/errors.dart';
import 'package:latlong2/latlong.dart';
import '../../core/widgets/error_views.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/property_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../data/favourites_store.dart';
import '../../data/models.dart';
import '../../data/analytics.dart';
import '../../core/launch.dart';
import '../../core/share.dart';
import 'reviews_widgets.dart';
import '../../core/widgets/safety_widgets.dart';
import '../../core/widgets/map_widgets.dart';
import '../../core/widgets/property_details_widgets.dart';
import '../../data/location_models.dart';
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

  static bool _safetyShown = false; // once per app session

  Future<void> _enquire(Property p) async {
    if (!_safetyShown) {
      if (!await showSafetyTips(context) || !mounted) return;
      _safetyShown = true;
    }
    final text = await _askText(context, title: 'Message the landlord', hint: 'Hello, is this room still available?', action: 'Send');
    if (text == null || !mounted) return;
    try {
      await Services.repo.sendEnquiry(p.id, text);
      if (mounted) showMessage(context, 'Message sent. Find the reply under Messages.');
    } catch (e) {
      if (mounted) showError(context, e);
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
      if (mounted) showError(context, e);
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
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: FutureBuilder<Property>(
          future: _f,
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (s.hasError) {
              return Scaffold(appBar: AppBar(), body: ErrorView(error: s.error!, onRetry: () => setState(() => _f = Services.repo.property(widget.propertyId))));
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
                          CircleAvatar(backgroundColor: Colors.white, child: IconButton(tooltip: 'Share', icon: const Icon(Icons.share_outlined, color: CS.ink), onPressed: () => shareListing(context, p))),
                          const SizedBox(width: 8),
                          ValueListenableBuilder<Set<String>>(
                            valueListenable: FavouritesStore.ids,
                            builder: (c, favs, _) => CircleAvatar(
                              backgroundColor: Colors.white,
                              child: IconButton(
                                tooltip: 'Save listing',
                                icon: Icon(favs.contains(p.id) ? Icons.favorite : Icons.favorite_border, color: favs.contains(p.id) ? CS.danger : CS.ink),
                                onPressed: () => FavouritesStore.toggle(p.id).catchError((Object e) {
 if (context.mounted) showError(context, e);
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
                      _ReplySpeed(propertyId: p.id),
                      if (p.verification != 'verified')
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('Not yet verified by CampusStay. Always view the property before paying anything.', style: TextStyle(color: CS.muted, fontSize: 12.5)),
                        ),
                      const SizedBox(height: 20),
                      Text('Key details', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      PropertyFacts(extras: p.extras, roomTypeLabel: p.roomTypeLabel),
                      if (p.extras.landmark.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(children: [const Icon(Icons.place_outlined, size: 18, color: CS.muted), const SizedBox(width: 6), Expanded(child: Text(p.extras.landmark))]),
                      ],
                      const SizedBox(height: 20),
                      Text('Facilities', style: Theme.of(context).textTheme.titleMedium),
                      FacilitiesByCategory(codes: p.amenities),
                      const SizedBox(height: 20),
                      Text('About this property', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(p.description.isEmpty ? 'No description provided.' : p.description, style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 20),
                      _LocationSection(property: p),
                      if (p.extras.walkMinutes != null || p.extras.bikeFareNgn != null || p.extras.kekeFareNgn != null || p.extras.busFareNgn != null) ...[
                        const SizedBox(height: 20),
                        Text('Getting to school', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        TransportCard(extras: p.extras),
                      ],
                      const SizedBox(height: 20),
                      Text('Costs', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      CostsCard(rentLabel: p.rentLabel, rentNgn: p.rentNgn, extras: p.extras, otherFees: p.extraFeesNote),
                      const SizedBox(height: 20),
                      Text('House rules', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      RulesCard(extras: p.extras),
                      const SizedBox(height: 20),
                      ReviewsSection(propertyId: p.id),
                      const SizedBox(height: 20),
                      _ContactSection(propertyId: p.id),
                      const SizedBox(height: 16),
                      const SafetyChecklist(),
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


/// Approximate area for everyone; exact pin and address only once the landlord has confirmed your viewing.
class _LocationSection extends StatefulWidget {
  final Property property;
  const _LocationSection({required this.property});
  @override
  State<_LocationSection> createState() => _LocationSectionState();
}

class _LocationSectionState extends State<_LocationSection> {
  late Future<ExactLocation?> _f = Services.repo.exactLocation(widget.property.id);

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Location', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      FutureBuilder<ExactLocation?>(
        future: _f,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return Container(height: 220, decoration: BoxDecoration(color: CS.surface, borderRadius: BorderRadius.circular(CS.rMd)));
          if (s.hasError) {
            return Row(children: [
              const Expanded(child: Text('Could not load the map.', style: TextStyle(color: CS.muted))),
              TextButton(onPressed: () => setState(() => _f = Services.repo.exactLocation(p.id)), child: const Text('Try again')),
            ]);
          }
          final exact = s.data;
          if (exact != null) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ListingMap(center: LatLng(exact.lat, exact.lng), exact: true),
              if (exact.addressLine.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(exact.addressLine, style: const TextStyle(fontWeight: FontWeight.w700))),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: () => openExternal(context, mapsUri(exact.lat, exact.lng)), icon: const Icon(Icons.directions_outlined), label: const Text('Get directions')),
            ]);
          }
          if (p.approxLat != null && p.approxLng != null) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ListingMap(center: LatLng(p.approxLat!, p.approxLng!), exact: false),
              const SizedBox(height: 8),
              const Text('This is the approximate area. The landlord shares the exact address once your viewing is confirmed.', style: TextStyle(color: CS.muted, fontSize: 12.5)),
              TextButton.icon(onPressed: () => openExternal(context, mapsUri(p.approxLat!, p.approxLng!)), icon: const Icon(Icons.open_in_new, size: 16), label: const Text('Open area in Maps')),
            ]);
          }
          return const Text('The landlord has not pinned the location yet.', style: TextStyle(color: CS.muted));
        },
      ),
    ]);
  }
}

/// Call or WhatsApp, only when the landlord's own setting allows it. The server decides; the number
/// is fetched only when you tap, and every reveal is rate-limited and logged.
class _ContactSection extends StatefulWidget {
  final String propertyId;
  const _ContactSection({required this.propertyId});
  @override
  State<_ContactSection> createState() => _ContactSectionState();
}

class _ContactSectionState extends State<_ContactSection> {
  late final Future<String> _f = Services.repo.contactStatus(widget.propertyId);
  bool _busy = false;

  Future<void> _reach(bool whatsapp) async {
    setState(() => _busy = true);
    try {
      final phone = await Services.repo.revealPhone(widget.propertyId);
      if (!mounted) return;
      final uri = whatsapp
          ? Uri.parse('https://wa.me/${toInternationalPhone(phone)}?text=${Uri.encodeComponent('Hello, I saw your listing on CampusStay and I am interested.')}')
          : Uri(scheme: 'tel', path: phone);
      await openExternal(context, uri);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: _f,
        builder: (c, s) {
          if (!s.hasData) return const SizedBox.shrink(); // contact is optional, so never block the page on it
          switch (s.data) {
            case ContactStatus.available:
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Contact the landlord', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : () => _reach(false), icon: const Icon(Icons.call_outlined), label: const Text('Call'))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : () => _reach(true), icon: const Icon(Icons.chat_outlined), label: const Text('WhatsApp'))),
                ]),
              ]);
            case ContactStatus.locked:
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: CS.blueSoft, borderRadius: BorderRadius.circular(CS.rMd)),
                child: const Row(children: [
                  Icon(Icons.lock_outline, color: CS.blue),
                  SizedBox(width: 10),
                  Expanded(child: Text("The landlord's phone number unlocks after you send them a message or they confirm your viewing.")),
                ]),
              );
            default:
              return const SizedBox.shrink();
          }
        },
      );
}


/// "Usually replies within an hour": a rough bucket worked out on the server from real replies.
class _ReplySpeed extends StatefulWidget {
  final String propertyId;
  const _ReplySpeed({required this.propertyId});
  @override
  State<_ReplySpeed> createState() => _ReplySpeedState();
}

class _ReplySpeedState extends State<_ReplySpeed> {
  late final Future<String> _f = Services.repo.replySpeed(widget.propertyId);

  static const _text = {
    'within_hour': 'Usually replies within an hour',
    'within_hours': 'Usually replies within a few hours',
    'within_day': 'Usually replies within a day',
    'slow': 'Can take a few days to reply',
  };

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: _f,
        builder: (c, s) {
          if (s.hasError) {
            // Optional extra: never blocks the page, but the cause is not hidden.
            debugPrint('reply speed unavailable: ${classify(s.error!)}');
            return const SizedBox.shrink();
          }
          final t = _text[s.data];
          if (t == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [const Icon(Icons.bolt, size: 16, color: CS.green), const SizedBox(width: 4), Text(t, style: const TextStyle(color: CS.green, fontWeight: FontWeight.w700, fontSize: 13))]),
          );
        },
      );
}
