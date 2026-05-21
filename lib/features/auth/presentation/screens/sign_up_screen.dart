import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/buttons/primary_button.dart';
import '../../../../shared/widgets/app_background.dart';
import '../../../../shared/widgets/brand_logo.dart';
import '../providers/auth_controller.dart';
import '../widgets/auth_text_field.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final bool ok = await ref.read(authControllerProvider.notifier).signUp(
          email: _email.text,
          password: _password.text,
          displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      context.go(RoutePaths.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthFormState state = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RoutePaths.signIn),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: 6),
                    const Center(child: BrandLogo.full(size: 76)),
                    const SizedBox(height: 22),
                    FadeSlideIn(
                      child: Text('Join Boyce Armory.',
                          style: context.text.displaySmall),
                    ),
                    const SizedBox(height: 6),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 80),
                      child: Text(
                        'Get live alerts, scanner setups, and trade breakdowns.',
                        style: context.text.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 36),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 130),
                      child: AuthTextField(
                        label: 'Name (optional)',
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        prefixIcon: Icons.person_outline,
                        autofillHints: const <String>[AutofillHints.name],
                      ),
                    ),
                    const SizedBox(height: 18),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 180),
                      child: AuthTextField(
                        label: 'Email',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        prefixIcon: Icons.alternate_email,
                        autofillHints: const <String>[AutofillHints.email],
                        validator: (String? v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required.';
                          }
                          if (!v.contains('@')) return 'Enter a valid email.';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 230),
                      child: AuthTextField(
                        label: 'Password',
                        hint: 'At least 8 characters',
                        controller: _password,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        prefixIcon: Icons.lock_outline,
                        autofillHints: const <String>[AutofillHints.newPassword],
                        validator: (String? v) {
                          if (v == null || v.length < 8) {
                            return 'Use at least 8 characters.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (state.error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.bearishMuted.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.bearish.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.error_outline,
                                color: AppColors.bearish, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                state.error!,
                                style: context.text.bodySmall?.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    PrimaryButton(
                      label: 'Create account',
                      loading: state.submitting,
                      onPressed: state.submitting ? null : _submit,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text('Already have an account?',
                            style: context.text.bodySmall),
                        TextButton(
                          onPressed: () => context.go(RoutePaths.signIn),
                          child: const Text('Sign in'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
