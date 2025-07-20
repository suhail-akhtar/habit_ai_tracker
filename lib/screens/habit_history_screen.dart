import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../providers/habit_provider.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';

class HabitHistoryScreen extends StatefulWidget {
  final Habit habit;

  const HabitHistoryScreen({super.key, required this.habit});

  @override
  State<HabitHistoryScreen> createState() => _HabitHistoryScreenState();
}

class _HabitHistoryScreenState extends State<HabitHistoryScreen> {
  List<HabitLog> _logs = [];
  bool _isLoading = true;
  int _currentStreak = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final habitProvider = context.read<HabitProvider>();
      final logs = await habitProvider.getHabitHistory(
        widget.habit.id!,
        limit: 50,
      );
      final streak = await habitProvider.getHabitStreak(widget.habit.id!);

      setState(() {
        _logs = logs;
        _currentStreak = streak;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Failed to load history: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.habit.name} History'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHistory),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatsCard(),
                Expanded(
                  child: _logs.isEmpty
                      ? _buildEmptyState()
                      : _buildHistoryList(),
                ),
              ],
            ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      margin: const EdgeInsets.all(AppTheme.spacingM),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: widget.habit.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: Icon(
                Helpers.getHabitIcon(widget.habit.iconName),
                color: widget.habit.color,
                size: 24,
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.habit.name, style: AppTheme.titleMedium),
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    'Current Streak: $_currentStreak days',
                    style: AppTheme.bodySmall.copyWith(
                      color: Helpers.getStreakColor(_currentStreak),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_logs.length}',
                  style: AppTheme.headlineSmall.copyWith(
                    color: widget.habit.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Total Logs',
                  style: AppTheme.bodySmall.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'No history yet',
            style: AppTheme.titleMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Complete this habit to see your progress here',
            style: AppTheme.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        return _buildLogItem(log, index);
      },
    );
  }

  Widget _buildLogItem(HabitLog log, int index) {
    final isCompleted = log.inputMethod != 'skip';

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(AppTheme.spacingXS),
          decoration: BoxDecoration(
            color: isCompleted
                ? AppTheme.successColor.withOpacity(0.1)
                : AppTheme.warningColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: Icon(
            isCompleted ? Icons.check_circle : Icons.skip_next,
            color: isCompleted ? AppTheme.successColor : AppTheme.warningColor,
            size: 20,
          ),
        ),
        title: Text(
          isCompleted ? 'Completed' : 'Skipped',
          style: AppTheme.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isCompleted ? AppTheme.successColor : AppTheme.warningColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Helpers.formatDateTime(log.completedAt),
              style: AppTheme.bodySmall,
            ),
            if (log.note != null && log.note!.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                log.note!,
                style: AppTheme.bodySmall.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getInputMethodIcon(log.inputMethod),
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              _getInputMethodLabel(log.inputMethod),
              style: AppTheme.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getInputMethodIcon(String inputMethod) {
    switch (inputMethod.toLowerCase()) {
      case 'voice':
        return Icons.mic;
      case 'manual':
        return Icons.touch_app;
      case 'skip':
        return Icons.skip_next;
      default:
        return Icons.touch_app;
    }
  }

  String _getInputMethodLabel(String inputMethod) {
    switch (inputMethod.toLowerCase()) {
      case 'voice':
        return 'Voice';
      case 'manual':
        return 'Manual';
      case 'skip':
        return 'Skip';
      default:
        return 'Manual';
    }
  }
}
