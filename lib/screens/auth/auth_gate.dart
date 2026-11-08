import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/friendly_error.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/vaulta_logo.dart';
import '../shell/shell.dart';
import 'auth_screen.dart';
import 'lock_screen.dart';
import 'verify_screen.dart';

/// Decides what to show: sign-in, verify email, club setup, lock, app.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});
  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(lockEnabledProvider)) ref.read(lockedProvider.notifier).state = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        ref.read(lockEnabledProvider) &&
        !ref.read(lockSuspendProvider)) {
      ref.read(lockedProvider.notifier).state = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Demo mode: straight into the app with sample data (no sign-in, no Firebase).
    if (ref.watch(demoModeProvider)) return const Shell();

    Widget splash() => const Scaffold(body: LoadingView());
    return ref.watch(authStateProvider).when(
          loading: splash,
          error: (e, _) => Scaffold(body: ErrorView(friendlyError(e))),
          data: (user) {
            if (user == null) return const AuthScreen();
            if (!user.emailVerified) return const VerifyScreen();
            return ref.watch(clubProvider).when(
                  loading: splash,
                  error: (e, _) => _ClubError(error: e),
                  data: (club) {
                    if (club == null) {
                      // Google accounts carry a person's name, not a club name, so ask for it.
                      final viaGoogle = user.providerData.any((p) => p.providerId == 'google.com');
                      return viaGoogle
                          ? _ClubNameScreen(email: user.email ?? '', uid: user.uid)
                          : _ClubSetup(name: user.displayName ?? 'My Club', email: user.email ?? '', uid: user.uid);
                    }
                    if (ref.watch(lockedProvider)) return const LockScreen();
                    return const Shell();
                  },
                );
          },
        );
  }
}

/// Shown when the club data can't be loaded. Refreshing the sign-in token
/// fixes the common "email just verified but rules still say no" case.
class _ClubError extends ConsumerWidget {
  const _ClubError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(friendlyError(error), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  await FirebaseAuth.instance.currentUser?.getIdToken(true);
                  ref.invalidate(clubProvider);
                },
                child: const Text('Try again'),
              ),
              TextButton(
                onPressed: () => ref.read(authServiceProvider).signOut(),
                child: const Text('Sign out'),
              ),
            ]),
          ),
        ),
      );
}

/// First sign-in after verification: create this club's profile document.
class _ClubSetup extends ConsumerStatefulWidget {
  const _ClubSetup({required this.name, required this.email, required this.uid});
  final String name, email, uid;
  @override
  ConsumerState<_ClubSetup> createState() => _ClubSetupState();
}

class _ClubSetupState extends ConsumerState<_ClubSetup> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _create());
  }

  Future<void> _create() async {
    setState(() => _error = null);
    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      await ref.read(clubRepoProvider).createIfMissing(widget.uid, widget.name, widget.email);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: _error == null
            ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(), SizedBox(height: 16), Text('Setting up your club…')]))
            : Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _create, child: const Text('Try again')),
                TextButton(onPressed: () => ref.read(authServiceProvider).signOut(), child: const Text('Sign out')),
              ]))),
      );
}

/// First Google sign-in: ask what the club is called, then create its profile.
class _ClubNameScreen extends ConsumerStatefulWidget {
  const _ClubNameScreen({required this.email, required this.uid});
  final String email, uid;
  @override
  ConsumerState<_ClubNameScreen> createState() => _ClubNameScreenState();
}

class _ClubNameScreenState extends ConsumerState<_ClubNameScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _busy = false;

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      await ref.read(clubRepoProvider).createIfMissing(widget.uid, _name.text.trim(), widget.email);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _form,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Center(child: VaultaLogo(size: 84)),
                    const SizedBox(height: 16),
                    Text('Welcome to Vaulta!', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text('Signed in as ${widget.email}.\nWhat is your club called?', textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Club name', prefixIcon: Icon(Icons.groups_outlined)),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      onFieldSubmitted: (_) => _create(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _create,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                      child: _busy
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Create my club'),
                    ),
                    TextButton(onPressed: () => ref.read(authServiceProvider).signOut(), child: const Text('Use a different account')),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}
