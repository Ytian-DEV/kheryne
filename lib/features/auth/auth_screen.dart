import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/form_factor.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import 'auth_controller.dart';

/// Cloud Sign-in / Create-account screen with Email + Password, Google Sign-In,
/// and an explicit "Continue offline on this device" option for field/lab work.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isSignUp = false;
  bool _obscure = true;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _institution = TextEditingController(text: 'Visayas State University');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _institution.dispose();
    super.dispose();
  }

  void _finishNavigation() {
    final desktop = FormFactor.of(context).isDesktop;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.goTo(desktop ? Routes.workspace : Routes.home);
    }
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _password.text;
    if (email.isEmpty || !email.contains('@')) {
      showToast(context, 'Enter a valid email address.');
      return;
    }
    if (pass.length < 6) {
      showToast(context, 'Password must be at least 6 characters.');
      return;
    }
    final auth = ref.read(authProvider.notifier);
    if (_isSignUp) {
      final ok = await auth.signUp(
        email: email,
        password: pass,
        fullName: _name.text.trim().isEmpty ? email.split('@').first : _name.text.trim(),
        institution: _institution.text.trim(),
      );
      if (ok && mounted) _finishNavigation();
    } else {
      final ok = await auth.signInWithPassword(email: email, password: pass);
      if (ok && mounted) _finishNavigation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final k = context.k;
    final t = context.t;

    ref.listen<AuthViewState>(authProvider, (prev, next) {
      if ((prev?.user == null) && next.user != null && mounted) {
        _finishNavigation();
      }
    });

    return Scaffold(
      appBar: KNavBar(
        title: _isSignUp ? 'Create account' : 'Sign in',
        actions: [
          KButton.tertiary(
            label: 'Use offline',
            size: KButtonSize.compact,
            onPressed: _finishNavigation,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(KSpace.s20, KSpace.s16, KSpace.s20, KSpace.s32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: k.primary, width: 2.5),
                    ),
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(color: k.primary, shape: BoxShape.circle),
                    ),
                  ),
                ),
                const SizedBox(height: KSpace.s16),
                Text(
                  'Sync across phone and lab computer',
                  style: t.title2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: KSpace.s8),
                Text(
                  'Your reports, micrographs, notes and microscope calibrations stay saved on this device offline and sync automatically when signed in.',
                  style: t.callout.copyWith(color: k.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: KSpace.s24),
                KSegmentedControl<bool>(
                  segments: const [
                    (false, 'Sign in', null),
                    (true, 'Create account', null),
                  ],
                  value: _isSignUp,
                  onChanged: (v) => setState(() => _isSignUp = v),
                ),
                const SizedBox(height: KSpace.s16),
                if (auth.errorMessage != null) ...[
                  StatusBanner(
                    title: 'Sign-in issue',
                    message: auth.errorMessage,
                    tone: BannerTone.error,
                    icon: KIcons.warning,
                  ),
                  const SizedBox(height: KSpace.s12),
                ],
                if (auth.infoMessage != null) ...[
                  StatusBanner(
                    title: 'Confirm your email',
                    message: auth.infoMessage,
                    tone: BannerTone.info,
                    icon: KIcons.checkCircle,
                  ),
                  const SizedBox(height: KSpace.s12),
                ],
                KCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isSignUp) ...[
                        TextField(
                          controller: _name,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Full name (shown on reports)',
                            prefixIcon: Icon(KIcons.user, size: KSize.icon),
                          ),
                        ),
                        const SizedBox(height: KSpace.s12),
                        TextField(
                          controller: _institution,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Institution / laboratory',
                            prefixIcon: Icon(KIcons.graduation, size: KSize.icon),
                          ),
                        ),
                        const SizedBox(height: KSpace.s12),
                      ],
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          prefixIcon: Icon(KIcons.globe, size: KSize.icon),
                        ),
                      ),
                      const SizedBox(height: KSpace.s12),
                      TextField(
                        controller: _password,
                        obscureText: _obscure,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(KIcons.lock, size: KSize.icon),
                          suffixIcon: KIconButton(
                            icon: _obscure ? KIcons.eye : KIcons.eyeOff,
                            label: _obscure ? 'Show password' : 'Hide password',
                            size: 18,
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: KSpace.s20),
                      KButton(
                        label: _isSignUp ? 'Create account' : 'Sign in',
                        expand: true,
                        loading: auth.busy,
                        onPressed: auth.busy ? null : _submit,
                      ),
                      const SizedBox(height: KSpace.s12),
                      KButton.secondary(
                        label: 'Continue with Google',
                        icon: KIcons.globe,
                        expand: true,
                        onPressed: auth.busy ? null : () => ref.read(authProvider.notifier).signInWithGoogle(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: KSpace.s16),
                Center(
                  child: KButton.tertiary(
                    label: 'Continue offline without signing in',
                    icon: KIcons.offlineReady,
                    onPressed: _finishNavigation,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
