import 'package:flutter/material.dart';
import '../../core/widgets/error_views.dart';
import '../../core/config.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/logo.dart';
import '../../core/widgets/state_views.dart';
import '../../data/auth_service.dart';
import '../shell/gate.dart';
import 'role_screen.dart';

class AuthScreen extends StatefulWidget {
  final String role;
  final bool startInSignUp;
  const AuthScreen({super.key, required this.role, required this.startInSignUp});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  late bool _signUp = widget.startInSignUp;
  // True once the person has picked student, landlord or agent.
  late final bool _roleChosen = widget.startInSignUp;
  bool _busy = false;
  bool _hide = true;

  void _toggleMode() {
    // Someone who opened "I already have an account" never saw the role choice.
    // If they decide to sign up, send them through it first.
    if (!_signUp && !_roleChosen) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RoleScreen()));
      return;
    }
    setState(() => _signUp = !_signUp);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  void _enter() => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const Gate()), (r) => false);

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (AppConfig.devMode) {
      AuthService.startDemo(widget.role);
      _enter();
      return;
    }
    setState(() => _busy = true);
    try {
      if (_signUp) {
        final inSession = await AuthService.signUp(_email.text.trim(), _password.text, widget.role, _name.text.trim());
        if (!mounted) return;
        if (inSession) {
          _enter();
        } else {
          showMessage(context, 'Check your email to confirm your account, then sign in.');
          setState(() => _signUp = false);
        }
      } else {
        await AuthService.signIn(_email.text.trim(), _password.text);
        if (mounted) _enter();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      showMessage(context, 'Enter your email above first.', error: true);
      return;
    }
    if (AppConfig.devMode) {
      showMessage(context, 'Password reset needs Supabase to be configured.');
      return;
    }
    try {
      await AuthService.resetPassword(email);
      if (mounted) showMessage(context, 'If that email has an account, a reset link is on its way.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: CS.bg, elevation: 0),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(CS.s24),
            child: Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Center(child: LogoLockup(size: 56)),
                const SizedBox(height: 28),
                Text(_signUp ? 'Create your ${widget.role} account' : 'Welcome back',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (_signUp) ...[
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                  validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _hide,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _hide ? 'Show password' : 'Hide password',
                      icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                  validator: (v) => (v ?? '').length < 8 ? 'Use at least 8 characters' : null,
                ),
                if (!_signUp)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: _forgot, child: const Text('Forgot password?')),
                  ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: _signUp ? 'Create account' : 'Log in',
                  loading: _busy,
                  onPressed: _submit,
                ),
                if (AppConfig.devMode)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('Development mode: this signs you into a local demo session. No account is created.',
                        textAlign: TextAlign.center, style: TextStyle(color: CS.warn, fontSize: 12.5)),
                  ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _toggleMode,
                  child: Text(_signUp ? 'Already have an account? Log in' : "Don't have an account? Sign up"),
                ),
              ]),
            ),
          ),
        ),
      );
}
