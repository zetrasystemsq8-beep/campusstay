import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/buttons.dart';
import 'auth_screen.dart';

class RoleScreen extends StatefulWidget {
  const RoleScreen({super.key});
  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  String _role = 'student';

  static const _roles = [
    ('student', 'Student', 'Find and book accommodation', Icons.school_outlined),
    ('landlord', 'Landlord', 'List your property, reach students', Icons.home_outlined),
    ('agent', 'Agent / Property manager', 'Manage multiple properties', Icons.badge_outlined),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: CS.bg, elevation: 0),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(CS.s24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Choose your role', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text('Select how you want to use CampusStay.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 24),
              for (final r in _roles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(CS.rMd),
                    onTap: () => setState(() => _role = r.$1),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(CS.rMd),
                        border: Border.all(color: _role == r.$1 ? CS.blue : CS.line, width: _role == r.$1 ? 2 : 1),
                        color: _role == r.$1 ? CS.blueSoft : CS.bg,
                      ),
                      child: Row(children: [
                        Icon(r.$4, color: CS.blue, size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(r.$2, style: Theme.of(context).textTheme.titleMedium),
                            Text(r.$3, style: Theme.of(context).textTheme.bodySmall),
                          ]),
                        ),
                        if (_role == r.$1) const Icon(Icons.check_circle, color: CS.blue),
                      ]),
                    ),
                  ),
                ),
              const Spacer(),
              if (_role != 'student')
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('Listing is free. There are no listing fees and no commission. '
                      'Listings are reviewed before they appear to students.',
                      style: TextStyle(color: CS.green, fontWeight: FontWeight.w600)),
                ),
              PrimaryButton(
                label: 'Continue',
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => AuthScreen(role: _role, startInSignUp: true))),
              ),
            ]),
          ),
        ),
      );
}
