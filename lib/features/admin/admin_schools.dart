import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/error_views.dart';
import '../../core/widgets/state_views.dart';
import '../../data/landlord_models.dart';
import '../../data/nigeria.dart';
import '../../data/repository.dart';
import '../../data/schools_store.dart';

/// Add or correct schools without touching the database by hand.
class SchoolsAdminScreen extends StatefulWidget {
  const SchoolsAdminScreen({super.key});
  @override
  State<SchoolsAdminScreen> createState() => _SchoolsAdminScreenState();
}

class _SchoolsAdminScreenState extends State<SchoolsAdminScreen> {
  late Future<List<University>> _f = SchoolsStore.load(force: true);
  String _q = '';
  void _reload() => setState(() => _f = SchoolsStore.load(force: true));

  Future<void> _edit([University? u]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(CS.rLg))),
      builder: (_) => _SchoolForm(school: u),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Schools')),
        floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Add school')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(CS.s16),
            child: TextField(onChanged: (v) => setState(() => _q = v.trim().toLowerCase()), decoration: const InputDecoration(hintText: 'Search schools', prefixIcon: Icon(Icons.search))),
          ),
          Expanded(
            child: FutureBuilder<List<University>>(
              future: _f,
              builder: (c, s) {
                if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                if (s.hasError) return ErrorView(error: s.error!, onRetry: _reload);
                final list = s.data!.where((u) => _q.isEmpty || '${u.name} ${u.shortName} ${u.city} ${u.state}'.toLowerCase().contains(_q)).toList();
                if (list.isEmpty) return const EmptyState(icon: Icons.school_outlined, title: 'No schools match', message: 'Try another search, or add the school.');
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    final u = list[i];
                    return ListTile(
                      title: Text(u.name),
                      subtitle: Text('${u.shortName} · ${u.kindLabel}${u.where.isEmpty ? '' : ' · ${u.where}'}'),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _edit(u),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      );
}

class _SchoolForm extends StatefulWidget {
  final University? school;
  const _SchoolForm({this.school});
  @override
  State<_SchoolForm> createState() => _SchoolFormState();
}

class _SchoolFormState extends State<_SchoolForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.school?.name ?? '');
  late final _short = TextEditingController(text: widget.school?.shortName ?? '');
  late final _city = TextEditingController(text: widget.school?.city ?? '');
  late String? _state = nigerianStates.contains(widget.school?.state) ? widget.school!.state : null;
  late String _kind = widget.school?.kind ?? 'university';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _short.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Services.admin.saveSchool(widget.school?.id, _name.text.trim(), _short.text.trim(), _city.text.trim(), _state!, _kind);
      if (mounted) {
        showMessage(context, 'School saved.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(CS.s24, CS.s24, CS.s24, CS.s24 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(widget.school == null ? 'Add a school' : 'Edit school', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextFormField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name'), validator: (v) => (v ?? '').trim().length < 4 ? 'Enter the full name' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _short, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Short name, e.g. EKSU'), validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the short name' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _city, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Town or city'), validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the town' : null),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _state,
                decoration: const InputDecoration(labelText: 'State'),
                items: [for (final s in nigerianStates) DropdownMenuItem(value: s, child: Text(s))],
                onChanged: (v) => setState(() => _state = v),
                validator: (v) => v == null ? 'Choose a state' : null,
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                for (final e in const {'university': 'University', 'polytechnic': 'Polytechnic', 'college_of_education': 'College of Education'}.entries)
                  ChoiceChip(label: Text(e.value), selected: _kind == e.key, onSelected: (_) => setState(() => _kind = e.key)),
              ]),
              const SizedBox(height: 20),
              PrimaryButton(label: 'Save', loading: _busy, onPressed: _save),
            ]),
          ),
        ),
      );
}
