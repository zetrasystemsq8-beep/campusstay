import 'package:flutter/material.dart';
import '../safety.dart';
import '../theme/tokens.dart';

/// Plain warnings for patterns that scams use.
class SafetyBanner extends StatelessWidget {
  final Set<SafetyFlag> flags;
  final VoidCallback? onReport;
  const SafetyBanner({super.key, required this.flags, this.onReport});

  @override
  Widget build(BuildContext context) {
    if (flags.isEmpty) return const SizedBox.shrink();
    final lines = <String>[
      if (flags.contains(SafetyFlag.secretCode)) 'Never share an OTP, PIN, BVN, password or card details. CampusStay will never ask for them.',
      if (flags.contains(SafetyFlag.money) || flags.contains(SafetyFlag.account)) 'This mentions payment. Never pay or send money before you have seen the place and met the landlord.',
      if (flags.contains(SafetyFlag.phone) && flags.length == 1) 'A phone number is shared here. Fine, but still see the place before you pay anything.',
    ];
    final serious = !(flags.length == 1 && flags.contains(SafetyFlag.phone));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: serious ? const Color(0xFFFDECEC) : const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(CS.rMd)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.shield_outlined, size: 20, color: serious ? CS.danger : CS.warn),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final l in lines) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(l, style: const TextStyle(fontSize: 13.5))),
            if (onReport != null && serious) TextButton(onPressed: onReport, style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)), child: const Text('Report this person')),
          ]),
        ),
      ]),
    );
  }
}

/// A short checklist shown on every listing.
class SafetyChecklist extends StatelessWidget {
  const SafetyChecklist({super.key});

  static const items = [
    'See the property in person, in daylight, before you pay anything.',
    'Meet the landlord or their real representative. Ask to see proof they own or manage it.',
    'Never pay to be shown a place, and be careful if you are rushed.',
    'Pay only against a receipt or a signed agreement, and keep both.',
    'Never share your OTP, PIN or BVN with anyone.',
    'If the price is far below similar places, be extra careful.',
  ];

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(CS.rMd), border: Border.all(color: CS.line)),
        child: ExpansionTile(
          shape: const Border(),
          leading: const Icon(Icons.shield_outlined, color: CS.green),
          title: const Text('Before you pay anything', style: TextStyle(fontWeight: FontWeight.w700)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final i in items)
              Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle_outline, size: 18, color: CS.green), const SizedBox(width: 8), Expanded(child: Text(i))])),
          ],
        ),
      );
}

/// Shown once per session before a first message. Returns true to continue.
Future<bool> showSafetyTips(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Stay safe'),
        content: const Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('• See the place in person before you pay.\n• Never send money to book a viewing.\n• Never share your OTP, PIN or BVN.\n• Keep chatting here so there is a record.'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('I understand')),
        ],
      ),
    ) ??
    false;
