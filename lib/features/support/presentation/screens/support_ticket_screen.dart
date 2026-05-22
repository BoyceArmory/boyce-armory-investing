import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/api_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/support_repository.dart';

/// "Send a trouble ticket" form. Submits to /api/support/tickets and shows
/// the new ticket id on success.
class SupportTicketScreen extends ConsumerStatefulWidget {
  const SupportTicketScreen({super.key});
  @override
  ConsumerState<SupportTicketScreen> createState() => _SupportTicketScreenState();
}

class _SupportTicketScreenState extends ConsumerState<SupportTicketScreen> {
  String _category = 'bug';
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subject.text.trim();
    final message = _message.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject and message are required.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final repo = SupportRepository(apiClient: ref.read(apiClientProvider));
      final id = await repo.submitTicket(
        category: _category,
        subject: subject,
        message: message,
        platform: defaultTargetPlatform.name,
      );
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.graphite,
          title: const Text('Ticket submitted',
              style: TextStyle(color: AppColors.textPrimary)),
          content: Text(
            'Reference: $id\n\nWe\'ll follow up by email. Thank you for the report.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.obsidian,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                if (mounted) context.pop();
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submit failed: $e'), backgroundColor: AppColors.bearish),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: AppColors.obsidian,
        title: const Text('Send a ticket',
            style: TextStyle(letterSpacing: 0.6, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const Text('Category',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12, letterSpacing: 0.4)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: const [
                'bug',
                'feature',
                'billing',
                'account',
                'other',
              ].map((c) {
                return ChoiceChip(
                  label: Text(c.toUpperCase()),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                  selectedColor: AppColors.gold.withValues(alpha: 0.22),
                  backgroundColor: AppColors.graphite,
                  side: BorderSide(
                    color: _category == c
                        ? AppColors.gold.withValues(alpha: 0.6)
                        : AppColors.steel,
                  ),
                  labelStyle: TextStyle(
                    color: _category == c ? AppColors.gold : AppColors.textSecondary,
                    fontSize: 11, fontWeight: FontWeight.w700,
                  ),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _subject,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: _decoration('Subject'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              maxLines: 8,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: _decoration('Describe what happened. Steps to reproduce help us a lot.'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.obsidian),
                      )
                    : const Icon(Icons.send, size: 16),
                label: Text(_submitting ? 'Sending…' : 'Submit ticket'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.obsidian,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your email and account ID are attached automatically — you don\'t need to include them.',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
        filled: true,
        fillColor: AppColors.graphite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.steel),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}
