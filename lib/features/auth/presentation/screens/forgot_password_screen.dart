import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../shared/buttons/primary_button.dart';
import '../../../../shared/widgets/app_background.dart';
import '../providers/auth_controller.dart';
import '../widgets/auth_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final TextEditingController _email = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final bool ok = await ref
        .read(authControllerProvider.notifier)
        .sendReset(_email.text);
    if (!mounted) return;
    if (ok) {
      setState(() => _sent = true);
      context.showSnack('Reset email sent. Check your inbox.');
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
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('Reset your password.', style: context.text.displaySmall),
                  const SizedBox(height: 6),
                  Text(
                    "Enter your email and we'll send you a reset link.",
                    style: context.text.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  AuthTextField(
                    label: 'Email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    prefixIcon: Icons.alternate_email,
                    validator: (String? v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email is required.';
                      }
                      if (!v.contains('@')) return 'Enter a valid email.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        state.error!,
                        style: context.text.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  PrimaryButton(
                    label: _sent ? 'Resend reset email' : 'Send reset email',
                    loading: state.submitting,
                    onPressed: state.submitting ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
