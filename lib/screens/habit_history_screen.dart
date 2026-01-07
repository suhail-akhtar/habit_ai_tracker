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
  Map<DateTime, List<HabitLog>> _groupedLogs = {}; // 📅 NEW: Grouped by date
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
      final logs = await habitProvider.getHabitHistory(widget.habit.id!);
      final streak = await habitProvider.getHabitStreak(widget.habit.id!);

      // 📅 NEW: Group logs by date (ignoring time)
      final Map<DateTime, List<HabitLog>> grouped = {};
      for (var log in logs) {
        final date = DateTime(
          log.completedAt.year,
          log.completedAt.month,
          log.completedAt.day,
        );
        if (!grouped.containsKey(date)) {
          grouped[date] = [];
        }
        grouped[date]!.add(log);
      }

      setState(() {
        _logs = logs;
        _groupedLogs = grouped;
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
      appBar: AppBar(title: Text('${widget.habit.name} History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: Column(
                children: [
                  _buildHabitHeader(),
                  Expanded(
                    child: _logs.isEmpty
                        ? _buildEmptyState()
                        : _buildHistoryList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHabitHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: widget.habit.color.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: widget.habit.color.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: widget.habit.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Icon(
              Helpers.getHabitIcon(widget.habit.iconName),
              color: widget.habit.color,
              size: 32,
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.habit.name, style: AppTheme.titleLarge),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  widget.habit.category,
                  style: AppTheme.bodyMedium.copyWith(
                    color: widget.habit.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Icon(
                Icons.local_fire_department,
                color: Helpers.getStreakColor(_currentStreak),
                size: 24,
              ),
              Text(
                '$_currentStreak',
                style: AppTheme.titleMedium.copyWith(
                  color: Helpers.getStreakColor(_currentStreak),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'day streak',
                style: AppTheme.bodySmall.copyWith(
                  color: Helpers.getStreakColor(_currentStreak),
                ),
              ),
            ],
          ),
        ],
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
            'Start completing this habit to see your progress here',
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
    final sortedDates = _groupedLogs.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Newest first

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final dayLogs = _groupedLogs[date]!;
        return _buildDayGroupCard(date, dayLogs);
      },
    );
  }

  Widget _buildDayGroupCard(DateTime date, List<HabitLog> dayLogs) {
    // Sort logs by time
    dayLogs.sort((a, b) => b.completedAt.compareTo(a.completedAt));

    final completedCount = dayLogs.where((l) => l.status == 'completed').length;
    final isSkippedDay = dayLogs.any((l) => l.status == 'skipped');
    final target = widget.habit.targetFrequency;
    
    final isTargetMet = completedCount >= target;
    final progress = target > 0 ? (completedCount / target).clamp(0.0, 1.0) : 1.0;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        side: BorderSide(
          color: isSkippedDay 
              ? Colors.grey.withOpacity(0.3)
              : (isTargetMet 
                  ? AppTheme.successColor.withOpacity(0.3) 
                  : Colors.transparent),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM, vertical: 8),
          leading: _buildDayStatusIcon(isTargetMet, isSkippedDay, progress),
          title: Text(
            Helpers.formatDate(date),
            style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSkippedDay)
                const Text('Skipped (Streak Frozen)', style: TextStyle(color: Colors.grey))
              else if (target > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.grey.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  widget.habit.color
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('$completedCount/$target', style: AppTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                )
              else
                Text(
                  Helpers.formatTime(dayLogs.first.completedAt),
                  style: AppTheme.bodySmall.copyWith(color: Colors.grey),
                ),
            ],
          ),
          children: dayLogs.map((log) => _buildLogDetailItem(log)).toList(),
        ),
      ),
    );
  }

  Widget _buildDayStatusIcon(bool isMet, bool isSkipped, double progress) {
    if (isSkipped) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.pause, color: Colors.grey, size: 20),
      );
    }
    
    if (widget.habit.targetFrequency > 1) {
       return Stack(
         alignment: Alignment.center,
         children: [
           CircularProgressIndicator(
             value: progress,
             backgroundColor: Colors.grey.withOpacity(0.1),
             valueColor: AlwaysStoppedAnimation<Color>(widget.habit.color),
             strokeWidth: 3,
           ),
           if (isMet)
             Icon(Icons.check, size: 16, color: widget.habit.color)
           else
             Text(
               '${(progress * 100).toInt()}%', 
               style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)
             ),
         ],
       );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, color: AppTheme.successColor, size: 20),
    );
  }

  Widget _buildLogDetailItem(HabitLog log) {
    final isVoice = log.inputMethod == 'voice';
    final isSkip = log.status == 'skipped';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingL,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        border: Border(
           top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5)),
        ),
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1),
      ),
      child: Row(
        children: [
           Icon(
             isSkip ? Icons.skip_next : Icons.check_circle_outline, 
             size: 16, 
             color: isSkip ? Colors.grey : widget.habit.color.withOpacity(0.7)
           ),
           const SizedBox(width: 12),
           Text(
             Helpers.formatTime(log.completedAt),
             style: AppTheme.bodyMedium.copyWith(fontFamily: 'Monospace'),
           ),
           if (isVoice) ...[
              const SizedBox(width: 8),
              const Icon(Icons.mic, size: 14, color: Colors.grey),
           ],
           if (log.note != null && log.note!.isNotEmpty) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  log.note!,
                  style: AppTheme.bodySmall.copyWith(fontStyle: FontStyle.italic),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
           ],
        ],
      ),
    );
  }
}
