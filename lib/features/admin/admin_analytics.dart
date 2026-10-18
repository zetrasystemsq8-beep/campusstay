import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/error_views.dart';
import '../../data/repository.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late Future<Map<String, List<(String, int)>>> _f = Services.admin.breakdown();
  void _reload() => setState(() => _f = Services.admin.breakdown());

  static const _titles = [
    ('listings_by_status', 'Listings by status'),
    ('users_by_role', 'People by role'),
    ('by_state', 'Live listings by state'),
    ('by_school', 'Live listings by school'),
    ('report_reasons', 'Most common report reasons'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Analytics')),
        body: FutureBuilder<Map<String, List<(String, int)>>>(
          future: _f,
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (s.hasError) return ErrorView(error: s.error!, onRetry: _reload);
            final d = s.data!;
            return RefreshIndicator(
              onRefresh: () async {
                _reload();
                await _f;
              },
              child: ListView(padding: const EdgeInsets.all(CS.s16), children: [
                for (final t in _titles) _Bars(title: t.$2, items: d[t.$1] ?? const []),
              ]),
            );
          },
        ),
      );
}

class _Bars extends StatelessWidget {
  final String title;
  final List<(String, int)> items;
  const _Bars({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final max = items.isEmpty ? 1 : items.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(CS.s16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(CS.rMd), border: Border.all(color: CS.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        if (items.isEmpty) const Text('Nothing to show yet.', style: TextStyle(color: CS.muted)),
        for (final e in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(width: 110, child: Text(e.$1.replaceAll('_', ' '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
              Expanded(
                child: Stack(children: [
                  Container(height: 18, decoration: BoxDecoration(color: CS.surface, borderRadius: BorderRadius.circular(9))),
                  FractionallySizedBox(widthFactor: e.$2 / max, child: Container(height: 18, decoration: BoxDecoration(color: CS.blue, borderRadius: BorderRadius.circular(9)))),
                ]),
              ),
              SizedBox(width: 40, child: Text('${e.$2}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800))),
            ]),
          ),
      ]),
    );
  }
}
