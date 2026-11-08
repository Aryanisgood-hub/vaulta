import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_info.dart';
import '../../core/constants/demo_config.dart';
import '../../core/errors/friendly_error.dart';
import '../../core/utils/formatters.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/vaulta_logo.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _register = false, _busy = false, _hide = true;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    setState(() => _busy = true);
    final auth = ref.read(authServiceProvider);
    try {
      if (_register) {
        await auth.register(_name.text, _email.text, _pass.text);
      } else {
        await auth.signIn(_email.text, _pass.text);
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    if (requiredField(_email.text) != null) {
      showSnack(context, 'Type your club email first, then tap "Forgot password".');
      return;
    }
    try {
      await ref.read(authServiceProvider).sendReset(_email.text);
      if (mounted) showSnack(context, 'Password reset email sent (check spam too).');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Center(child: VaultaLogo(size: 96)),
                  const SizedBox(height: 14),
                  Text(AppInfo.name, textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800)),
                  Text(AppInfo.tagline, textAlign: TextAlign.center, style: TextStyle(color: cs.outline)),
                  const SizedBox(height: 28),
                  if (_register) ...[
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Club name', prefixIcon: Icon(Icons.groups_outlined)),
                      validator: (v) => requiredField(v),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Club email', prefixIcon: Icon(Icons.mail_outline)),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pass,
                    obscureText: _hide,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                    ),
                    validator: _register ? passwordRule : (v) => requiredField(v),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (!_register)
                    Align(alignment: Alignment.centerRight,
                        child: TextButton(onPressed: _forgot, child: const Text('Forgot password?'))),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                    child: _busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_register ? 'Create club account' : 'Sign in'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _register = !_register),
                    child: Text(_register ? 'Already registered? Sign in' : 'New club? Register here'),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: cs.outline))),
                    const Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _google,
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(14)),
                    icon: Image.asset('assets/images/google_g.png', width: 22, height: 22),
                    label: const Text('Continue with Google'),
                  ),
                  if (demoEnabled) ...[
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : () => enterDemo(ref),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.all(14)),
                      icon: const Icon(Icons.explore_outlined),
                      label: const Text('Explore demo'),
                    ),
                    const SizedBox(height: 4),
                    Text('See Vaulta with sample data. Nothing is saved.',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
