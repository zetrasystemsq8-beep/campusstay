import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'errors.dart';
import 'widgets/error_views.dart';

/// Opens a link, phone call or map in another app. Failure is reported specifically.
Future<void> openExternal(BuildContext context, Uri uri) async {
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showError(context, const AppException(AppErrorKind.invalid, detail: 'No app on this phone could open that.'));
    }
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

Uri mapsUri(double lat, double lng) => Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
