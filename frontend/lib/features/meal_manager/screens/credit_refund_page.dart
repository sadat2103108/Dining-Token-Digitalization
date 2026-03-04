import 'package:flutter/material.dart';
import '../models/credit_refund.dart';
import '../models/meal_config.dart';
import '../services/meal_manager_service.dart';
import '../widgets/refund_meal_card.dart';

/// Page for managing credit refunds.
///
/// The first tab shows **today's meals** so the manager can refund
/// everyone who bought a token for a specific meal in one tap
/// (uses POST /refunds/process-bulk).
/// The second tab shows completed refund history.
class CreditRefundPage extends StatefulWidget {
  const CreditRefundPage({super.key});

  @override
  State<CreditRefundPage> createState() => _CreditRefundPageState();
}

class _CreditRefundPageState extends State<CreditRefundPage>
    with SingleTickerProviderStateMixin {
  final _service = MealManagerService();

  late TabController _tabController;

  // State
  bool _loading = true;
  List<MealConfig> _todayMeals = [];
  List<RefundableMeal> _historyMeals = [];
  final Set<int> _processingIds = {}; // meal ids currently being refunded

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.getMealConfigByDate(_todayDate),
        _service.getRefundHistory(),
      ]);
      if (mounted) {
        setState(() {
          _todayMeals = results[0] as List<MealConfig>;
          _historyMeals = results[1] as List<RefundableMeal>;
        });
      }
    } catch (_) {
      // handle error
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refundMeal(MealConfig meal) async {
    if (meal.id == null) return;

    final confirmed = await _showRefundConfirmDialog(
      context,
      title: 'Confirm Refund',
      message:
          'Refund all students who bought a ${meal.mealType == MealType.lunch ? "Lunch" : "Dinner"} '
          'token for today (${_formatDate(meal.date)})?\n\n'
          'Price per token: ৳${meal.price.toStringAsFixed(0)}',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processingIds.add(meal.id!));
    try {
      final success = await _service.processBulkRefund([meal.id.toString()]);
      if (!mounted) return;
      if (success) {
        _showSnackBar(
          '${meal.mealType == MealType.lunch ? "Lunch" : "Dinner"} refund processed successfully!',
          isSuccess: true,
        );
        await _loadData();
      } else {
        _showSnackBar('Failed to process refund. Please try again.');
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _processingIds.remove(meal.id!));
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

  Future<bool?> _showRefundConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.currency_exchange,
                color: Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('Confirm Refund'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit Refund'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.restaurant_menu, size: 18),
                  const SizedBox(width: 6),
                  const Text("Today's Meals"),
                  if (_todayMeals.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _todayMeals.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 18),
                  SizedBox(width: 6),
                  Text('History'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildTodayMealsTab(theme), _buildHistoryTab(theme)],
            ),
    );
  }

  // ── Today's Meals tab ──
  Widget _buildTodayMealsTab(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _todayMeals.isEmpty
          ? _buildEmptyState(
              icon: Icons.restaurant_outlined,
              title: 'No Meals Today',
              subtitle: 'No meal configurations found for today.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.indigo.shade50],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blue.withAlpha(40)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Today's Meals — ${_formatDate(_todayDate)}",
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tap Refund to credit all token holders for that meal.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Meal cards
                ..._todayMeals.map((meal) => _buildTodayMealCard(theme, meal)),
              ],
            ),
    );
  }

  // ── Today meal card ──
  Widget _buildTodayMealCard(ThemeData theme, MealConfig meal) {
    final isLunch = meal.mealType == MealType.lunch;
    final mealColor = isLunch ? Colors.orange : Colors.indigo;
    final isProcessing = meal.id != null && _processingIds.contains(meal.id!);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Meal icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: mealColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isLunch
                        ? Icons.wb_sunny_outlined
                        : Icons.nightlight_outlined,
                    color: mealColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLunch ? 'Lunch' : 'Dinner',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: mealColor.withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '৳${meal.price.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: mealColor,
                              ),
                            ),
                          ),
                          if (meal.purchaseDeadline != null) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              meal.purchaseDeadline!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (meal.menu.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          meal.menu,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Refund button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isProcessing ? null : () => _refundMeal(meal),
                icon: isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.currency_exchange, size: 18),
                label: Text(
                  isProcessing ? 'Processing...' : 'Refund All Buyers',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 12),
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

  void _showStudentList(RefundableMeal meal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _StudentListSheet(meal: meal),
    );
  }

  // ── History tab ──
  Widget _buildHistoryTab(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _historyMeals.isEmpty
          ? _buildEmptyState(
              icon: Icons.history,
              title: 'No Refund History',
              subtitle: 'Processed refunds will appear here.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ..._historyMeals.map(
                  (meal) => RefundMealCard(
                    meal: meal,
                    onViewStudents: () => _showStudentList(meal),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Empty state ──
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String date) {
    try {
      final d = DateTime.parse(date);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return date;
    }
  }
}

// ─── Bottom sheet showing the list of students for a refundable meal ───

class _StudentListSheet extends StatelessWidget {
  final RefundableMeal meal;

  const _StudentListSheet({required this.meal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLunch = meal.mealType == MealType.lunch;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isLunch ? Colors.orange : Colors.indigo)
                          .withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.people,
                      color: isLunch ? Colors.orange : Colors.indigo,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${isLunch ? "Lunch" : "Dinner"} · ${_formatDate(meal.date)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${meal.tokensSold} students · ৳${meal.totalRefundAmount.toStringAsFixed(0)} total',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Student list
            Expanded(
              child: meal.students.isEmpty
                  ? Center(
                      child: Text(
                        'Student details will load from backend',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: meal.students.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final student = meal.students[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withAlpha(80),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: theme.colorScheme.primary
                                    .withAlpha(25),
                                child: Text(
                                  student.studentName.isNotEmpty
                                      ? student.studentName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student.studentName,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      'Roll: ${student.studentRoll}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '৳${student.amountPaid.toStringAsFixed(0)}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.red.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(String date) {
    try {
      final d = DateTime.parse(date);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return date;
    }
  }
}
