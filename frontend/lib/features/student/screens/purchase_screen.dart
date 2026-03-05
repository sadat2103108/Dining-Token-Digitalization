import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/student_api_service.dart';

class PurchaseScreen extends StatefulWidget {
  final StudentApiService apiService;

  const PurchaseScreen({super.key, required this.apiService});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<MealOption> _meals = [];
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableTokens();
  }

  Future<void> _loadAvailableTokens() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final available = await widget.apiService.getAvailableTokens();
      if (!mounted) return;
      setState(() {
        _meals = available
            .map((t) => MealOption(
                  mealId: t.mealId,
                  mealType: t.tokenType,
                  price: t.price,
                  time: t.time,
                  menu: t.menu,
                  icon: t.tokenType == 'Lunch'
                      ? Icons.wb_sunny_outlined
                      : Icons.nightlight_outlined,
                  accentColor: t.tokenType == 'Lunch'
                      ? Colors.orange
                      : Colors.deepPurple,
                  date: t.date,
                  purchaseEndTime: t.purchaseEndTime,
                ))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load available tokens.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePurchase(MealOption meal) async {
    if (_isPurchasing) return;
    setState(() => _isPurchasing = true);

    try {
      await widget.apiService.purchaseToken(
        PurchaseTokenRequest(mealId: meal.mealId),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${meal.mealType} token purchased!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchase failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buy Tomorrow\'s Token'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: theme.colorScheme.error),
                        const SizedBox(height: 16),
                        Text(_errorMessage!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadAvailableTokens,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _meals.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.no_meals_outlined,
                                size: 48,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(height: 16),
                            Text(
                              'No tokens available right now',
                              style: theme.textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tomorrow\'s meal tokens can only be purchased during the window set by the dining manager.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAvailableTokens,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _meals.length,
                        itemBuilder: (context, index) {
                          final meal = _meals[index];
                          return _buildMealCard(theme, meal);
                        },
                      ),
                    ),
    );
  }

  String _formatMealDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final weekday = weekdays[date.weekday - 1];
      final month = months[date.month - 1];
      return '$weekday, $month ${date.day}'; // e.g. "Fri, Mar 6"
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildMealCard(ThemeData theme, MealOption meal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meal date banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Tomorrow — ${_formatMealDate(meal.date)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (meal.purchaseEndTime != null) ...[
                    const Spacer(),
                    Icon(Icons.timer_outlined,
                        size: 14, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      'Ends ${meal.purchaseEndTime}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: meal.accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(meal.icon, color: meal.accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    meal.mealType,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '৳${meal.price}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Menu label
            Text(
              'Menu',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // Menu items as chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: meal.menu
                  .map(
                    (item) => Chip(
                      label: Text(item),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                  .toList(),
            ),

            const SizedBox(height: 16),

            // Buy button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text('Confirm Purchase'),
                      content: Text(
                          'Buy ${meal.mealType} token for ৳${meal.price}?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: _isPurchasing
                              ? null
                              : () => _handlePurchase(meal),
                          child: _isPurchasing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Text('Confirm'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.shopping_cart_outlined),
                label: Text('Buy ${meal.mealType} Token'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}