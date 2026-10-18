import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/errors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/error_views.dart';
import '../../core/widgets/state_views.dart';
import '../../data/auth_service.dart';

/// Forgot password, all inside the app: email, then the 6-digit code from the email, then a new password.
class ResetPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ResetPasswordScreen({super.key, this.initialEmail = ''});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _sent = false, _busy = false, _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _validEmail => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  Future<void> _send() async {
    if (!_validEmail) {
      showError(context, const AppException(AppErrorKind.invalid, detail: 'Enter the email you signed up with.'));
      return;
    }
    if (AppConfig.devMode) {
      showError(context, const AppException(AppErrorKind.invalid, detail: 'Password reset needs Supabase to be configured.'));
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthService.sendResetCode(_email.text.trim());
      if (mounted) {
        setState(() => _sent = true);
        showMessage(context, 'If that email has an account, a code is on its way.');
      }
    } catch (e) {
      if (mounted) showError(context, e, onRetry: _send);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AuthService.resetWithCode(_email.text.trim(), _code.text.trim(), _password.text);
      if (mounted) {
        showMessage(context, 'Password changed. Please log in with the new one.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Reset password')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(CS.s24),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(_sent ? 'Enter the code from your email' : 'We will email you a code', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(_sent ? 'Check your inbox and spam folder. The code works for a short time only.' : 'Type the email you signed up with.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                enabled: !_sent,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
              ),
              if (!_sent) ...[
                const SizedBox(height: 20),
                PrimaryButton(label: 'Send me a code', loading: _busy, onPressed: _send),
              ] else ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                  style: const TextStyle(fontSize: 22, letterSpacing: 4, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(labelText: 'Code from the email', counterText: ''),
                  validator: (v) => RegExp(r'^\d{6,10}$').hasMatch((v ?? '').trim()) ? null : 'Enter the 6-digit code',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _hide,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(tooltip: _hide ? 'Show password' : 'Hide password', icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _hide = !_hide)),
                  ),
                  validator: (v) => (v ?? '').length < 8 ? 'Use at least 8 characters' : null,
                ),
                const SizedBox(height: 20),
                PrimaryButton(label: 'Change password', loading: _busy, onPressed: _reset),
                TextButton(onPressed: _busy ? null : _send, child: const Text('Send a new code')),
              ],
            ]),
          ),
        ),
      );
}
