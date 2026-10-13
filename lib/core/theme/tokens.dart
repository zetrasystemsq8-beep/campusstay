import 'package:flutter/material.dart';

class CS {
  // Colour tokens (from the approved reference)
  static const navy = Color(0xFF0A2457);
  static const navyDeep = Color(0xFF06173B);
  static const blue = Color(0xFF1B63E6);
  static const blueSoft = Color(0xFFE8F0FE);
  static const green = Color(0xFF12A36B); // landlord side
  static const greenSoft = Color(0xFFE5F6EE);
  static const teal = Color(0xFF14B8A6);
  static const bg = Colors.white;
  static const surface = Color(0xFFF4F7FC);
  static const line = Color(0xFFE3E9F3);
  static const ink = Color(0xFF0E1B35);
  static const muted = Color(0xFF66768F);
  static const danger = Color(0xFFD64545);
  static const warn = Color(0xFFE08A00);

  // Spacing
  static const s4 = 4.0, s8 = 8.0, s12 = 12.0, s16 = 16.0, s20 = 20.0, s24 = 24.0, s32 = 32.0;

  // Radii
  static const rSm = 10.0, rMd = 14.0, rLg = 20.0;

  static List<BoxShadow> get shadow => [
        BoxShadow(color: navy.withOpacity(0.08), blurRadius: 18, offset: const Offset(0, 6)),
      ];
}
