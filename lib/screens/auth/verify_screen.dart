import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/friendly_error.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

class VerifyScreen extends ConsumerWidget {
  const VerifyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authServiceProvider);
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    Future<void> run(Future<void> Function() f, String ok) async {
      try {
        await f();
        if (context.mounted) showSnack(context, ok);
      } catch (e) {
        if (context.mounted) showSnack(context, friendlyError(e), error: true);
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Icon(Icons.mark_email_unread_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text('Verify your email', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('We sent a link to\n$email\nOpen it, then tap the button below. Check spam if you can\'t find it.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => run(auth.reloadUser, 'Checked. If verified, you\'ll be taken in.'),
                  child: const Text('I\'ve verified my email'),
                ),
                OutlinedButton(
                  onPressed: () => run(auth.resendVerification, 'Verification email sent again.'),
                  child: const Text('Resend email'),
                ),
                TextButton(onPressed: auth.signOut, child: const Text('Use a different account')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
