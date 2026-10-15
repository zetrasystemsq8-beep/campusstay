import 'package:flutter/material.dart';
import '../../data/landlord_models.dart';
import '../../data/schools_store.dart';
import '../theme/tokens.dart';
import 'error_views.dart';

/// What the person chose. Exactly one of [school], [other] or [cleared] is set.
class SchoolChoice {
  final University? school;
  final String? other;
  final bool cleared;
  const SchoolChoice({this.school, this.other, this.cleared = false});
}

Future<SchoolChoice?> pickSchool(BuildContext context, {bool allowOther = false, bool allowClear = false}) =>
    showModalBottomSheet<SchoolChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(CS.rLg))),
      builder: (_) => _SchoolSheet(allowOther: allowOther, allowClear: allowClear),
    );

class _SchoolSheet extends StatefulWidget {
  final bool allowOther, allowClear;
  const _SchoolSheet({required this.allowOther, required this.allowClear});
  @override
  State<_SchoolSheet> createState() => _SchoolSheetState();
}

class _SchoolSheetState extends State<_SchoolSheet> {
  late Future<List<University>> _f = SchoolsStore.load();
  String _q = '';
  String? _kind;

  static const _kinds = {'university': 'Universities', 'polytechnic': 'Polytechnics', 'college_of_education': 'Colleges'};

  void _retry() => setState(() => _f = SchoolsStore.load(force: true));

  Future<void> _other() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add your school'),
        content: TextField(controller: c, maxLength: 150, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Full name of the school')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final t = c.text.trim();
              if (t.length >= 3) Navigator.pop(ctx, t);
            },
            child: const Text('Use this name'),
          ),
        ],
      ),
    );
    if (name != null && mounted) Navigator.pop(context, SchoolChoice(other: name));
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.88,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(CS.s16, CS.s16, CS.s16, CS.s8),
              child: Row(children: [
                Expanded(child: Text('Choose a school', style: Theme.of(context).textTheme.titleLarge)),
                IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CS.s16),
              child: TextField(
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                decoration: const InputDecoration(hintText: 'Search name, short name, town or state', prefixIcon: Icon(Icons.search)),
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: CS.s16, vertical: 8), children: [
                Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: const Text('All'), selected: _kind == null, onSelected: (_) => setState(() => _kind = null))),
                for (final e in _kinds.entries)
                  Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(e.value), selected: _kind == e.key, onSelected: (s) => setState(() => _kind = s ? e.key : null))),
              ]),
            ),
            if (widget.allowClear)
              ListTile(
                leading: const Icon(Icons.public, color: CS.blue),
                title: const Text('Any school', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(context, const SchoolChoice(cleared: true)),
              ),
            Expanded(
              child: FutureBuilder<List<University>>(
                future: _f,
                builder: (c, s) {
                  if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                  if (s.hasError) return ErrorView(error: s.error!, onRetry: _retry);
                  final list = s.data!.where((u) {
                    if (_kind != null && u.kind != _kind) return false;
                    if (_q.isEmpty) return true;
                    return '${u.name} ${u.shortName} ${u.city} ${u.state}'.toLowerCase().contains(_q);
                  }).toList();
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(CS.s24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('No school matches that search.', textAlign: TextAlign.center),
                          if (widget.allowOther) ...[
                            const SizedBox(height: 12),
                            FilledButton(onPressed: _other, child: const Text("My school isn't listed")),
                          ],
                        ]),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: list.length + (widget.allowOther ? 1 : 0),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (c, i) {
                      if (i == list.length) {
                        return ListTile(
                          leading: const Icon(Icons.add_circle_outline, color: CS.green),
                          title: const Text("My school isn't listed", style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: const Text('Type its name instead'),
                          onTap: _other,
                        );
                      }
                      final u = list[i];
                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: CS.blueSoft, child: Icon(Icons.school_outlined, color: CS.blue)),
                        title: Text(u.name),
                        subtitle: Text('${u.shortName} · ${u.kindLabel}${u.where.isEmpty ? '' : ' · ${u.where}'}'),
                        onTap: () => Navigator.pop(context, SchoolChoice(school: u)),
                      );
                    },
                  );
                },
              ),
            ),
          ]),
        ),
      );
}
