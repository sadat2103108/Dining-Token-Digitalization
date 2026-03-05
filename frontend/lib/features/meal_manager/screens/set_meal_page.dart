import 'package:flutter/material.dart';
import '../models/meal_config.dart';
import '../services/meal_manager_service.dart';

/// Combined page for Meal Manager to set menu items AND price
/// for tomorrow's lunch & dinner.
///
/// API: POST /meals/config  |  PUT /meals/config/{id}
class SetMealPage extends StatefulWidget {
  const SetMealPage({super.key});

  @override
  State<SetMealPage> createState() => _SetMealPageState();
}

class _SetMealPageState extends State<SetMealPage>
    with SingleTickerProviderStateMixin {
  final _service = MealManagerService();
  late TabController _tabController;

  bool _loading = true;
  bool _saving = false;

  // Lunch
  final List<String> _lunchItems = [];
  final _lunchItemController = TextEditingController();
  final _lunchPriceController = TextEditingController();

  // Dinner
  final List<String> _dinnerItems = [];
  final _dinnerItemController = TextEditingController();
  final _dinnerPriceController = TextEditingController();

  List<MealConfig> _configs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadConfig();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _lunchItemController.dispose();
    _lunchPriceController.dispose();
    _dinnerItemController.dispose();
    _dinnerPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    try {
      final configs = await _service.getTomorrowConfig();
      _configs = configs;

      for (final c in configs) {
        final items = c.menu
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        if (c.mealType == MealType.lunch) {
          _lunchItems
            ..clear()
            ..addAll(items);
          if (c.price > 0) _lunchPriceController.text = c.price.toString();
        } else {
          _dinnerItems
            ..clear()
            ..addAll(items);
          if (c.price > 0) _dinnerPriceController.text = c.price.toString();
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _addItem(List<String> items, TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      items.add(text);
      controller.clear();
    });
  }

  void _removeItem(List<String> items, int index) {
    setState(() => items.removeAt(index));
  }

  Future<void> _save() async {
    final lunchPrice = int.tryParse(_lunchPriceController.text.trim());
    final dinnerPrice = int.tryParse(_dinnerPriceController.text.trim());

    if (lunchPrice == null && _lunchItems.isNotEmpty) {
      _showSnackBar('Please enter a price for Lunch');
      return;
    }
    if (dinnerPrice == null && _dinnerItems.isNotEmpty) {
      _showSnackBar('Please enter a price for Dinner');
      return;
    }

    setState(() => _saving = true);
    try {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final dateStr =
          '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

      // Lunch
      final lunchConfig = _configs.firstWhere(
        (c) => c.mealType == MealType.lunch,
        orElse: () => MealConfig(
            date: dateStr, mealType: MealType.lunch, price: 0, menu: ''),
      );
      final updatedLunch = lunchConfig.copyWith(
        menu: _lunchItems.join(', '),
        price: lunchPrice ?? 0,
      );

      if (lunchConfig.id != null) {
        await _service.updateMealConfig(lunchConfig.id!, updatedLunch);
      } else {
        await _service.createMealConfig(updatedLunch);
      }

      // Dinner
      final dinnerConfig = _configs.firstWhere(
        (c) => c.mealType == MealType.dinner,
        orElse: () => MealConfig(
            date: dateStr, mealType: MealType.dinner, price: 0, menu: ''),
      );
      final updatedDinner = dinnerConfig.copyWith(
        menu: _dinnerItems.join(', '),
        price: dinnerPrice ?? 0,
      );

      if (dinnerConfig.id != null) {
        await _service.updateMealConfig(dinnerConfig.id!, updatedDinner);
      } else {
        await _service.createMealConfig(updatedDinner);
      }

      if (mounted) {
        _showSnackBar('Meal config saved successfully!', isSuccess: true);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
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
      appBar: AppBar(
        title: const Text('Set Meal'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.wb_sunny_outlined), text: 'Lunch'),
            Tab(icon: Icon(Icons.nightlight_outlined), text: 'Dinner'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMealTab(
                        theme: theme,
                        items: _lunchItems,
                        itemController: _lunchItemController,
                        priceController: _lunchPriceController,
                        color: Colors.blue,
                        label: 'Lunch',
                      ),
                      _buildMealTab(
                        theme: theme,
                        items: _dinnerItems,
                        itemController: _dinnerItemController,
                        priceController: _dinnerPriceController,
                        color: Colors.orange,
                        label: 'Dinner',
                      ),
                    ],
                  ),
                ),

                // ── Save button ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                          color:
                              theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                    ),
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save),
                        label: Text(_saving ? 'Saving...' : 'Save'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMealTab({
    required ThemeData theme,
    required List<String> items,
    required TextEditingController itemController,
    required TextEditingController priceController,
    required Color color,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Price field ──
          Text('$label Price (৳)',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: priceController,
            decoration: InputDecoration(
              hintText: 'e.g. 55',
              prefixIcon: const Icon(Icons.attach_money),
              suffixText: '৳',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            keyboardType: TextInputType.number,
          ),

          const SizedBox(height: 20),

          // ── Menu items header ──
          Text('Menu Items',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          // ── Add item form ──
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: itemController,
                  decoration: InputDecoration(
                    hintText: 'Add menu item…',
                    prefixIcon: const Icon(Icons.restaurant_menu),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addItem(items, itemController),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: () => _addItem(items, itemController),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(14),
                  minimumSize: const Size(52, 52),
                ),
                child: const Icon(Icons.add),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Item list ──
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restaurant_menu,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'No $label items yet. Add some above!',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    itemCount: items.length,
                    onReorder: (oldIdx, newIdx) {
                      setState(() {
                        if (newIdx > oldIdx) newIdx--;
                        final item = items.removeAt(oldIdx);
                        items.insert(newIdx, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      return Card(
                        key: ValueKey('${items[index]}_$index'),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: color.withValues(alpha: 0.2)),
                        ),
                        color: color.withValues(alpha: 0.05),
                        child: ListTile(
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                          title: Text(items[index]),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            color: theme.colorScheme.error,
                            onPressed: () => _removeItem(items, index),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
