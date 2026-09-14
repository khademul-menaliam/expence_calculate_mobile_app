import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../database/app_database.dart';
import '../../providers/currency_provider.dart';
import '../../providers/goal_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/currency_selector_dialog.dart';
import 'add_goal_dialog.dart';
import 'edit_goal_dialog.dart';

class GoalsHomeScreen extends ConsumerStatefulWidget {
  const GoalsHomeScreen({super.key});

  @override
  ConsumerState<GoalsHomeScreen> createState() => _GoalsHomeScreenState();
}

class _GoalsHomeScreenState extends ConsumerState<GoalsHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _quickGoalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quickGoalController.dispose();
    super.dispose();
  }

  Future<void> _addQuickGoal() async {
    final name = _quickGoalController.text.trim();
    if (name.isEmpty) {
      AddGoalDialog.show(context);
      return;
    }

    FocusScope.of(context).unfocus();
    _quickGoalController.clear();
    await ref.read(goalRepositoryProvider).addGoal(name: name);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added goal "$name"'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _confirmDeleteGoal(BuildContext context, Goal goal) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Delete Goal?'),
          content: Text('Are you sure you want to delete "${goal.name}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.expenseColor,
                minimumSize: const Size(80, 44),
              ),
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                await ref.read(goalRepositoryProvider).deleteGoal(goal.id);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeGoalsAsync = ref.watch(activeGoalsStreamProvider);
    final doneGoalsAsync = ref.watch(doneGoalsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: const Icon(Icons.currency_exchange, size: 16, color: AppTheme.primaryAccent),
              label: Text(
                '${ref.watch(currencyProvider).symbol} (${ref.watch(currencyProvider).code})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onPressed: () => showCurrencySelector(context, ref),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryAccent,
          labelColor: AppTheme.primaryAccent,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Active'),
                  const SizedBox(width: 6),
                  activeGoalsAsync.maybeWhen(
                    data: (goals) => _Badge(count: goals.length),
                    orElse: () => const SizedBox(),
                  ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Completed'),
                  const SizedBox(width: 6),
                  doneGoalsAsync.maybeWhen(
                    data: (goals) => _Badge(count: goals.length, isMuted: true),
                    orElse: () => const SizedBox(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Quick Add Input Box at top
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quickGoalController,
                    decoration: const InputDecoration(
                      hintText: 'Add a new goal (e.g. Save for Laptop)...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onSubmitted: (_) => _addQuickGoal(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(60, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: _addQuickGoal,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),

          // TabBar View (Active vs Completed)
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Active Goals Tab
                _GoalListTab(
                  goalsAsync: activeGoalsAsync,
                  emptyTitle: 'No Active Goals',
                  emptySubtitle: 'Type a goal name above to start tracking your wishlist.',
                  isDoneTab: false,
                  onToggleComplete: (goal) {
                    ref.read(goalRepositoryProvider).markGoalComplete(goal.id);
                  },
                  onEdit: (goal) => EditGoalDialog.show(context, goal),
                  onDelete: (goal) => _confirmDeleteGoal(context, goal),
                ),

                // Done Goals Tab
                _GoalListTab(
                  goalsAsync: doneGoalsAsync,
                  emptyTitle: 'No Completed Goals Yet',
                  emptySubtitle: 'Mark your active goals as finished when completed!',
                  isDoneTab: true,
                  onToggleComplete: (goal) {
                    ref.read(goalRepositoryProvider).markGoalUncomplete(goal.id);
                  },
                  onEdit: (goal) => EditGoalDialog.show(context, goal),
                  onDelete: (goal) => _confirmDeleteGoal(context, goal),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'goals_home_fab',
        onPressed: () => AddGoalDialog.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Goal'),
      ),
    );
  }
}

class _GoalListTab extends ConsumerWidget {
  final AsyncValue<List<Goal>> goalsAsync;
  final String emptyTitle;
  final String emptySubtitle;
  final bool isDoneTab;
  final Function(Goal) onToggleComplete;
  final Function(Goal) onEdit;
  final Function(Goal) onDelete;

  const _GoalListTab({
    required this.goalsAsync,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.isDoneTab,
    required this.onToggleComplete,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);

    return goalsAsync.when(
      data: (goals) {
        if (goals.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isDoneTab ? Icons.check_circle_outline : Icons.flag_outlined,
                    size: 48,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    emptyTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    emptySubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: goals.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final goal = goals[index];

            return Card(
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: Checkbox(
                    value: isDoneTab,
                    activeColor: AppTheme.primaryAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (_) => onToggleComplete(goal),
                  ),
                  title: Text(
                    goal.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      decoration: isDoneTab ? TextDecoration.lineThrough : null,
                      color: isDoneTab ? AppTheme.textSecondary : AppTheme.textPrimary,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (goal.note != null && goal.note!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          goal.note!,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (goal.targetCost != null)
                            Text(
                              'Target: ${currency.format(goal.targetCost!)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryAccent,
                              ),
                            ),
                          if (isDoneTab && goal.completedAt != null)
                            Text(
                              'Done: ${DateFormat('MMM d, yyyy').format(goal.completedAt!)}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            )
                          else if (!isDoneTab && goal.targetDate != null)
                            Text(
                              'Target: ${DateFormat('MMM d, yyyy').format(goal.targetDate!)}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => onEdit(goal),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.expenseColor),
                        onPressed: () => onDelete(goal),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  final bool isMuted;

  const _Badge({required this.count, this.isMuted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isMuted ? AppTheme.border : AppTheme.accentLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isMuted ? AppTheme.textSecondary : AppTheme.primaryAccent,
        ),
      ),
    );
  }
}
