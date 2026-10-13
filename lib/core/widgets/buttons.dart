import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color color;
  final IconData? icon;
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.color = CS.blue,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CS.rMd)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          onPressed: loading ? null : onPressed,
          child: loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                  Text(label),
                ]),
        ),
      );
}

class OutlineActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const OutlineActionButton({super.key, required this.label, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: CS.blue,
            side: const BorderSide(color: CS.blue, width: 1.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CS.rMd)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          onPressed: onPressed,
          icon: Icon(icon ?? Icons.chat_bubble_outline, size: 18),
          label: Text(label),
        ),
      );
}
