import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(CS.s32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: CS.blueSoft, shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: CS.blue),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ]),
        ),
      );
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Something went wrong',
        message: message,
        actionLabel: 'Try again',
        onAction: onRetry,
      );
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});
  @override
  Widget build(BuildContext context) => Container(
        height: 250,
        margin: const EdgeInsets.only(bottom: CS.s16),
        decoration: BoxDecoration(color: CS.surface, borderRadius: BorderRadius.circular(CS.rLg)),
      );
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key});
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(CS.s16),
        physics: const NeverScrollableScrollPhysics(),
        children: const [SkeletonCard(), SkeletonCard()],
      );
}

void showMessage(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? CS.danger : CS.navy));
}
