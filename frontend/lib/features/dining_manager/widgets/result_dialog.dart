import 'package:flutter/material.dart';

/// Reusable result dialog / bottom-sheet for quick scan feedback.
///
/// Shows an icon (green check / red cross) and a message.
/// Automatically guards against use-after-dispose via [mounted] check
/// on the calling widget's [BuildContext].
class ResultDialog {
  ResultDialog._();

  /// Show a modal bottom sheet with the scan result feedback.
  ///
  /// [context] must be from a mounted widget.
  /// Returns `true` when "Scan Another" is tapped, `null` on dismiss.
  static Future<bool?> show(
    BuildContext context, {
    required bool isValid,
    required String message,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final color = isValid ? Colors.green : Colors.red;
        final icon = isValid ? Icons.check_circle_rounded : Icons.cancel_rounded;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 64),
                const SizedBox(height: 16),
                Text(
                  isValid ? 'Valid Token' : 'Invalid Token',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan Another'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
