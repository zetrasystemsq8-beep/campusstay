import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/property_widgets.dart';
import '../../data/models.dart';
import '../property/property_detail_screen.dart';

class _Row {
  final String label;
  final List<String> values;
  final List<num?>? keys; // used to find the best value
  final bool lowerIsBetter;
  const _Row(this.label, this.values, {this.keys, this.lowerIsBetter = true});
}

int annualRent(Property p) => p.rentPeriod == 'month' ? p.rentNgn * 12 : p.rentNgn;
int firstPayment(Property p) => p.rentNgn + (p.extras.cautionFeeNgn ?? 0) + (p.extras.serviceChargeNgn ?? 0);

/// Two or three listings side by side. The best value in each row is highlighted.
class CompareScreen extends StatelessWidget {
  final List<Property> items;
  const CompareScreen({super.key, required this.items});

  String _money(int v) => '₦${formatNaira(v)}';

  List<_Row> _rows() => [
        _Row('Rent', [for (final p in items) p.rentLabel], keys: [for (final p in items) annualRent(p)]),
        _Row('First payment', [for (final p in items) _money(firstPayment(p))], keys: [for (final p in items) firstPayment(p)]),
        _Row('Type', [for (final p in items) p.roomTypeLabel]),
        _Row('Bedrooms', [for (final p in items) p.extras.bedrooms == 0 ? 'Bed space' : '${p.extras.bedrooms}'], keys: [for (final p in items) p.extras.bedrooms], lowerIsBetter: false),
        _Row('Bathroom', [for (final p in items) p.extras.bathrooms == 0 ? 'None' : (p.extras.bathroomType == 'private' ? 'Private' : 'Shared')]),
        _Row('Kitchen', [for (final p in items) kitchenLabels[p.extras.kitchenType] ?? '']),
        _Row('Furnishing', [for (final p in items) furnishingLabels[p.extras.furnishing] ?? '']),
        _Row('Walk to school', [for (final p in items) p.extras.walkMinutes == null ? '–' : '${p.extras.walkMinutes} min'], keys: [for (final p in items) p.extras.walkMinutes]),
        _Row('Okada fare', [for (final p in items) p.extras.bikeFareNgn == null ? '–' : _money(p.extras.bikeFareNgn!)], keys: [for (final p in items) p.extras.bikeFareNgn]),
        _Row('Facilities', [for (final p in items) '${p.amenities.length}'], keys: [for (final p in items) p.amenities.length], lowerIsBetter: false),
        _Row('Instalments', [for (final p in items) p.extras.allowsInstalments ? 'Yes' : 'No']),
        _Row('Suitable for', [for (final p in items) genderLabels[p.extras.genderPreference] ?? '']),
        _Row('Verified', [for (final p in items) p.verification == 'verified' ? 'Yes' : (p.verification == 'pending' ? 'In review' : 'No')]),
      ];

  Set<int> _best(_Row r) {
    final k = r.keys;
    if (k == null) return {};
    final vals = [for (var i = 0; i < k.length; i++) if (k[i] != null) (i, k[i]!)];
    if (vals.length < 2) return {};
    final target = r.lowerIsBetter ? vals.map((e) => e.$2).reduce((a, b) => a < b ? a : b) : vals.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    final winners = {for (final e in vals) if (e.$2 == target) e.$1};
    return winners.length == vals.length ? {} : winners; // all equal: nothing stands out
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Compare')),
        body: ListView(padding: const EdgeInsets.all(CS.s16), children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final p in items)
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PropertyDetailScreen(propertyId: p.id))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ClipRRect(borderRadius: BorderRadius.circular(CS.rSm), child: PropertyPhoto(url: p.photoUrls.isEmpty ? null : p.photoUrls.first, height: 90)),
                      const SizedBox(height: 6),
                      Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                      const Text('View', style: TextStyle(color: CS.blue, fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          for (final r in _rows()) ...[
            Padding(padding: const EdgeInsets.only(top: 12, bottom: 4, left: 4), child: Text(r.label, style: Theme.of(context).textTheme.bodySmall)),
            Builder(builder: (c) {
              final best = _best(r);
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: best.contains(i) ? CS.greenSoft : CS.surface, borderRadius: BorderRadius.circular(CS.rSm)),
                      child: Row(children: [
                        if (best.contains(i)) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.check_circle, size: 15, color: CS.green)),
                        Expanded(child: Text(r.values[i], style: TextStyle(fontWeight: best.contains(i) ? FontWeight.w800 : FontWeight.w600, fontSize: 13.5, color: best.contains(i) ? CS.green : CS.ink))),
                      ]),
                    ),
                  ),
              ]);
            }),
          ],
          const SizedBox(height: 16),
          const Text('Green means the best value in that row. Compare the full cost, not just the rent.', style: TextStyle(color: CS.muted, fontSize: 12.5)),
        ]),
      );
}
