import 'package:flutter/material.dart';
import '../../data/offline_cache.dart';
import '../theme/tokens.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: OfflineState.servingCache,
        builder: (c, on, _) => on
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: const Color(0xFFFFF4E0),
                child: const Row(children: [
                  Icon(Icons.cloud_off_outlined, size: 18, color: CS.warn),
                  SizedBox(width: 8),
                  Expanded(child: Text("You're offline. Showing copies saved earlier; prices may have changed.", style: TextStyle(fontSize: 12.5))),
                ]),
              )
            : const SizedBox.shrink(),
      );
}
