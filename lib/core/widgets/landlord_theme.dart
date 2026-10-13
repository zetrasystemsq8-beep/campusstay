import 'package:flutter/material.dart';
import '../theme/tokens.dart';

ThemeData landlordTheme(ThemeData base) => base.copyWith(
      colorScheme: base.colorScheme.copyWith(primary: CS.green, secondary: CS.teal),
      chipTheme: base.chipTheme.copyWith(selectedColor: CS.green),
      navigationBarTheme: base.navigationBarTheme.copyWith(indicatorColor: CS.greenSoft),
    );

/// Landlord screens use the green side of the design system.
class LandlordThemed extends StatelessWidget {
  final Widget child;
  const LandlordThemed({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Theme(data: landlordTheme(Theme.of(context)), child: child);
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const StatusBadge(this.label, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      );
}

String landlordError(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('duplicate') || s.contains('23505')) return 'You already have a listing with this title and area.';
  if (s.contains('socket') || s.contains('network') || s.contains('clientexception')) return 'No connection. Check your internet and try again.';
  if (s.contains('row-level security') || s.contains('not allowed') || s.contains('forbidden')) return 'You are not allowed to do that.';
  if (s.contains('cannot be submitted')) return 'This listing cannot be submitted right now.';
  return 'Something went wrong. Please try again.';
}
