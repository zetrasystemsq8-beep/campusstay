import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import 'config.dart';
import 'launch.dart';
import 'theme/tokens.dart';
import 'widgets/state_views.dart';

/// Only the public summary is shared: never the exact address or the landlord's phone.
String listingShareText(Property p) {
  final b = StringBuffer()
    ..writeln(p.title)
    ..writeln('${p.rentLabel} · ${p.locationLabel}')
    ..write('Student accommodation on CampusStay');
  if (AppConfig.appLink.isNotEmpty) b.write('\n${AppConfig.appLink}');
  return b.toString();
}

Future<void> shareListing(BuildContext context, Property p) => showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(CS.rLg))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CS.s16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Share this listing', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Shares the title, rent and area only.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.chat_outlined, color: CS.green),
              title: const Text('WhatsApp'),
              onTap: () {
                Navigator.pop(c);
                openExternal(context, Uri.parse('https://wa.me/?text=${Uri.encodeComponent(listingShareText(p))}'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined, color: CS.blue),
              title: const Text('Copy text'),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: listingShareText(p)));
                if (c.mounted) Navigator.pop(c);
                if (context.mounted) showMessage(context, 'Copied. Paste it anywhere.');
              },
            ),
          ]),
        ),
      ),
    );
