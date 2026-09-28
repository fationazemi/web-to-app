import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../app.dart';
import '../billing/billing_service.dart';
import '../settings/app_settings.dart';
import '../theme/app_theme.dart';

/// Shows the freemium upgrade sheet.
Future<void> showProSheet(BuildContext context, {String? reason}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _ProSheet(reason: reason),
  );
}

class _ProSheet extends StatefulWidget {
  const _ProSheet({this.reason});

  final String? reason;

  @override
  State<_ProSheet> createState() => _ProSheetState();
}

class _ProSheetState extends State<_ProSheet> {
  static const _benefits = [
    (Icons.all_inclusive, 'Unlimited drawings', 'Free accounts keep up to ${AppSettings.freeDrawingLimit} sketches.'),
    (Icons.layers_outlined, 'Up to ${AppSettings.proLayerLimit} layers', 'Free accounts get ${AppSettings.freeLayerLimit} layers per sketch.'),
    (Icons.palette_outlined, 'Custom colors', 'Pick any color with the HSV picker.'),
    (Icons.movie_creation_outlined, 'Time-lapse export', 'Share an animated GIF of your process.'),
    (Icons.hd_outlined, 'High-resolution export', 'Share crisp 4x PNGs.'),
  ];

  @override
  void initState() {
    super.initState();
    // Query the store lazily, only when someone actually opens this sheet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).billing.init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final settings = scope.settings;
    final billing = scope.billing;
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: ListenableBuilder(
          listenable: Listenable.merge([settings, billing]),
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(20)),
                      child: const Text('PRO',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                    const SizedBox(width: 10),
                    Text('Sketch Pro', style: theme.textTheme.titleLarge),
                  ],
                ),
                if (widget.reason != null) ...[
                  const SizedBox(height: 8),
                  Text(widget.reason!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 12),
                for (final (icon, title, subtitle) in _benefits)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accentSoft,
                      foregroundColor: AppColors.ink,
                      child: Icon(icon, size: 20),
                    ),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(subtitle),
                  ),
                const SizedBox(height: 16),
                if (settings.isPro)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.verified, color: AppColors.orange),
                    title: Text('You are on Sketch Pro', style: TextStyle(fontWeight: FontWeight.w700)),
                  )
                else ...[
                  if (billing.available) ...[
                    for (final product in billing.products) _ProductButton(product: product, billing: billing),
                  ] else
                    Text(
                      billing.error ?? 'The store is not available on this device right now.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: billing.busy ? null : billing.restore,
                    child: const Text('Restore purchases'),
                  ),
                  if (kDebugMode)
                    TextButton(
                      onPressed: () {
                        settings.setPro(true);
                        Navigator.pop(context);
                      },
                      child: const Text('Activate Pro (debug build only)'),
                    ),
                ],
                if (billing.error != null && billing.available)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(billing.error!, textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                  ),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Maybe later')),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProductButton extends StatelessWidget {
  const _ProductButton({required this.product, required this.billing});

  final ProductDetails product;
  final BillingService billing;

  @override
  Widget build(BuildContext context) {
    final lifetime = product.id == BillingService.lifetimeId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FilledButton(
        onPressed: billing.busy ? null : () => billing.buy(product),
        style: lifetime ? null : FilledButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white),
        child: billing.busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Text('${lifetime ? 'Lifetime' : 'Monthly'} · ${product.price}'),
      ),
    );
  }
}
