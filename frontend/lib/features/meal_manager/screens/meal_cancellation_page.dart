import 'package:flutter/material.dart';
import '../models/meal_config.dart';
import '../services/meal_manager_service.dart';

/// Page for the Meal Manager to cancel meals.
///
/// Shows today's and tomorrow's meal configs. The manager can cancel
/// a meal which will:
///   1. Mark the meal as closed
///   2. Auto-refund all students who purchased tokens
///   3. Remove the meal from the student's available meals
///
/// API: POST /meals/config/{id}/cancel
class MealCancellationPage extends StatefulWidget {
  const MealCancellationPage({super.key});

  @override
  State<MealCancellationPage> createState() => _MealCancellationPageState();
}

class _MealCancellationPageState extends State<MealCancellationPage> {
  final _service = MealManagerService();

  bool _loading = true;
  List<MealConfig> _todayMeals = [];
  List<MealConfig> _tomorrowMeals = [];
  final Set<int> _cancellingIds = {};

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  String _dateToString(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _dateToDisplay(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _loadMeals() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final results = await Future.wait([
        _service.getMealConfigByDate(_dateToString(now)),
        _service.getMealConfigByDate(_dateToString(tomorrow)),
      ]);
      if (mounted) {
        setState(() {
          _todayMeals = results[0];
          _tomorrowMeals = results[1];
        });
      }
    } catch (_) {
      // handle error
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelMeal(MealConfig meal) async {
    if (meal.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Meal'),
        content: Text(
          'Are you sure you want to cancel ${meal.mealType.displayName} '
          'for ${meal.date}?\n\n'
          'All students who purchased tokens (৳${meal.price.toStringAsFixed(0)} each) '
          'will be automatically refunded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No, Keep It'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, Cancel & Refund'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancellingIds.add(meal.id!));
    try {
      final success = await _service.cancelMeal(meal.id!);
      if (!mounted) return;
      if (success) {
        _showSnackBar(
          '${meal.mealType.displayName} cancelled and refunds processed!',
          isSuccess: true,
        );
        await _loadMeals();
      } else {
        _showSnackBar('Failed to cancel meal. Please try again.');
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _cancellingIds.remove(meal.id!));
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cancel Meal')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMeals,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Header Card ──
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.errorContainer.withAlpha(40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                          color: theme.colorScheme.error.withAlpha(50)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error.withAlpha(30),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.cancel_outlined,
                                color: theme.colorScheme.error, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cancel Meal',
                                  style:
                                      theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Cancel a meal to auto-refund all students',
                                  style:
                                      theme.textTheme.bodySmall?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Today's Meals ──
                  if (_todayMeals.isNotEmpty) ...[
                    _sectionHeader(theme, "Today — ${_dateToDisplay(DateTime.now())}"),
                    const SizedBox(height: 8),
                    ..._todayMeals.map((meal) => _buildMealCard(theme, meal)),
                    const SizedBox(height: 20),
                  ],

                  // ── Tomorrow's Meals ──
                  if (_tomorrowMeals.isNotEmpty) ...[
                    _sectionHeader(
                        theme,
                        "Tomorrow — ${_dateToDisplay(DateTime.now().add(const Duration(days: 1)))}"),
                    const SizedBox(height: 8),
                    ..._tomorrowMeals.map((meal) => _buildMealCard(theme, meal)),
                    const SizedBox(height: 20),
                  ],

                  // ── No meals ──
                  if (_todayMeals.isEmpty && _tomorrowMeals.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.restaurant_menu,
                                size: 48,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withAlpha(100)),
                            const SizedBox(height: 12),
                            Text(
                              'No meals configured for today or tomorrow',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildMealCard(ThemeData theme, MealConfig meal) {
    final isCancelling = meal.id != null && _cancellingIds.contains(meal.id!);
    final isAlreadyCancelled = meal.isClosed;
    final isLunch = meal.mealType == MealType.lunch;
    final color = isAlreadyCancelled
        ? Colors.grey
        : (isLunch ? Colors.blue : Colors.orange);
    final icon = isLunch ? Icons.wb_sunny_outlined : Icons.nightlight_outlined;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withAlpha(60)),
      ),
      color: color.withAlpha(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.mealType.displayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '৳${meal.price.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (meal.menu.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                meal.menu,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            if (isAlreadyCancelled)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.grey, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Already Cancelled',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isCancelling ? null : () => _cancelMeal(meal),
                  icon: isCancelling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(
                      isCancelling ? 'Cancelling...' : 'Cancel & Refund'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
