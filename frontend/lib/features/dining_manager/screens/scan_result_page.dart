import 'package:flutter/material.dart';
import 'package:frontend/features/dining_manager/services/dining_service.dart';

class ScanResultPage extends StatelessWidget {
  final ScanResult result;
  final VoidCallback onScanAnother;

  const ScanResultPage({
    super.key,
    required this.result,
    required this.onScanAnother,
  });

  @override
  Widget build(BuildContext context) {
    final isValid = result.isValid;
    final color = isValid ? Colors.green : Colors.red;
    final icon =
        isValid ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Scan Result'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      // Large status icon
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.1),
                        ),
                        child: Icon(icon, size: 80, color: color),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        isValid ? 'Valid Token' : 'Invalid Token',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 28),
                      // Details card
                      _DetailsCard(result: result),
                      const Spacer(flex: 3),
                      // Scan Another button
                      FilledButton.icon(
                        onPressed: onScanAnother,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Scan Another'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Details Card ──────────────────────────────────────

class _DetailsCard extends StatelessWidget {
  final ScanResult result;
  const _DetailsCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          children: [
            if (result.mealType != null)
              _row(context, Icons.restaurant_rounded, 'Meal Type',
                  result.mealType!),
            if (result.ownerName != null)
              _row(context, Icons.person_rounded, 'Student',
                  result.ownerName!),
            if (result.mealDate != null)
              _row(context, Icons.calendar_today_rounded, 'Meal Date',
                  result.mealDate!),
            if (result.tokenId != null)
              _row(context, Icons.confirmation_number_rounded, 'Token ID',
                  '#${result.tokenId}'),
            if (result.status != null)
              _row(context, Icons.info_rounded, 'Status',
                  result.status!),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext ctx, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Text(label,
              style: Theme.of(ctx)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600])),
          const Spacer(),
          Text(value,
              style: Theme.of(ctx)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
