import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/landlord_theme.dart';
import '../../core/widgets/property_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../data/landlord_models.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

class _Photo {
  final PhotoRef ref;
  final Uint8List? bytes;
  _Photo(this.ref, [this.bytes]);
}

/// Guided 5-step flow: Details, Photos, Facilities, Verification, Review.
/// The draft is saved to the server after the first step, so nothing is lost.
class ListingWizard extends StatefulWidget {
  final LandlordListing? existing;
  const ListingWizard({super.key, this.existing});
  @override
  State<ListingWizard> createState() => _ListingWizardState();
}

class _ListingWizardState extends State<ListingWizard> {
  static const _titles = ['Details', 'Photos', 'Facilities', 'Verification', 'Review'];
  static const _maxPhotos = 8;
  static const _docTypes = [
    ('id_card', 'ID card', 'NIN slip, driver\'s licence or passport'),
    ('agreement', 'Landlord agreement or authorisation', 'Shows you are allowed to rent this property'),
    ('property_document', 'Property documents (optional)', 'Receipt, survey plan or utility bill'),
  ];

  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _area = TextEditingController();
  final _rent = TextEditingController();
  final _distance = TextEditingController();
  final _desc = TextEditingController();
  final _fees = TextEditingController();
  final _picker = ImagePicker();
  late Future<List<University>> _unis = Services.landlord.universities();

  String? _universityId;
  String _period = 'year';
  String? _roomType;
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
    if (e != null) {
      _id = e.id;
      _title.text = e.title;
      _area.text = e.area;
      _rent.text = e.rentNgn.toString();
      _distance.text = e.distanceKm?.toString() ?? '';
      _desc.text = e.description;
      _fees.text = e.extraFees ?? '';
      _universityId = e.universityId;
      _period = e.rentPeriod;
      _roomType = e.roomType;
      _photos.addAll(e.photos.map((p) => _Photo(p)));
      _amen.addAll(e.amenities);
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _area, _rent, _distance, _desc, _fees]) {
      c.dispose();
    }
    super.dispose();
  }

  ListingInput _input() => ListingInput(
        title: _title.text.trim(),
        description: _desc.text.trim(),
        area: _area.text.trim(),
        rentPeriod: _period,
        roomType: _roomType!,
        universityId: _universityId!,
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
          if (!_form.currentState!.validate()) return;
          _id = await r.saveDraft(_id, _input());
          break;
        case 1:
          if (_photos.isEmpty) {
            showMessage(context, 'Add at least one photo of the property.', error: true);
            return;
          }
          break;
        case 2:
          await r.setAmenities(_id!, _amen.toList());
          break;
        case 3:
          _status = (await r.myListing(_id!)).moderation;
          break;
        case 4:
          await _finish();
          return;
      }
      if (mounted) setState(() => _step++);
    } catch (e) {
      if (mounted) showMessage(context, landlordError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (['draft', 'needs_changes', 'rejected'].contains(_status)) {
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
          if (mounted) showMessage(context, '${f.name} is larger than 5 MB and was skipped.', error: true);
          continue;
        }
        final ref = await Services.landlord.addPhoto(_id!, bytes, f.name, _photos.length);
        if (mounted) setState(() => _photos.add(_Photo(ref, bytes)));
      }
    } catch (e) {
      if (mounted) showMessage(context, landlordError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto(_Photo p) async {
    try {
      await Services.landlord.removePhoto(_id!, p.ref);
      if (mounted) setState(() => _photos.remove(p));
    } catch (e) {
      if (mounted) showMessage(context, landlordError(e), error: true);
    }
  }

  Future<void> _pickDoc(String type) async {
    final f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 2000);
    if (f == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await f.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) throw Exception('File is larger than 10 MB.');
      await Services.landlord.uploadVerificationDoc(_id!, type, bytes, f.name);
      if (mounted) setState(() => _docs[type] = true);
    } catch (e) {
      if (mounted) showMessage(context, landlordError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
                      label: _step == 4 ? (['draft', 'needs_changes', 'rejected'].contains(_status) ? 'Submit for review' : 'Save changes') : 'Next',
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
        0 => _details(),
        1 => _photosStep(),
        2 => _facilities(),
        3 => _verification(),
        _ => _review(),
      };

  Widget _details() => Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.existing?.moderation == 'approved')
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(CS.rMd)),
              child: const Text('Changing the title, price, location or description sends this listing back for review.', style: TextStyle(fontSize: 13)),
            ),
          TextFormField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Property title', hintText: 'e.g. Single room near campus gate'),
            validator: (v) => (v ?? '').trim().length < 5 ? 'Enter at least 5 characters' : ((v ?? '').trim().length > 120 ? 'Keep it under 120 characters' : null),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<University>>(
            future: _unis,
            builder: (c, s) {
              if (s.hasError) return ErrorState(message: 'Could not load schools.', onRetry: () => setState(() => _unis = Services.landlord.universities()));
              final list = s.data ?? [];
              return DropdownButtonFormField<String>(
                value: list.any((u) => u.id == _universityId) ? _universityId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Nearest school'),
                items: [for (final u in list) DropdownMenuItem(value: u.id, child: Text('${u.shortName} · ${u.name}', overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setState(() => _universityId = v),
                validator: (v) => v == null ? 'Choose a school' : null,
              );
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _area,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Town or area', hintText: 'e.g. Ado-Ekiti, Ajilosun'),
            validator: (v) => (v ?? '').trim().length < 2 ? 'Enter the town or area' : null,
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
                value: _period,
                decoration: const InputDecoration(labelText: 'Per'),
                items: const [DropdownMenuItem(value: 'year', child: Text('Year')), DropdownMenuItem(value: 'month', child: Text('Month'))],
                onChanged: (v) => setState(() => _period = v ?? 'year'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _roomType,
            decoration: const InputDecoration(labelText: 'Room type'),
            items: [for (final e in roomTypeLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() => _roomType = v),
            validator: (v) => v == null ? 'Choose a room type' : null,
          ),
          const SizedBox(height: 12),
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
          TextFormField(
            controller: _desc,
            maxLines: 5,
            maxLength: 4000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Description', hintText: 'Describe the room, the area and the house rules'),
            validator: (v) => (v ?? '').trim().length < 20 ? 'Write at least 20 characters so students know what to expect' : null,
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: _fees,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Other compulsory fees (optional)', hintText: 'e.g. caution fee, agreement fee'),
          ),
        ]),
      );

  Widget _photosStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Add clear photos of the real property. Do not use photos of other places. The first photo is the cover.', style: TextStyle(color: CS.muted)),
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
        Text('${_photos.length} of $_maxPhotos photos. Each photo up to 5 MB.', style: Theme.of(context).textTheme.bodySmall),
      ]);

  Widget _facilities() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Select what the property offers.', style: TextStyle(color: CS.muted)),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final e in amenityLabels.entries)
            FilterChip(
              avatar: Icon(_amen.contains(e.key) ? Icons.check : Icons.add, size: 18, color: _amen.contains(e.key) ? Colors.white : CS.green),
              label: Text(e.value, style: TextStyle(fontSize: 15, color: _amen.contains(e.key) ? Colors.white : CS.ink)),
              selected: _amen.contains(e.key),
              showCheckmark: false,
              selectedColor: CS.green,
              onSelected: (v) => setState(() => v ? _amen.add(e.key) : _amen.remove(e.key)),
            ),
        ]),
      ]);

  Widget _verification() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Confirm your identity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Upload a photo of your ID and proof that you can rent this property. Our team reviews them before a listing can be marked verified. '
            'Only you and our review team can see these files. Students never can.', style: TextStyle(color: CS.muted)),
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

  Widget _review() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(CS.rLg), border: Border.all(color: CS.line), boxShadow: CS.shadow, color: CS.bg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_title.text.trim(), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(_area.text.trim(), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text('₦${formatNaira(int.tryParse(_rent.text.trim()) ?? 0)}/${_period == 'month' ? 'month' : 'year'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: CS.green)),
          const SizedBox(height: 8),
          Text(roomTypeLabels[_roomType] ?? ''),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final a in _amen) FacilityTile(a)]),
          const SizedBox(height: 12),
          Text('${_photos.length} photo${_photos.length == 1 ? '' : 's'}  ·  ${_docs.values.where((v) => v).length} document${_docs.values.where((v) => v).length == 1 ? '' : 's'} uploaded'),
        ]),
      ),
      const SizedBox(height: 16),
      Text(
        ['draft', 'needs_changes', 'rejected'].contains(_status)
            ? 'When you submit, our team reviews this listing. It becomes visible to students only after approval.'
            : 'Saving keeps your changes. If you changed key details, the listing returns to review.',
        style: const TextStyle(color: CS.muted),
      ),
    ]);
  }
}
