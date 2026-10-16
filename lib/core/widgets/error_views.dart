import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../errors.dart';
import '../theme/tokens.dart';
import 'state_views.dart';

IconData _icon(AppErrorKind k) => switch (k) {
      AppErrorKind.offline => Icons.wifi_off_rounded,
      AppErrorKind.timeout => Icons.hourglass_empty_rounded,
      AppErrorKind.signInRequired || AppErrorKind.suspended || AppErrorKind.forbidden => Icons.lock_outline,
      AppErrorKind.notFound || AppErrorKind.notAvailable => Icons.search_off,
      AppErrorKind.locationOff || AppErrorKind.locationDenied || AppErrorKind.locationDeniedForever || AppErrorKind.locationUnavailable => Icons.location_off_outlined,
      _ => Icons.sentiment_neutral_outlined,
    };

/// Full-area error with its own title, wording and (when sensible) a retry button.
class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final e = classify(error);
    final i = describe(e);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CS.s32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: CS.blueSoft, shape: BoxShape.circle),
            child: Icon(_icon(e.kind), size: 36, color: CS.blue),
          ),
          const SizedBox(height: 16),
          Text(i.title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(i.message, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          if (i.retryable) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
          if (i.reference != null)
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: '${i.reference}: ${i.technical}'));
                showMessage(context, 'Error details copied.');
              },
              child: Text('Copy error details (${i.reference})'),
            ),
        ]),
      ),
    );
  }
}

/// Snackbar with the specific title and message for this failure.
void showError(BuildContext context, Object error, {VoidCallback? onRetry}) {
  final i = describe(error);
  final messenger = ScaffoldMessenger.of(context);
  SnackBarAction? action;
  if (i.retryable && onRetry != null) {
    action = SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: onRetry);
  } else if (i.reference != null) {
    action = SnackBarAction(
      label: 'Copy details',
      textColor: Colors.white,
      onPressed: () => Clipboard.setData(ClipboardData(text: '${i.reference}: ${i.technical}')),
    );
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: CS.danger,
      duration: const Duration(seconds: 6),
      action: action,
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(i.title, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 2),
        Text(i.message, style: const TextStyle(color: Colors.white)),
      ]),
    ));
}
