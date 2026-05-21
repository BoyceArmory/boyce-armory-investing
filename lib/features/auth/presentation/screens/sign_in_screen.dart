import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/buttons/primary_button.dart';
import '../../../../shared/widgets/app_background.dart';
import '../../../../shared/widgets/brand_logo.dart';
import '../providers/auth_controller.dart';
import '../widgets/auth_text_field.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final bool ok = await ref.read(authControllerProvider.notifier).signIn(
          email: _email.text,
          password: _password.text,
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
      body: AppBackground(
        child: SafeArea(
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: 18),
                    const Center(child: BrandLogo.full(size: 96)),
                    const SizedBox(height: 22),
                    FadeSlideIn(
                      child: Text(
                        AppConstants.appName.toUpperCase(),
                        style: context.text.labelMedium
                            ?.copyWith(color: AppColors.gold, letterSpacing: 4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 60),
                      child: Text('Welcome back.', style: context.text.displaySmall),
                    ),
                    const SizedBox(height: 6),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 110),
                      child: Text(
                        'Sign in to access your alerts, scanner, and trade plan.',
                        style: context.text.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 36),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 160),
                      child: AuthTextField(
                        label: 'Email',
                        hint: 'you@boyce.io',
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
                      delay: const Duration(milliseconds: 210),
                      child: AuthTextField(
                        label: 'Password',
                        hint: '••••••••',
                        controller: _password,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        prefixIcon: Icons.lock_outline,
                        autofillHints: const <String>[AutofillHints.password],
                        validator: (String? v) {
                          if (v == null || v.isEmpty) {
                            return 'Password is required.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () =>
                            context.go(RoutePaths.forgotPassword),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 14),
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
                      label: 'Sign in',
                      loading: state.submitting,
                      onPressed: state.submitting ? null : _submit,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text("Don't have an account?",
                            style: context.text.bodySmall),
                        TextButton(
                          onPressed: () => context.go(RoutePaths.signUp),
                          child: const Text('Create one'),
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
