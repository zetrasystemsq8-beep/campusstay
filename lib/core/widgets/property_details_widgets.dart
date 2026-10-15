import 'package:flutter/material.dart';
import '../../data/models.dart';
import '../format.dart';
import '../theme/tokens.dart';
import 'property_widgets.dart';

class _Fact extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlight;
  const _Fact(this.icon, this.text, {this.highlight = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: highlight ? CS.blueSoft : CS.surface, borderRadius: BorderRadius.circular(CS.rSm)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 17, color: CS.blue),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))),
        ]),
      );
}

/// Key facts about the space: rooms, bathroom, kitchen, furnishing, who it suits.
class PropertyFacts extends StatelessWidget {
  final PropertyExtras extras;
  final String roomTypeLabel;
  const PropertyFacts({super.key, required this.extras, required this.roomTypeLabel});

  @override
  Widget build(BuildContext context) {
    final e = extras;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      _Fact(Icons.home_work_outlined, roomTypeLabel, highlight: true),
      _Fact(Icons.bed_outlined, e.bedrooms == 0 ? 'Bed space' : '${e.bedrooms} bedroom${e.bedrooms == 1 ? '' : 's'}'),
      if (e.bathrooms > 0) _Fact(Icons.bathtub_outlined, '${e.bathrooms} · ${e.bathroomType == 'private' ? 'private' : 'shared'} bathroom${e.bathrooms == 1 ? '' : 's'}'),
      _Fact(Icons.kitchen_outlined, kitchenLabels[e.kitchenType] ?? ''),
      _Fact(Icons.chair_outlined, furnishingLabels[e.furnishing] ?? ''),
      _Fact(Icons.people_outline, e.maxOccupants == 1 ? 'For 1 person' : 'Up to ${e.maxOccupants} people'),
      if (e.genderPreference != 'any') _Fact(Icons.wc, genderLabels[e.genderPreference] ?? '', highlight: true),
      if (e.availableFrom != null) _Fact(Icons.event_available_outlined, 'Available from ${fmtDate(e.availableFrom!)}'),
      if (e.leaseMonths != null) _Fact(Icons.schedule, 'Minimum stay ${e.leaseMonths} month${e.leaseMonths == 1 ? '' : 's'}'),
      if (e.landlordLivesOnSite) const _Fact(Icons.house_outlined, 'Landlord lives on the property'),
    ]);
  }
}

/// Facilities grouped under readable headings. Only groups that have items are shown.
class FacilitiesByCategory extends StatelessWidget {
  final List<String> codes;
  const FacilitiesByCategory({super.key, required this.codes});

  @override
  Widget build(BuildContext context) {
    if (codes.isEmpty) return const Text('No facilities listed.', style: TextStyle(color: CS.muted));
    final set = codes.toSet();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final cat in amenityCategoryLabels.entries)
        if (amenityCatalog.any((a) => a.category == cat.key && set.contains(a.code))) ...[
          Padding(padding: const EdgeInsets.only(top: 10, bottom: 6), child: Text(cat.value, style: Theme.of(context).textTheme.bodySmall)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in amenityCatalog)
              if (a.category == cat.key && set.contains(a.code)) FacilityTile(a.code),
          ]),
        ],
    ]);
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final bool strong;
  const _Row(this.label, this.value, {this.strong = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(label, style: const TextStyle(color: CS.muted))),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w600))),
        ]),
      );
}

/// What a student will actually pay, in plain words.
class CostsCard extends StatelessWidget {
  final String rentLabel;
  final int rentNgn;
  final PropertyExtras extras;
  final String? otherFees;
  const CostsCard({super.key, required this.rentLabel, required this.rentNgn, required this.extras, this.otherFees});

  @override
  Widget build(BuildContext context) {
    final caution = extras.cautionFeeNgn ?? 0, service = extras.serviceChargeNgn ?? 0;
    final upfront = rentNgn + caution + service;
    return Container(
      padding: const EdgeInsets.all(CS.s16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(CS.rMd), border: Border.all(color: CS.line)),
      child: Column(children: [
        _Row('Rent', rentLabel),
        if (extras.cautionFeeNgn != null) _Row('Caution fee', '₦${formatNaira(extras.cautionFeeNgn!)}'),
        if (extras.serviceChargeNgn != null) _Row('Service charge', '₦${formatNaira(extras.serviceChargeNgn!)}'),
        if (caution + service > 0) ...[const Divider(height: 16), _Row('First payment', '₦${formatNaira(upfront)}', strong: true)],
        _Row('Pay in instalments', extras.allowsInstalments ? 'Offered' : 'Not offered'),
        if ((otherFees ?? '').isNotEmpty) _Row('Other fees', otherFees!),
      ]),
    );
  }
}

class RulesCard extends StatelessWidget {
  final PropertyExtras extras;
  const RulesCard({super.key, required this.extras});

  @override
  Widget build(BuildContext context) {
    Widget line(bool ok, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [Icon(ok ? Icons.check_circle_outline : Icons.block, size: 18, color: ok ? CS.green : CS.muted), const SizedBox(width: 8), Text(text)]),
        );
    return Container(
      padding: const EdgeInsets.all(CS.s16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(CS.rMd), border: Border.all(color: CS.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        line(extras.visitorsAllowed, extras.visitorsAllowed ? 'Visitors allowed' : 'No visitors'),
        line(extras.petsAllowed, extras.petsAllowed ? 'Pets allowed' : 'No pets'),
        if (extras.houseRules.isNotEmpty) ...[const SizedBox(height: 8), Text(extras.houseRules)],
      ]),
    );
  }
}
