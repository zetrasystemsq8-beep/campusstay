import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/error_views.dart';
import '../../core/widgets/landlord_theme.dart';
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

/// Guided 7-step flow. The draft is saved to the server as you go, so nothing is lost.
class ListingWizard extends StatefulWidget {
  final LandlordListing? existing;
  const ListingWizard({super.key, this.existing});
  @override
  State<ListingWizard> createState() => _ListingWizardState();
}

class _ListingWizardState extends State<ListingWizard> {
  static const _titles = ['Basics', 'Space', 'Costs', 'Features', 'Photos', 'Verification', 'Review'];
  static const _maxPhotos = 10;
  static const _docTypes = [
    ('id_card', 'ID card', "NIN slip, driver's licence or passport"),
    ('agreement', 'Landlord agreement or authorisation', 'Shows you are allowed to rent this property'),
    ('property_document', 'Property documents (optional)', 'Receipt, survey plan or utility bill'),
  ];

  final _formBasics = GlobalKey<FormState>();
  final _formCosts = GlobalKey<FormState>();
  final _formFeatures = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _area = TextEditingController();
  final _landmark = TextEditingController();
  final _distance = TextEditingController();
  final _rent = TextEditingController();
  final _caution = TextEditingController();
  final _service = TextEditingController();
  final _fees = TextEditingController();
  final _lease = TextEditingController();
  final _rules = TextEditingController();
  final _desc = TextEditingController();
  final _picker = ImagePicker();

  String? _universityId;
  String _schoolLabel = '';
  String _schoolOther = '';
  bool _schoolMissing = false;
  String _period = 'year';
  String? _roomType;
  int _bedrooms = 1, _bathrooms = 1, _occupants = 1;
  String _bathroomType = 'private', _kitchenType = 'shared', _furnishing = 'unfurnished', _gender = 'any';
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
    _distance.text = e.distanceKm?.toString() ?? '';
    _rent.text = e.rentNgn.toString();
    _caution.text = x.cautionFeeNgn?.toString() ?? '';
    _service.text = x.serviceChargeNgn?.toString() ?? '';
    _fees.text = e.extraFees ?? '';
    _lease.text = x.leaseMonths?.toString() ?? '';
    _rules.text = x.houseRules;
    _desc.text = e.description;
    _universityId = e.universityId;
    _schoolLabel = e.school;
    _schoolOther = x.schoolOther;
    _period = e.rentPeriod;
    _roomType = e.roomType;
    _bedrooms = x.bedrooms;
    _bathrooms = x.bathrooms;
    _occupants = x.maxOccupants;
    _bathroomType = x.bathroomType;
    _kitchenType = x.kitchenType;
    _furnishing = x.furnishing;
    _gender = x.genderPreference;
    _availableFrom = x.availableFrom;
    _instalments = x.allowsInstalments;
    _liveOnSite = x.landlordLivesOnSite;
    _visitors = x.visitorsAllowed;
    _pets = x.petsAllowed;
    _photos.addAll(e.photos.map((p) => _Photo(p)));
    _amen.addAll(e.amenities);
  }

  @override
  void dispose() {
    for (final c in [_title, _area, _landmark, _distance, _rent, _caution, _service, _fees, _lease, _rules, _desc]) {
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
        distanceKm: _distance.text.trim().isEmpty ? null : double.tryParse(_distance.text.trim()),
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
          setState(() => _schoolMissing = !schoolOk);
          if (!ok || !schoolOk) return;
          _id = await r.saveDraft(_id, _input());
          break;
        case 1:
          _id = await r.saveDraft(_id, _input());
          break;
        case 2:
          if (!_formCosts.currentState!.validate()) return;
          _id = await r.saveDraft(_id, _input());
          break;
        case 3:
          if (!_formFeatures.currentState!.validate()) return;
          _id = await r.saveDraft(_id, _input());
          await r.setAmenities(_id!, _amen.toList());
          break;
        case 4:
          if (_photos.isEmpty) {
            showMessage(context, 'Add at least one photo of the property.', error: true);
            return;
          }
          break;
        case 5:
          _status = (await r.myListing(_id!)).moderation;
          break;
        case 6:
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
          title: const Text('Submitted for review'),
          content: const Text('Our team will check your listing before students can see it. You will find its status under My listings.'),
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
        _schoolOther = '';
      } else if (r.other != null) {
        _universityId = null;
        _schoolOther = r.other!;
        _schoolLabel = r.other!;
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

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) => LandlordThemed(
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.existing == null ? 'Add property' : 'Edit property'),
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context, _id != null)),
          ),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(CS.s16, 0, CS.s16, CS.s8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  for (var i = 0; i < _titles.length; i++)
                    Expanded(
                      child: Container(
                        height: 5,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(color: i <= _step ? CS.green : CS.line, borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                ]),
                const SizedBox(height: 8),
                Text('Step ${_step + 1} of ${_titles.length}: ${_titles[_step]}', style: Theme.of(context).textTheme.titleMedium),
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
                      child: SizedBox(height: 54, child: OutlinedButton(onPressed: () => setState(() => _step--), child: const Text('Back'))),
                    ),
                  Expanded(
                    child: PrimaryButton(
                      label: _step == 6 ? (_canSubmit ? 'Submit for review' : 'Save changes') : 'Next',
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
      );

  Widget _body() => switch (_step) {
        0 => _basics(),
        1 => _space(),
        2 => _costs(),
        3 => _features(),
        4 => _photosStep(),
        5 => _verification(),
        _ => _review(),
      };

  Widget _h(String t, [String? sub]) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          if (sub != null) Text(sub, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );

  Widget _choices(Map<String, String> options, String value, void Function(String) on) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final e in options.entries) ChoiceChip(label: Text(e.value, style: const TextStyle(fontSize: 15)), selected: value == e.key, onSelected: (_) => setState(() => on(e.key)))],
      );

  Widget _counter(String label, int value, int min, int max, void Function(int) on, {String? hint}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              if (hint != null) Text(hint, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          IconButton.outlined(tooltip: 'Fewer', onPressed: value > min ? () => setState(() => on(value - 1)) : null, icon: const Icon(Icons.remove)),
          SizedBox(width: 44, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
          IconButton.outlined(tooltip: 'More', onPressed: value < max ? () => setState(() => on(value + 1)) : null, icon: const Icon(Icons.add)),
        ]),
      );

  Widget _switch(String title, String sub, bool v, void Function(bool) on) =>
      SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(sub), value: v, onChanged: (x) => setState(() => on(x)));

  String? _optMoney(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    return (n == null || n < 0 || n >= 100000000) ? 'Enter a valid amount' : null;
  }

  // Step 1
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
          TextFormField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Property title', hintText: 'e.g. Self-contain near campus gate'),
            validator: (v) => (v ?? '').trim().length < 5 ? 'Enter at least 5 characters' : ((v ?? '').trim().length > 120 ? 'Keep it under 120 characters' : null),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _roomType,
            decoration: const InputDecoration(labelText: 'Property type'),
            items: [for (final e in roomTypeLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() => _roomType = v),
            validator: (v) => v == null ? 'Choose a property type' : null,
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(CS.rMd),
            onTap: _chooseSchool,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Nearest school',
                errorText: _schoolMissing ? 'Choose a school or add its name' : null,
                suffixIcon: const Icon(Icons.search),
              ),
              child: Text(_schoolLabel.isEmpty ? 'Tap to search all Nigerian schools' : _schoolLabel, style: TextStyle(color: _schoolLabel.isEmpty ? CS.muted : CS.ink, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _area,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Town or area', hintText: 'e.g. Ado-Ekiti, Ajilosun'),
            validator: (v) => (v ?? '').trim().length < 2 ? 'Enter the town or area' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _landmark,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Landmark or directions (optional)', hintText: 'e.g. Opposite the main gate, behind the filling station'),
          ),
          TextFormField(
            controller: _distance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Distance from school in km (optional)'),
            validator: (v) {
              if ((v ?? '').trim().isEmpty) return null;
              final d = double.tryParse(v!.trim());
              return (d == null || d < 0 || d > 999) ? 'Enter a number like 1.5' : null;
            },
          ),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _rent,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Rent (₦)'),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  return (n == null || n <= 0) ? 'Enter the rent amount' : (n >= 100000000 ? 'Amount is too large' : null);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _period,
                decoration: const InputDecoration(labelText: 'Per'),
                items: const [DropdownMenuItem(value: 'year', child: Text('Year')), DropdownMenuItem(value: 'month', child: Text('Month'))],
                onChanged: (v) => setState(() => _period = v ?? 'year'),
              ),
            ),
          ]),
        ]),
      );

  // Step 2
  Widget _space() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _counter('Bedrooms', _bedrooms, 0, 20, (v) => _bedrooms = v, hint: '0 means a bed space or a single shared room'),
        _counter('Bathrooms', _bathrooms, 0, 20, (v) => _bathrooms = v),
        _counter('Most people allowed', _occupants, 1, 30, (v) => _occupants = v, hint: 'Counting everyone who will live there'),
        _h('Bathroom'),
        _choices(const {'private': 'Private', 'shared': 'Shared'}, _bathroomType, (v) => _bathroomType = v),
        _h('Kitchen'),
        _choices(const {'private': 'Private', 'shared': 'Shared', 'none': 'No kitchen'}, _kitchenType, (v) => _kitchenType = v),
        _h('Furnishing'),
        _choices(furnishingLabels, _furnishing, (v) => _furnishing = v),
        _h('Who is it for?', 'Choosing one side limits who can find this listing.'),
        _choices(const {'any': 'Anyone', 'male_only': 'Male students', 'female_only': 'Female students'}, _gender, (v) => _gender = v),
        _h('Available from'),
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.event),
          label: Text(_availableFrom == null ? 'Available now. Tap to set a date' : fmtDate(_availableFrom!)),
        ),
        if (_availableFrom != null) TextButton(onPressed: () => setState(() => _availableFrom = null), child: const Text('Clear date')),
        const SizedBox(height: 8),
        _switch('Landlord lives on the property', 'Tell students if you live in the same compound.', _liveOnSite, (v) => _liveOnSite = v),
      ]);

  // Step 3
  Widget _costs() {
    final rent = _n(_rent) ?? 0, caution = _n(_caution) ?? 0, service = _n(_service) ?? 0;
    final first = rent + caution + service;
    return Form(
      key: _formCosts,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Be clear about every cost. Students trust listings that show the full amount.', style: TextStyle(color: CS.muted)),
        const SizedBox(height: 12),
        TextFormField(
          controller: _caution,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Caution fee (₦, optional)', hintText: 'Refundable deposit'),
          onChanged: (_) => setState(() {}),
          validator: _optMoney,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _service,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Service charge (₦, optional)', hintText: 'Cleaning, security, waste'),
          onChanged: (_) => setState(() {}),
          validator: _optMoney,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _fees,
          maxLines: 3,
          maxLength: 1000,
          decoration: const InputDecoration(labelText: 'Any other fees (optional)', hintText: 'e.g. agreement fee, light bill share'),
        ),
        TextFormField(
          controller: _lease,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Minimum stay in months (optional)'),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return null;
            final n = int.tryParse(t);
            return (n == null || n < 1 || n > 60) ? 'Enter 1 to 60 months' : null;
          },
        ),
        const SizedBox(height: 8),
        _switch('Allow payment in instalments', 'Students can pay in parts instead of all at once.', _instalments, (v) => _instalments = v),
        if (rent > 0)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: CS.greenSoft, borderRadius: BorderRadius.circular(CS.rMd)),
            child: Text('A student pays about ₦${formatNaira(first)} to move in (rent${caution > 0 ? ' + caution fee' : ''}${service > 0 ? ' + service charge' : ''}).',
                style: const TextStyle(color: CS.green, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }

  // Step 4
  Widget _features() => Form(
        key: _formFeatures,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tick everything the property has. Students can filter by these.', style: TextStyle(color: CS.muted)),
          for (final cat in amenityCategoryLabels.entries) ...[
            _h(cat.value),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final a in amenityCatalog)
                if (a.category == cat.key)
                  FilterChip(
                    avatar: Icon(a.icon, size: 18, color: _amen.contains(a.code) ? Colors.white : CS.green),
                    label: Text(a.label, style: TextStyle(fontSize: 14.5, color: _amen.contains(a.code) ? Colors.white : CS.ink)),
                    selected: _amen.contains(a.code),
                    showCheckmark: false,
                    selectedColor: CS.green,
                    onSelected: (v) => setState(() => v ? _amen.add(a.code) : _amen.remove(a.code)),
                  ),
            ]),
          ],
          const SizedBox(height: 8),
          Text('${_amen.length} selected', style: Theme.of(context).textTheme.bodySmall),
          _h('House rules'),
          _switch('Visitors allowed', 'Friends and family can visit.', _visitors, (v) => _visitors = v),
          _switch('Pets allowed', 'Students may keep pets.', _pets, (v) => _pets = v),
          TextFormField(
            controller: _rules,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Other rules (optional)', hintText: 'e.g. No loud music after 10pm'),
          ),
          _h('Describe the property'),
          TextFormField(
            controller: _desc,
            maxLines: 5,
            maxLength: 4000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Description', hintText: 'The room, the compound, the neighbourhood and what makes it a good place to live'),
            validator: (v) => (v ?? '').trim().length < 20 ? 'Write at least 20 characters so students know what to expect' : null,
          ),
        ]),
      );

  // Step 5
  Widget _photosStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Add clear photos of the real property: the room, bathroom, kitchen and outside. Do not use photos of other places. The first photo is the cover.', style: TextStyle(color: CS.muted)),
        const SizedBox(height: 12),
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
                    child: const CircleAvatar(radius: 13, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 15, color: Colors.white)),
                  ),
                ),
              ]),
            if (_photos.length < _maxPhotos)
              InkWell(
                onTap: _busy ? null : _pickPhotos,
                child: Container(
                  decoration: BoxDecoration(color: CS.greenSoft, borderRadius: BorderRadius.circular(CS.rSm), border: Border.all(color: CS.green)),
                  child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_a_photo_outlined, color: CS.green),
                    SizedBox(height: 4),
                    Text('Add photos', style: TextStyle(color: CS.green, fontWeight: FontWeight.w700, fontSize: 12)),
                  ]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text('${_photos.length} of $_maxPhotos photos. Each photo up to 5 MB. Listings with 4 or more photos get more enquiries.', style: Theme.of(context).textTheme.bodySmall),
      ]);

  // Step 6
  Widget _verification() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Confirm your identity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Upload a photo of your ID and proof that you can rent this property. Our team reviews them before a listing can be marked verified. Only you and our review team can see these files. Students never can.', style: TextStyle(color: CS.muted)),
        const SizedBox(height: 16),
        for (final d in _docTypes)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CS.rMd), side: const BorderSide(color: CS.line)),
            child: ListTile(
              leading: Icon(_docs[d.$1] == true ? Icons.check_circle : Icons.upload_file_outlined, color: _docs[d.$1] == true ? CS.green : CS.muted),
              title: Text(d.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(_docs[d.$1] == true ? 'Uploaded. Waiting for review.' : d.$3),
              trailing: TextButton(onPressed: _busy ? null : () => _pickDoc(d.$1), child: Text(_docs[d.$1] == true ? 'Replace' : 'Upload')),
            ),
          ),
        const SizedBox(height: 8),
        const Text('You can skip this now. Listings without documents are shown to students as Unverified.', style: TextStyle(fontSize: 13, color: CS.muted)),
      ]);

  // Step 7
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
          Text(rentLabel, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: CS.green)),
          const SizedBox(height: 12),
          PropertyFacts(extras: x, roomTypeLabel: roomTypeLabels[_roomType] ?? ''),
          const SizedBox(height: 12),
          FacilitiesByCategory(codes: _amen.toList()),
          const SizedBox(height: 12),
          Text('${_photos.length} photo${_photos.length == 1 ? '' : 's'}  ·  ${_docs.values.where((v) => v).length} document${_docs.values.where((v) => v).length == 1 ? '' : 's'} uploaded'),
        ]),
      ),
      const SizedBox(height: 16),
      CostsCard(rentLabel: rentLabel, rentNgn: rent, extras: x, otherFees: _fees.text.trim().isEmpty ? null : _fees.text.trim()),
      const SizedBox(height: 12),
      RulesCard(extras: x),
      const SizedBox(height: 16),
      Text(_canSubmit ? 'When you submit, our team reviews this listing. It becomes visible to students only after approval.' : 'Saving keeps your changes. If you changed key details, the listing returns to review.', style: const TextStyle(color: CS.muted)),
    ]);
  }
}
