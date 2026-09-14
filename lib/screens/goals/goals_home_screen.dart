import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../database/app_database.dart';
import '../../providers/currency_provider.dart';
import '../../providers/goal_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_toast.dart';
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
                  onToggleComplete: (goal) async {
                    await ref.read(goalRepositoryProvider).markGoalComplete(goal.id);
                    if (!context.mounted) return;
                    AppToast.showUndo(
                      context: context,
                      message: '🎉 Goal Completed: "${goal.name}"!',
                      onUndo: () async {
                        await ref.read(goalRepositoryProvider).markGoalUncomplete(goal.id);
                      },
                    );
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
                  onToggleComplete: (goal) async {
                    await ref.read(goalRepositoryProvider).markGoalUncomplete(goal.id);
                    if (!context.mounted) return;
                    AppToast.showUndo(
                      context: context,
                      message: 'Restored "${goal.name}" to Active',
                      onUndo: () async {
                        await ref.read(goalRepositoryProvider).markGoalComplete(goal.id);
                      },
                    );
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

            return _AnimatedGoalCard(
              key: ValueKey('goal_${goal.id}_$isDoneTab'),
              goal: goal,
              isDoneTab: isDoneTab,
              currencySymbol: currency.symbol,
              onToggleComplete: onToggleComplete,
              onEdit: onEdit,
              onDelete: onDelete,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}

class _AnimatedGoalCard extends StatefulWidget {
  final Goal goal;
  final bool isDoneTab;
  final String currencySymbol;
  final Function(Goal) onToggleComplete;
  final Function(Goal) onEdit;
  final Function(Goal) onDelete;

  const _AnimatedGoalCard({
    super.key,
    required this.goal,
    required this.isDoneTab,
    required this.currencySymbol,
    required this.onToggleComplete,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_AnimatedGoalCard> createState() => _AnimatedGoalCardState();
}

class _AnimatedGoalCardState extends State<_AnimatedGoalCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isAnimatingComplete = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    // Active tab -> fly up-right towards Completed tab.
    // Completed tab -> fly up-left towards Active tab.
    final targetOffset = widget.isDoneTab
        ? const Offset(-0.25, -1.0)
        : const Offset(0.25, -1.0);

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: targetOffset,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInCubic));

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInQuad),
    );
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
  }

  @override
  void didUpdateWidget(covariant _AnimatedGoalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.goal.id != oldWidget.goal.id || widget.isDoneTab != oldWidget.isDoneTab) {
      _controller.reset();
      _isAnimatingComplete = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleToggle() async {
    if (_isAnimatingComplete) return;

    setState(() => _isAnimatingComplete = true);
    await _controller.forward();

    widget.onToggleComplete(widget.goal);
  }

  @override
  Widget build(BuildContext context) {
    // On Active tab: turns done when user taps complete
    // On Completed tab: turns active (un-checked) when user taps un-complete
    final showCompletedStyle = widget.isDoneTab ? !_isAnimatingComplete : _isAnimatingComplete;

    return SlideTransition(
      position: _slideAnimation,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: child,
            ),
          );
        },
        child: Card(
          elevation: showCompletedStyle ? 0 : 2,
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: InkWell(
                onTap: _handleToggle,
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: showCompletedStyle ? AppTheme.incomeColor : Colors.transparent,
                    border: Border.all(
                      color: showCompletedStyle ? AppTheme.incomeColor : AppTheme.textSecondary,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.check,
                    size: 16,
                    color: showCompletedStyle ? Colors.white : Colors.transparent,
                  ),
                ),
              ),
              title: Text(
                widget.goal.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  decoration: showCompletedStyle ? TextDecoration.lineThrough : null,
                  color: showCompletedStyle ? AppTheme.textSecondary : AppTheme.textPrimary,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.goal.note != null && widget.goal.note!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.goal.note!,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (widget.goal.targetCost != null)
                        Text(
                          'Target: ${widget.currencySymbol}${widget.goal.targetCost!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryAccent,
                          ),
                        ),
                      if (widget.isDoneTab && widget.goal.completedAt != null)
                        Text(
                          'Done: ${DateFormat('MMM d, yyyy').format(widget.goal.completedAt!)}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        )
                      else if (!widget.isDoneTab && widget.goal.targetDate != null)
                        Text(
                          'Target: ${DateFormat('MMM d, yyyy').format(widget.goal.targetDate!)}',
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
                    onPressed: () => widget.onEdit(widget.goal),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.expenseColor),
                    onPressed: () => widget.onDelete(widget.goal),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
