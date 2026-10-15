import 'package:flutter/material.dart';
import '../../data/models.dart';
import '../theme/tokens.dart';

class VerificationBadge extends StatelessWidget {
  final String level;
  const VerificationBadge(this.level, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (level) {
      'verified' => ('Verified', CS.green, Icons.verified),
      'pending' => ('Pending review', CS.warn, Icons.hourglass_top),
      _ => ('Unverified', CS.muted, Icons.info_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

/// Shows the first photo, or an honest "no photo" state. Never a stock image.
class PropertyPhoto extends StatelessWidget {
  final String? url;
  final double height;
  const PropertyPhoto({super.key, this.url, this.height = 160});

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return Container(
        height: height,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [CS.navy, CS.blue], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.home_work_outlined, color: Colors.white70, size: 36),
          SizedBox(height: 6),
          Text('No photo uploaded', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      );
    }
    return Image.network(
      url!,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (c, child, p) => p == null ? child : Container(height: height, color: CS.surface),
      errorBuilder: (c, e, s) => Container(
          height: height, color: CS.surface, child: const Icon(Icons.broken_image_outlined, color: CS.muted)),
    );
  }
}

class PropertyCard extends StatelessWidget {
  final Property property;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onToggleSave;
  const PropertyCard({super.key, required this.property, required this.saved, required this.onTap, required this.onToggleSave});

  @override
  Widget build(BuildContext context) {
    final p = property;
    return Semantics(
      button: true,
      label: '${p.title}, ${p.rentLabel}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: CS.s16),
          decoration: BoxDecoration(
            color: CS.bg,
            borderRadius: BorderRadius.circular(CS.rLg),
            boxShadow: CS.shadow,
            border: Border.all(color: CS.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(children: [
              PropertyPhoto(url: p.photoUrls.isEmpty ? null : p.photoUrls.first, height: 160),
              Positioned(
                right: 10,
                top: 10,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: saved ? 'Remove from saved' : 'Save listing',
                    icon: Icon(saved ? Icons.favorite : Icons.favorite_border, color: saved ? CS.danger : CS.ink, size: 20),
                    onPressed: onToggleSave,
                  ),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.all(CS.s16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(p.title, style: Theme.of(context).textTheme.titleMedium)),
                  VerificationBadge(p.verification),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 15, color: CS.muted),
                  const SizedBox(width: 3),
                  Expanded(child: Text(p.locationLabel, style: Theme.of(context).textTheme.bodySmall)),
                ]),
                const SizedBox(height: 8),
                Text(p.rentLabel,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CS.blue)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class FacilityTile extends StatelessWidget {
  final String code;
  const FacilityTile(this.code, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: CS.blueSoft, borderRadius: BorderRadius.circular(CS.rSm)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(amenityIcons[code] ?? Icons.check, size: 17, color: CS.blue),
          const SizedBox(width: 6),
          Text(amenityLabels[code] ?? code, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      );
}
