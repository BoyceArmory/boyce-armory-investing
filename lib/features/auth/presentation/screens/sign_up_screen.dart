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

  bool _acceptRisk = false;
  bool _acceptTerms = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptRisk || !_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please review and accept both disclosures to continue.')),
      );
      return;
    }
    final bool ok = await ref.read(authControllerProvider.notifier).signUp(
          email: _email.text,
          password: _password.text,
          displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
        );
    if (!mounted) return;
    if (ok) context.go(RoutePaths.home);
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
                      child: Text('Join Boyce Armory.', style: context.text.displaySmall),
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
                          if (v == null || v.trim().isEmpty) return 'Email is required.';
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
                          if (v == null || v.length < 8) return 'Use at least 8 characters.';
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ---- Risk disclosure ----
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 270),
                      child: _DisclosureBox(
                        title: 'Trading risk acknowledgement',
                        body: 'Boyce Armory provides educational content, market scans, and '
                            'stock trade call-outs. We are not a registered investment advisor, '
                            'broker-dealer, or financial planner. Nothing here is personalized '
                            'investment advice.\n\n'
                            'Trading stocks involves risk of loss, including the risk of losing '
                            'your full investment. Short positions and any use of margin can '
                            'result in losses beyond your original investment. Past performance '
                            '— actual or simulated — does not guarantee future results. All trading '
                            'decisions are your own. Consult a licensed financial professional before '
                            'acting on any idea you see in this app.',
                        accepted: _acceptRisk,
                        onChanged: (v) => setState(() => _acceptRisk = v),
                        checkboxLabel: 'I understand and accept the trading risks.',
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ---- TOS + Privacy ----
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 310),
                      child: _DisclosureBox(
                        title: 'Terms of Service & Privacy Policy',
                        body: 'By creating an account you agree to our Terms of Service and Privacy '
                            'Policy. You can request deletion of your account at any time from the '
                            'Profile tab — that action permanently removes your account, stops all '
                            'push notifications, and anonymizes your historical activity.',
                        accepted: _acceptTerms,
                        onChanged: (v) => setState(() => _acceptTerms = v),
                        checkboxLabel: 'I agree to the Terms of Service and Privacy Policy.',
                        links: const [
                          _LinkPair('Terms of Service', 'https://www.boycearmory.com/terms'),
                          _LinkPair('Privacy Policy', 'https://www.boycearmory.com/privacy'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    if (state.error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.bearishMuted.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.bearish.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.error_outline, color: AppColors.bearish, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(state.error!,
                                  style: context.text.bodySmall
                                      ?.copyWith(color: AppColors.textPrimary)),
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
                        Text('Already have an account?', style: context.text.bodySmall),
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

class _LinkPair {
  const _LinkPair(this.label, this.url);
  final String label;
  final String url;
}

class _DisclosureBox extends StatelessWidget {
  const _DisclosureBox({
    required this.title,
    required this.body,
    required this.accepted,
    required this.onChanged,
    required this.checkboxLabel,
    this.links = const [],
  });
  final String title;
  final String body;
  final bool accepted;
  final ValueChanged<bool> onChanged;
  final String checkboxLabel;
  final List<_LinkPair> links;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.graphite,
        border: Border.all(color: AppColors.steel),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800,
                  letterSpacing: 0.3)),
          const SizedBox(height: 8),
          Text(body,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11.5, height: 1.45)),
          if (links.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              children: links
                  .map((l) => TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 28),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          foregroundColor: AppColors.gold,
                        ),
                        onPressed: () {
                          // url_launcher would open the link; for now show a snackbar so
                          // users see where to go. Swap to launchUrl() once you add the
                          // url_launcher dep.
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Open ${l.url}')),
                          );
                        },
                        child: Text(l.label,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                      ))
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 4),
          InkWell(
            onTap: () => onChanged(!accepted),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Checkbox(
                    value: accepted,
                    onChanged: (v) => onChanged(v ?? false),
                    activeColor: AppColors.gold,
                    checkColor: AppColors.obsidian,
                    side: const BorderSide(color: AppColors.textTertiary),
                  ),
                  Expanded(
                    child: Text(
                      checkboxLabel,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
