import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../core/config.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/launch.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/error_views.dart';
import '../../core/widgets/landlord_theme.dart';
import '../../core/widgets/map_widgets.dart';
import '../../core/widgets/property_details_widgets.dart';
import '../../core/widgets/school_picker.dart';
import '../../core/widgets/state_views.dart';
import '../../data/landlord_models.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

class _Photo {
  final PhotoRef ref;
  final Uint8List? bytes;
  _Photo(this.ref, [this.bytes]);
}

/// Guided flow written for people who are not comfortable with phones or forms:
/// plain questions, big buttons, examples, one-tap amounts and suggested wording.
/// The draft is saved to the server as you go, so nothing is lost.
class ListingWizard extends StatefulWidget {
  final LandlordListing? existing;
  const ListingWizard({super.key, this.existing});
  @override
  State<ListingWizard> createState() => _ListingWizardState();
}

class _ListingWizardState extends State<ListingWizard> {
  static const _titles = ['Your place', 'Location', 'Space', 'Costs', 'Features', 'Photos', 'Verification', 'Review'];
  static const _subtitles = [
    'Tell us what you are renting out.',
    'Help students find you and get to school.',
    'Rooms, bathroom and who it is for.',
    'What a student will pay.',
    'What your place has, and your rules.',
    'Show the real place.',
    'Prove who you are.',
    'Check everything, then send it.',
  ];
  static const _maxPhotos = 10;
  static const _docTypes = [
    ('id_card', 'ID card', "NIN slip, driver's licence or passport"),
    ('agreement', 'Landlord agreement or authorisation', 'Shows you are allowed to rent this property'),
    ('property_document', 'Property documents (optional)', 'Receipt, survey plan or utility bill'),
  ];
  static const _types = [
    ('single_room', 'A room', 'One room in a house. Toilet and kitchen are shared.', Icons.bed_outlined),
    ('self_contain', 'Self-contain', 'Own room with its own toilet and a small kitchen area.', Icons.meeting_room_outlined),
    ('apartment', 'Flat', 'A flat with bedroom, parlour and kitchen.', Icons.apartment),
    ('shared_room', 'Shared room', 'A room that two or more students share.', Icons.people_outline),
    ('hostel', 'Hostel bed space', 'One bed space in a hostel with many students.', Icons.hotel_outlined),
  ];

  final _formBasics = GlobalKey<FormState>();
  final _formLocation = GlobalKey<FormState>();
  final _formCosts = GlobalKey<FormState>();
  final _formFeatures = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _area = TextEditingController();
  final _landmark = TextEditingController();
  final _rent = TextEditingController();
  final _bike = TextEditingController();
  final _keke = TextEditingController();
  final _bus = TextEditingController();
  final _address = TextEditingController();
  final _caution = TextEditingController();
  final _service = TextEditingController();
  final _fees = TextEditingController();
  final _lease = TextEditingController();
  final _rules = TextEditingController();
  final _desc = TextEditingController();
  final _picker = ImagePicker();

  LatLng? _pin;
  bool _hadLocation = false;
  String? _universityId;
  String _schoolLabel = '';
  String _schoolShort = '';
  String _schoolOther = '';
  bool _schoolMissing = false, _typeMissing = false;
  String _period = 'year';
  String? _roomType;
  double? _distanceKm; // kept from older listings; new listings use walking time instead
  int? _walk;
  int _bedrooms = 1, _bathrooms = 1, _occupants = 1, _spaces = 1;
  String _bathroomType = 'private', _kitchenType = 'shared', _furnishing = 'unfurnished', _gender = 'any';
  String? _electricity, _water;
  DateTime? _availableFrom;
  bool _instalments = false, _liveOnSite = false, _visitors = true, _pets = false;

  int _step = 0;
  bool _busy = false;
  String? _id;
  String _status = 'draft';
  final _photos = <_Photo>[];
  final _amen = <String>{};
  final _docs = <String, bool>{};

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e == null) return;
    final x = e.extras;
    _id = e.id;
    _title.text = e.title;
    _area.text = e.area;
    _landmark.text = x.landmark;
    _rent.text = e.rentNgn.toString();
    _bike.text = x.bikeFareNgn?.toString() ?? '';
    _keke.text = x.kekeFareNgn?.toString() ?? '';
    _bus.text = x.busFareNgn?.toString() ?? '';
    _caution.text = x.cautionFeeNgn?.toString() ?? '';
    _service.text = x.serviceChargeNgn?.toString() ?? '';
    _fees.text = e.extraFees ?? '';
    _lease.text = x.leaseMonths?.toString() ?? '';
    _rules.text = x.houseRules;
    _desc.text = e.description;
    _universityId = e.universityId;
    _schoolLabel = e.school;
    _schoolShort = e.university;
    _schoolOther = x.schoolOther;
    _period = e.rentPeriod;
    _roomType = e.roomType;
    _distanceKm = e.distanceKm;
    _walk = x.walkMinutes;
    _bedrooms = x.bedrooms;
    _bathrooms = x.bathrooms;
    _occupants = x.maxOccupants;
    _spaces = x.spacesAvailable ?? 1;
    _bathroomType = x.bathroomType;
    _kitchenType = x.kitchenType;
    _furnishing = x.furnishing;
    _gender = x.genderPreference;
    _electricity = x.electricityBilling;
    _water = x.waterBilling;
    _availableFrom = x.availableFrom;
    _instalments = x.allowsInstalments;
    _liveOnSite = x.landlordLivesOnSite;
    _visitors = x.visitorsAllowed;
    _pets = x.petsAllowed;
    _photos.addAll(e.photos.map((p) => _Photo(p)));
    _amen.addAll(e.amenities);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLocation());
  }

  Future<void> _loadLocation() async {
    try {
      final l = await Services.landlord.myLocation(_id!);
      if (!mounted || l == null) return;
      setState(() {
        _pin = LatLng(l.lat, l.lng);
        _address.text = l.addressLine;
        _hadLocation = true;
      });
    } catch (e) {
      if (mounted) showError(context, e, onRetry: _loadLocation);
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _area, _landmark, _rent, _bike, _keke, _bus, _address, _caution, _service, _fees, _lease, _rules, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _n(TextEditingController c) => int.tryParse(c.text.trim());

  PropertyExtras _extras() => PropertyExtras(
        schoolOther: _universityId == null ? _schoolOther : '',
        landmark: _landmark.text.trim(),
        bedrooms: _bedrooms,
        bathrooms: _bathrooms,
        bathroomType: _bathroomType,
        kitchenType: _kitchenType,
        furnishing: _furnishing,
        genderPreference: _gender,
        maxOccupants: _occupants,
        availableFrom: _availableFrom,
        leaseMonths: _n(_lease),
        allowsInstalments: _instalments,
        cautionFeeNgn: _n(_caution),
        serviceChargeNgn: _n(_service),
        landlordLivesOnSite: _liveOnSite,
        visitorsAllowed: _visitors,
        petsAllowed: _pets,
        houseRules: _rules.text.trim(),
        walkMinutes: _walk,
        bikeFareNgn: _n(_bike),
        kekeFareNgn: _n(_keke),
        busFareNgn: _n(_bus),
        electricityBilling: _electricity,
        waterBilling: _water,
        spacesAvailable: _spaces,
      );

  ListingInput _input() => ListingInput(
        title: _title.text.trim(),
        description: _desc.text.trim(),
        area: _area.text.trim(),
        rentPeriod: _period,
        roomType: _roomType!,
        universityId: _universityId,
        extras: _extras(),
        rentNgn: int.parse(_rent.text.trim()),
        distanceKm: _distanceKm,
        extraFees: _fees.text.trim().isEmpty ? null : _fees.text.trim(),
      );

  Future<void> _next() async {
    if (_busy) return;
    final r = Services.landlord;
    setState(() => _busy = true);
    try {
      switch (_step) {
        case 0:
          final ok = _formBasics.currentState!.validate();
          final schoolOk = _universityId != null || _schoolOther.isNotEmpty;
          final typeOk = _roomType != null;
          setState(() {
            _schoolMissing = !schoolOk;
            _typeMissing = !typeOk;
          });
          if (!ok || !schoolOk || !typeOk) return;
          _id = await r.saveDraft(_id, _input());
          break;
        case 1:
          if (!_formLocation.currentState!.validate()) return;
          _id = await r.saveDraft(_id, _input());
          if (_pin != null) {
            await r.saveLocation(_id!, _pin!.latitude, _pin!.longitude, _address.text.trim());
            _hadLocation = true;
          } else if (_hadLocation) {
            await r.clearLocation(_id!);
            _hadLocation = false;
          }
          break;
        case 2:
          _id = await r.saveDraft(_id, _input());
          break;
        case 3:
          if (!_formCosts.currentState!.validate()) return;
          _id = await r.saveDraft(_id, _input());
          break;
        case 4:
          if (!_formFeatures.currentState!.validate()) return;
          _id = await r.saveDraft(_id, _input());
          await r.setAmenities(_id!, _amen.toList());
          break;
        case 5:
          if (_photos.isEmpty) {
            showMessage(context, 'Please add at least one photo of the property.', error: true);
            return;
          }
          break;
        case 6:
          _status = (await r.myListing(_id!)).moderation;
          break;
        case 7:
          await _finish();
          return;
      }
      if (mounted) setState(() => _step++);
    } catch (e) {
      if (mounted) showError(context, e, onRetry: _next);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _canSubmit => ['draft', 'needs_changes', 'rejected'].contains(_status);

  Future<void> _finish() async {
    if (_canSubmit) {
      await Services.landlord.submitForReview(_id!);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Sent for review'),
          content: const Text('Thank you. Our team will check your listing before students can see it. You can follow its progress under My listings.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );
    } else {
      final now = await Services.landlord.myListing(_id!);
      if (!mounted) return;
      showMessage(context, now.moderation == 'pending' ? 'Changes saved. The listing is back in review.' : 'Changes saved.');
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _chooseSchool() async {
    final r = await pickSchool(context, allowOther: true);
    if (r == null) return;
    setState(() {
      _schoolMissing = false;
      if (r.school != null) {
        _universityId = r.school!.id;
        _schoolLabel = '${r.school!.shortName} · ${r.school!.name}';
        _schoolShort = r.school!.shortName;
        _schoolOther = '';
      } else if (r.other != null) {
        _universityId = null;
        _schoolOther = r.other!;
        _schoolLabel = r.other!;
        _schoolShort = r.other!;
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: _availableFrom ?? now, firstDate: now.subtract(const Duration(days: 1)), lastDate: now.add(const Duration(days: 730)), helpText: 'Available from');
    if (d != null) setState(() => _availableFrom = d);
  }

  Future<void> _pickPhotos() async {
    final room = _maxPhotos - _photos.length;
    if (room <= 0) {
      showMessage(context, 'You can add up to $_maxPhotos photos.', error: true);
      return;
    }
    final files = await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
    if (files.isEmpty) return;
    setState(() => _busy = true);
    try {
      for (final f in files.take(room)) {
        final bytes = await f.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          if (mounted) showError(context, const AppException(AppErrorKind.fileTooLarge));
          continue;
        }
        final ref = await Services.landlord.addPhoto(_id!, bytes, f.name, _photos.length);
        if (mounted) setState(() => _photos.add(_Photo(ref, bytes)));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto(_Photo p) async {
    try {
      await Services.landlord.removePhoto(_id!, p.ref);
      if (mounted) setState(() => _photos.remove(p));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _pickDoc(String type) async {
    final f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 2000);
    if (f == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await f.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) throw const AppException(AppErrorKind.fileTooLarge);
      await Services.landlord.uploadVerificationDoc(_id!, type, bytes, f.name);
      if (mounted) setState(() => _docs[type] = true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _help() => showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Need help?'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('• Take your time. Everything is saved as you go.\n'
                  '• You can close this page and come back later from My listings.\n'
                  '• Tap the examples and amounts to fill in a box for you.\n'
                  '• If you are not sure about something, you can leave it out and fix it later.\n'
                  '• Listing is free. Nobody should ask you to pay to list.'),
              if (AppConfig.supportEmail.isNotEmpty || AppConfig.supportWhatsapp.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Talk to a person', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (AppConfig.supportWhatsapp.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => openExternal(context, Uri.parse('https://wa.me/${AppConfig.supportWhatsapp.replaceAll(RegExp(r'[^0-9]'), '')}')),
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('WhatsApp us'),
                  ),
                if (AppConfig.supportEmail.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => openExternal(context, Uri(scheme: 'mailto', path: AppConfig.supportEmail)),
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('Email us'),
                  ),
              ],
            ]),
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
        ),
      );

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // A little larger text for everyone on this flow.
    final scale = math.min(1.6, 1.1 * mq.textScaler.scale(1.0));
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(scale)),
      child: LandlordThemed(
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.existing == null ? 'Add property' : 'Edit property'),
            leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context, _id != null)),
            actions: [TextButton.icon(onPressed: _help, icon: const Icon(Icons.help_outline), label: const Text('Help'))],
          ),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(CS.s16, 0, CS.s16, CS.s8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  for (var i = 0; i < _titles.length; i++)
                    Expanded(
                      child: Container(
                        height: 6,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(color: i <= _step ? CS.green : CS.line, borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                ]),
                const SizedBox(height: 10),
                Text('Step ${_step + 1} of ${_titles.length}', style: Theme.of(context).textTheme.bodySmall),
                Text(_titles[_step], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CS.ink)),
                Text(_subtitles[_step], style: const TextStyle(color: CS.muted)),
              ]),
            ),
            Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(CS.s16), child: _body())),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(CS.s16, CS.s8, CS.s16, CS.s12),
                child: Row(children: [
                  if (_step > 0 && !_busy)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(height: 56, child: OutlinedButton(onPressed: () => setState(() => _step--), child: const Text('Back'))),
                    ),
                  Expanded(
                    child: PrimaryButton(
                      label: _step == 7 ? (_canSubmit ? 'Send for review' : 'Save changes') : 'Continue',
                      color: CS.green,
                      loading: _busy,
                      onPressed: _next,
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _body() => switch (_step) {
        0 => _basics(),
        1 => _locationStep(),
        2 => _space(),
        3 => _costs(),
        4 => _features(),
        5 => _photosStep(),
        6 => _verification(),
        _ => _review(),
      };

  // ---------------------------------------------------------------- helpers

  Widget _h(String t, [String? sub]) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, style: Theme.of(context).textTheme.bodySmall)),
        ]),
      );

  Widget _choices(Map<String, String> options, String? value, void Function(String) on) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final e in options.entries) ChoiceChip(label: Text(e.value, style: const TextStyle(fontSize: 15.5)), selected: value == e.key, onSelected: (_) => setState(() => on(e.key)))],
      );

  Widget _counter(String label, int value, int min, int max, void Function(int) on, {String? hint}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
              if (hint != null) Text(hint, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          IconButton.outlined(tooltip: 'Fewer', onPressed: value > min ? () => setState(() => on(value - 1)) : null, icon: const Icon(Icons.remove)),
          SizedBox(width: 46, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
          IconButton.outlined(tooltip: 'More', onPressed: value < max ? () => setState(() => on(value + 1)) : null, icon: const Icon(Icons.add)),
        ]),
      );

  Widget _switch(String title, String sub, bool v, void Function(bool) on) =>
      SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)), subtitle: Text(sub), value: v, onChanged: (x) => setState(() => on(x)));

  String? _optMoney(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    return (n == null || n < 0 || n >= 100000000) ? 'Enter an amount in naira' : null;
  }

  String? _fare(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    return (n == null || n < 0 || n > 100000) ? 'Enter a fare up to ₦100,000' : null;
  }

  /// A money box that shows the amount with commas as you type and offers one-tap amounts.
  Widget _money(TextEditingController c, String label, {String? helper, List<int> quick = const [], String? Function(String?)? validator, bool big = false}) {
    final n = int.tryParse(c.text.trim());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextFormField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(fontSize: big ? 24 : 18, fontWeight: FontWeight.w700),
        decoration: InputDecoration(labelText: label, prefixText: '₦ ', helperText: helper, helperMaxLines: 3),
        onChanged: (_) => setState(() {}),
        validator: validator,
      ),
      if (n != null && n >= 1000) Padding(padding: const EdgeInsets.only(top: 4, left: 4), child: Text('₦${formatNaira(n)}', style: const TextStyle(color: CS.green, fontWeight: FontWeight.w800, fontSize: 16))),
      if (quick.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(spacing: 8, runSpacing: 4, children: [
            for (final q in quick) ActionChip(label: Text('₦${formatNaira(q)}'), onPressed: () => setState(() => c.text = '$q')),
          ]),
        ),
    ]);
  }

  String get _typeName => _roomType == null ? 'Room' : {'single_room': 'Room', 'self_contain': 'Self-contain', 'apartment': 'Flat', 'shared_room': 'Shared room', 'hostel': 'Hostel bed space'}[_roomType]!;

  String? get _suggestedTitle {
    if (_roomType == null) return null;
    final where = _schoolShort.isNotEmpty ? ' near $_schoolShort' : (_area.text.trim().isNotEmpty ? ' in ${_area.text.trim()}' : '');
    return '$_typeName$where';
  }

  String get _suggestedDescription {
    final b = StringBuffer('A ${_furnishing == 'furnished' ? 'furnished ' : _furnishing == 'semi_furnished' ? 'semi-furnished ' : ''}${_typeName.toLowerCase()}');
    if (_area.text.trim().isNotEmpty) b.write(' in ${_area.text.trim()}');
    if (_schoolShort.isNotEmpty) b.write(', ${_walk != null ? '$_walk minutes on foot from' : 'close to'} $_schoolShort');
    b.write('. ');
    if (_bedrooms > 0) b.write('$_bedrooms bedroom${_bedrooms == 1 ? '' : 's'}, ');
    b.write('${_bathroomType == 'private' ? 'private' : 'shared'} bathroom');
    if (_kitchenType != 'none') b.write(' and ${_kitchenType == 'private' ? 'private' : 'shared'} kitchen');
    b.write('. ');
    final names = [for (final a in amenityCatalog) if (_amen.contains(a.code)) a.label.toLowerCase()];
    if (names.isNotEmpty) b.write('It has ${names.take(6).join(', ')}. ');
    b.write('Quiet and safe for students.');
    return b.toString();
  }

  // ----------------------------------------------------------------- step 1

  Widget _basics() => Form(
        key: _formBasics,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.existing?.moderation == 'approved')
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(CS.rMd)),
              child: const Text('Changing key details sends this listing back for review.', style: TextStyle(fontSize: 13)),
            ),
          _h('What are you renting out?'),
          if (_typeMissing) const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Please tap one.', style: TextStyle(color: CS.danger, fontWeight: FontWeight.w700))),
          for (final t in _types)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(CS.rMd),
                onTap: () => setState(() {
                  _roomType = t.$1;
                  _typeMissing = false;
                  // Sensible starting answers so fewer questions need changing.
                  if (t.$1 == 'self_contain' || t.$1 == 'apartment') {
                    _bathroomType = 'private';
                    _kitchenType = t.$1 == 'apartment' ? 'private' : 'shared';
                  } else if (t.$1 == 'hostel' || t.$1 == 'shared_room') {
                    _bedrooms = 0;
                    _occupants = t.$1 == 'hostel' ? 4 : 2;
                    _bathroomType = 'shared';
                  } else {
                    _bathroomType = 'shared';
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(CS.rMd),
                    border: Border.all(color: _roomType == t.$1 ? CS.green : CS.line, width: _roomType == t.$1 ? 2.5 : 1),
                    color: _roomType == t.$1 ? CS.greenSoft : CS.bg,
                  ),
                  child: Row(children: [
                    Icon(t.$4, size: 32, color: CS.green),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.$2, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        Text(t.$3, style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ),
                    if (_roomType == t.$1) const Icon(Icons.check_circle, color: CS.green, size: 28),
                  ]),
                ),
              ),
            ),
          _h('Which school is it near?', 'Any university, polytechnic or college in Nigeria.'),
          InkWell(
            borderRadius: BorderRadius.circular(CS.rMd),
            onTap: _chooseSchool,
            child: InputDecorator(
              decoration: InputDecoration(
                errorText: _schoolMissing ? 'Please choose a school, or add its name' : null,
                suffixIcon: const Icon(Icons.search),
              ),
              child: Text(_schoolLabel.isEmpty ? 'Tap here to find the school' : _schoolLabel, style: TextStyle(color: _schoolLabel.isEmpty ? CS.muted : CS.ink, fontSize: 17)),
            ),
          ),
          _h('Which town or area?'),
          TextFormField(
            controller: _area,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontSize: 17),
            decoration: const InputDecoration(hintText: 'e.g. Ado-Ekiti, Ajilosun'),
            onChanged: (_) => setState(() {}),
            validator: (v) => (v ?? '').trim().length < 2 ? 'Please enter the town or area' : null,
          ),
          _h('What would you like to call it?', 'A short name students will see.'),
          TextFormField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 17),
            decoration: InputDecoration(hintText: _suggestedTitle ?? 'e.g. Self-contain near the campus gate'),
            validator: (v) => (v ?? '').trim().length < 5 ? 'Please enter at least 5 letters' : ((v ?? '').trim().length > 120 ? 'Keep it under 120 letters' : null),
          ),
          if (_suggestedTitle != null && _title.text.trim().isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(avatar: const Icon(Icons.auto_awesome, size: 18), label: Text('Use "${_suggestedTitle!}"'), onPressed: () => setState(() => _title.text = _suggestedTitle!)),
            ),
          _h('How much is the rent?'),
          _money(_rent, 'Rent', big: true, validator: (v) {
            final n = int.tryParse((v ?? '').trim());
            return (n == null || n <= 0) ? 'Please enter the rent' : (n >= 100000000 ? 'That amount is too large' : null);
          }),
          const SizedBox(height: 8),
          _choices(const {'year': 'Per year', 'month': 'Per month'}, _period, (v) => _period = v),
          const Padding(padding: EdgeInsets.only(top: 6), child: Text('Most places near campuses charge per year.', style: TextStyle(color: CS.muted, fontSize: 13))),
        ]),
      );

  // ----------------------------------------------------------------- step 2

  Widget _locationStep() => Form(
        key: _formLocation,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _h('How far is it from the school?', 'Tap the one that is closest. A guess is fine.'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in const [(5, 'Under 5 min'), (10, 'About 10 min'), (15, 'About 15 min'), (20, 'About 20 min'), (30, '30 min or more')])
              ChoiceChip(label: Text('${o.$2} on foot', style: const TextStyle(fontSize: 15.5)), selected: _walk == o.$1, onSelected: (_) => setState(() => _walk = o.$1)),
            ChoiceChip(label: const Text("I'm not sure", style: TextStyle(fontSize: 15.5)), selected: _walk == null, onSelected: (_) => setState(() => _walk = null)),
          ]),
          _h('What does transport to the school cost?', 'Optional. Students like to know. Tap an amount or type your own.'),
          _money(_bike, 'Okada (bike) from here to the school gate', quick: const [100, 200, 300, 500, 1000], validator: _fare),
          const SizedBox(height: 14),
          _money(_keke, 'Keke (tricycle) to the school gate', quick: const [100, 150, 200, 300], validator: _fare),
          const SizedBox(height: 14),
          _money(_bus, 'Bus or taxi to the school gate', quick: const [100, 200, 300, 500], validator: _fare),
          _h('Any landmark to help people find you?', 'Optional.'),
          TextFormField(
            controller: _landmark,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 17),
            decoration: const InputDecoration(hintText: 'e.g. Opposite the main gate, behind the filling station'),
          ),
          _h('Show it on the map', 'Optional. Students only see a rough area. The exact spot is shared only after you confirm their viewing.'),
          LocationPicker(initial: _pin, onChanged: (p) => setState(() => _pin = p)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _address,
            maxLength: 200,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontSize: 17),
            decoration: const InputDecoration(labelText: 'House number and street (optional)', helperText: 'Private. Shared only after you confirm a viewing.'),
          ),
        ]),
      );

  // ----------------------------------------------------------------- step 3

  Widget _space() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _counter('Bedrooms', _bedrooms, 0, 20, (v) => _bedrooms = v, hint: '0 means a bed space or a single room'),
        _counter('Bathrooms', _bathrooms, 0, 20, (v) => _bathrooms = v),
        _counter('Most people allowed', _occupants, 1, 30, (v) => _occupants = v, hint: 'Counting everyone who will live there'),
        _counter('Rooms or bed spaces to rent', _spaces, 1, 200, (v) => _spaces = v, hint: 'Use 1 if it is just one room. For a hostel, count the free bed spaces.'),
        _h('The bathroom is…', 'Private means only your tenant uses it.'),
        _choices(const {'private': 'Private', 'shared': 'Shared'}, _bathroomType, (v) => _bathroomType = v),
        _h('The kitchen is…'),
        _choices(const {'private': 'Private', 'shared': 'Shared', 'none': 'No kitchen'}, _kitchenType, (v) => _kitchenType = v),
        _h('Is it furnished?', 'Furnished means bed, wardrobe and so on are already there.'),
        _choices(furnishingLabels, _furnishing, (v) => _furnishing = v),
        _h('Who is it for?', 'Choosing one side limits who can find this listing.'),
        _choices(const {'any': 'Anyone', 'male_only': 'Male students', 'female_only': 'Female students'}, _gender, (v) => _gender = v),
        _h('When can someone move in?'),
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.event),
          label: Text(_availableFrom == null ? 'Available now (tap to pick a date)' : fmtDate(_availableFrom!)),
        ),
        if (_availableFrom != null) TextButton(onPressed: () => setState(() => _availableFrom = null), child: const Text('Say "available now" instead')),
        const SizedBox(height: 8),
        _switch('I live on the property', 'Tell students if you live in the same compound.', _liveOnSite, (v) => _liveOnSite = v),
      ]);

  // ----------------------------------------------------------------- step 4

  Widget _costs() {
    final rent = _n(_rent) ?? 0, caution = _n(_caution) ?? 0, service = _n(_service) ?? 0;
    final first = rent + caution + service;
    return Form(
      key: _formCosts,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Be clear about every cost. Students trust listings that show the full amount.', style: TextStyle(color: CS.muted)),
        _h('Caution fee', 'A refundable deposit, if you take one. Leave empty if none.'),
        _money(_caution, 'Caution fee', quick: const [10000, 20000, 30000, 50000], validator: _optMoney),
        _h('Service charge', 'For cleaning, security or waste, if any.'),
        _money(_service, 'Service charge', quick: const [5000, 10000, 20000], validator: _optMoney),
        _h('Light (electricity)'),
        _choices(electricityLabels, _electricity, (v) => _electricity = v),
        _h('Water'),
        _choices(waterLabels, _water, (v) => _water = v),
        _h('Any other fee?', 'e.g. agreement fee. Optional.'),
        TextFormField(
          controller: _fees,
          maxLines: 3,
          maxLength: 1000,
          style: const TextStyle(fontSize: 17),
          decoration: const InputDecoration(hintText: 'Write it here, with the amount'),
        ),
        _h('Shortest stay', 'Optional. In months.'),
        TextFormField(
          controller: _lease,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 18),
          decoration: const InputDecoration(hintText: 'e.g. 12'),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return null;
            final n = int.tryParse(t);
            return (n == null || n < 1 || n > 60) ? 'Enter 1 to 60 months' : null;
          },
        ),
        const SizedBox(height: 8),
        _switch('Students can pay in instalments', 'Turn on if they can pay in parts instead of all at once.', _instalments, (v) => _instalments = v),
        if (rent > 0)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: CS.greenSoft, borderRadius: BorderRadius.circular(CS.rMd)),
            child: Text('A student pays about ₦${formatNaira(first)} to move in (rent${caution > 0 ? ' + caution fee' : ''}${service > 0 ? ' + service charge' : ''}).',
                style: const TextStyle(color: CS.green, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
      ]),
    );
  }

  // ----------------------------------------------------------------- step 5

  Widget _features() => Form(
        key: _formFeatures,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tap everything your place has. Students can search by these.', style: TextStyle(color: CS.muted)),
          for (final cat in amenityCategoryLabels.entries) ...[
            _h(cat.value),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final a in amenityCatalog)
                if (a.category == cat.key)
                  FilterChip(
                    avatar: Icon(a.icon, size: 19, color: _amen.contains(a.code) ? Colors.white : CS.green),
                    label: Text(a.label, style: TextStyle(fontSize: 15, color: _amen.contains(a.code) ? Colors.white : CS.ink)),
                    selected: _amen.contains(a.code),
                    showCheckmark: false,
                    selectedColor: CS.green,
                    onSelected: (v) => setState(() => v ? _amen.add(a.code) : _amen.remove(a.code)),
                  ),
            ]),
          ],
          const SizedBox(height: 8),
          Text('${_amen.length} chosen', style: Theme.of(context).textTheme.bodySmall),
          _h('Your house rules'),
          _switch('Visitors are allowed', 'Friends and family can visit.', _visitors, (v) => _visitors = v),
          _switch('Pets are allowed', 'Students may keep pets.', _pets, (v) => _pets = v),
          TextFormField(
            controller: _rules,
            maxLines: 3,
            maxLength: 1000,
            style: const TextStyle(fontSize: 17),
            decoration: const InputDecoration(labelText: 'Other rules (optional)', hintText: 'e.g. No loud music after 10pm'),
          ),
          _h('Describe your place', 'A few sentences. What is it like to live there?'),
          TextFormField(
            controller: _desc,
            maxLines: 6,
            maxLength: 4000,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 17),
            decoration: const InputDecoration(hintText: 'The room, the compound, the neighbourhood…'),
            onChanged: (_) => setState(() {}),
            validator: (v) => (v ?? '').trim().length < 20 ? 'Please write at least 20 letters so students know what to expect' : null,
          ),
          if (_desc.text.trim().isEmpty)
            OutlinedButton.icon(
              onPressed: () => setState(() => _desc.text = _suggestedDescription),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Write it for me'),
            ),
          if (_desc.text.trim().isEmpty) const Padding(padding: EdgeInsets.only(top: 6), child: Text('We will use your answers so far. You can change the words afterwards.', style: TextStyle(color: CS.muted, fontSize: 13))),
        ]),
      );

  // ----------------------------------------------------------------- step 6

  Widget _photosStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Take clear photos of the real place. Never use photos of somewhere else.', style: TextStyle(color: CS.muted)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in const ['The room', 'The bathroom', 'The kitchen', 'Outside the building'])
            Chip(avatar: const Icon(Icons.photo_camera_outlined, size: 16), label: Text(t)),
        ]),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final p in _photos)
              Stack(fit: StackFit.expand, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(CS.rSm),
                  child: p.bytes != null
                      ? Image.memory(p.bytes!, fit: BoxFit.cover)
                      : (p.ref.url != null ? Image.network(p.ref.url!, fit: BoxFit.cover) : Container(color: CS.surface, child: const Icon(Icons.image_outlined, color: CS.muted))),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: InkWell(
                    onTap: _busy ? null : () => _removePhoto(p),
                    child: const CircleAvatar(radius: 14, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 16, color: Colors.white)),
                  ),
                ),
              ]),
            if (_photos.length < _maxPhotos)
              InkWell(
                onTap: _busy ? null : _pickPhotos,
                child: Container(
                  decoration: BoxDecoration(color: CS.greenSoft, borderRadius: BorderRadius.circular(CS.rSm), border: Border.all(color: CS.green)),
                  child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_a_photo_outlined, color: CS.green, size: 30),
                    SizedBox(height: 4),
                    Text('Add photos', style: TextStyle(color: CS.green, fontWeight: FontWeight.w800, fontSize: 13)),
                  ]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text('${_photos.length} of $_maxPhotos. The first photo is the cover. Each photo up to 5 MB. Listings with 4 or more photos get more enquiries.', style: Theme.of(context).textTheme.bodySmall),
      ]);

  // ----------------------------------------------------------------- step 7

  Widget _verification() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Upload a photo of your ID and proof that you can rent this property. Our team checks them before your listing is marked Verified. Only you and our review team can see these files. Students never can.', style: TextStyle(color: CS.muted)),
        const SizedBox(height: 16),
        for (final d in _docTypes)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CS.rMd), side: const BorderSide(color: CS.line)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: Icon(_docs[d.$1] == true ? Icons.check_circle : Icons.upload_file_outlined, color: _docs[d.$1] == true ? CS.green : CS.muted, size: 30),
              title: Text(d.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(_docs[d.$1] == true ? 'Uploaded. Waiting for review.' : d.$3),
              trailing: TextButton(onPressed: _busy ? null : () => _pickDoc(d.$1), child: Text(_docs[d.$1] == true ? 'Replace' : 'Upload')),
            ),
          ),
        const SizedBox(height: 8),
        const Text('You can skip this now. Listings without documents are shown to students as Unverified.', style: TextStyle(fontSize: 13.5, color: CS.muted)),
      ]);

  // ----------------------------------------------------------------- step 8

  Widget _review() {
    final rent = int.tryParse(_rent.text.trim()) ?? 0;
    final x = _extras();
    final rentLabel = '₦${formatNaira(rent)}/${_period == 'month' ? 'month' : 'year'}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(CS.rLg), border: Border.all(color: CS.line), boxShadow: CS.shadow, color: CS.bg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_title.text.trim(), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('${_area.text.trim()}${_schoolLabel.isEmpty ? '' : ' · near $_schoolLabel'}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(rentLabel, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CS.green)),
          const SizedBox(height: 12),
          PropertyFacts(extras: x, roomTypeLabel: roomTypeLabels[_roomType] ?? ''),
          const SizedBox(height: 12),
          FacilitiesByCategory(codes: _amen.toList()),
          const SizedBox(height: 12),
          Text(_pin == null ? 'No map pin yet' : 'Map pin set', style: TextStyle(color: _pin == null ? CS.warn : CS.green, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('${_photos.length} photo${_photos.length == 1 ? '' : 's'}  ·  ${_docs.values.where((v) => v).length} document${_docs.values.where((v) => v).length == 1 ? '' : 's'} uploaded'),
        ]),
      ),
      if (TransportCard(extras: x).hasAny) ...[const SizedBox(height: 16), TransportCard(extras: x)],
      const SizedBox(height: 16),
      CostsCard(rentLabel: rentLabel, rentNgn: rent, extras: x, otherFees: _fees.text.trim().isEmpty ? null : _fees.text.trim()),
      const SizedBox(height: 12),
      RulesCard(extras: x),
      const SizedBox(height: 16),
      Text(_canSubmit ? 'When you send this, our team reviews it. Students can see it only after it is approved.' : 'Saving keeps your changes. If you changed key details, the listing returns to review.', style: const TextStyle(color: CS.muted)),
    ]);
  }
}
