import 'package:flutter/material.dart';
import '../../core/widgets/error_views.dart';
import '../../core/widgets/state_views.dart';
import '../../data/auth_service.dart';
import '../admin/admin_home.dart';
import '../landlord/landlord_home.dart';
import 'student_shell.dart';

/// Routes by the role stored on the server profile.
class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  late Future<String> _role = AuthService.role();

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: _role,
        builder: (c, s) {
          if (s.hasError) {
            return Scaffold(body: ErrorView(error: s.error!, onRetry: () => setState(() => _role = AuthService.role())));
          }
          if (!s.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          if (s.data == 'admin') return const AdminHome();
          return (s.data == 'landlord' || s.data == 'agent') ? const LandlordHome() : const StudentShell();
        },
      );
}
