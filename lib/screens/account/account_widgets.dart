import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_services.dart';
import '../../core/auth/auth_backend.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/l10n/app_strings.dart';

/// Opens the sign-in sheet when a personal feature needs an account.
/// Returns true if the person is signed in afterwards.
Future<bool> requireSignIn(BuildContext context) async {
  final auth = AppScope.of(context).auth;
  if (auth.isSignedIn) return true;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const SignInSheet(),
  );
  return ok == true && auth.isSignedIn;
}

class SignInSheet extends StatelessWidget {
  const SignInSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final auth = AppScope.of(context).auth;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: ListenableBuilder(
          listenable: auth,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_circle_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                s.signInRequiredTitle,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                auth.isAvailable ? s.signInRequiredBody : s.signInUnavailable,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (auth.isAvailable)
                SizedBox(
                  width: double.infinity,
                  child: _SignInButton(
                    auth: auth,
                    onDone: (ok) {
                      if (ok && context.mounted) Navigator.of(context).pop(true);
                    },
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(s.cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  final AuthController auth;
  final ValueChanged<bool>? onDone;
  const _SignInButton({required this.auth, this.onDone});

  Future<void> _go(BuildContext context) async {
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await auth.signIn();
    final msg = auth.message;
    if (msg != AuthMessage.none) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(msg == AuthMessage.cancelled ? s.signInCancelled : s.signInFailed),
        ),
      );
      auth.clearMessage();
    }
    onDone?.call(ok);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final busy = auth.status == AuthStatus.signingIn || auth.status == AuthStatus.checking;
    return FilledButton.icon(
      onPressed: busy ? null : () => _go(context),
      icon: busy
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.login_rounded),
      label: Text(busy ? s.signingIn : s.signInGoogle),
      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
    );
  }
}

Future<void> _open(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Account block for the More tab: sign in, or photo/name/email with
/// Switch account and Sign out, plus Google account help links.
class AccountCard extends StatelessWidget {
  const AccountCard({super.key});

  Future<void> _confirmSignOut(BuildContext context, AuthController auth) async {
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.signOut),
        content: Text(s.signOutConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.signOut)),
        ],
      ),
    );
    if (yes == true) {
      await auth.signOut();
      messenger.showSnackBar(SnackBar(content: Text(s.signedOutDone)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        final user = auth.user;
        Widget body;
        if (auth.status == AuthStatus.checking) {
          body = const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (auth.status == AuthStatus.unavailable) {
          body = ListTile(
            leading: const Icon(Icons.cloud_off_rounded),
            title: Text(s.signInUnavailable),
          );
        } else if (user == null) {
          body = Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.signInBenefit, style: text.bodyMedium),
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: _SignInButton(auth: auth)),
              ],
            ),
          );
        } else {
          body = Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Avatar(user: user),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (user.name.isNotEmpty)
                            Text(
                              user.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          Text(
                            user.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: auth.status == AuthStatus.signingIn
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await auth.signIn();
                              if (auth.message == AuthMessage.failed) {
                                messenger.showSnackBar(SnackBar(content: Text(s.signInFailed)));
                              }
                              auth.clearMessage();
                            },
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: Text(s.switchAccount),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _confirmSignOut(context, auth),
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(s.signOut),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: scheme.surfaceContainerLow,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              body,
              if (auth.isAvailable) ...[
                const Divider(height: 1),
                ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: const Icon(Icons.help_outline_rounded),
                  title: Text(s.googleHelp),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.manage_accounts_outlined),
                      title: Text(s.manageGoogle),
                      onTap: () => _open('https://myaccount.google.com'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.mail_outline_rounded),
                      title: Text(s.openGmail),
                      onTap: () => _open('https://mail.google.com'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.person_add_alt_1_outlined),
                      title: Text(s.createGoogle),
                      onTap: () => _open('https://accounts.google.com/signup'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.lock_reset_rounded),
                      title: Text(s.recoverAccount),
                      onTap: () => _open('https://accounts.google.com/signin/recovery'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  final AppUser user;
  const _Avatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = CircleAvatar(
      radius: 28,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        user.initial,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
    final url = user.photoUrl;
    if (url == null || url.isEmpty) return initial;
    return ClipOval(
      child: Image.network(
        url,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => initial,
        loadingBuilder: (context, child, progress) => progress == null ? child : initial,
      ),
    );
  }
}

/// Small card used on the Study tab: sign-in prompt, or a short "you're in" note.
class SignInPromptCard extends StatelessWidget {
  const SignInPromptCard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        if (!auth.isAvailable) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: scheme.primaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: auth.isSignedIn
                  ? Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: scheme.onPrimaryContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            s.signedInStudyNote,
                            style: TextStyle(color: scheme.onPrimaryContainer),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.signInBenefit, style: TextStyle(color: scheme.onPrimaryContainer)),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => requireSignIn(context),
                          icon: const Icon(Icons.login_rounded),
                          label: Text(s.signInGoogle),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
