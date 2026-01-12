import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../models/habit_log.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../utils/helpers.dart';
import '../utils/theme.dart';

class AlarmScreen extends StatefulWidget {
  final int notificationSettingId;
  final List<int> habitIds;

  const AlarmScreen({
    super.key,
    required this.notificationSettingId,
    required this.habitIds,
  });

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  static const Duration _defaultSnoozeDuration = Duration(minutes: 10);

  final DatabaseService _db = DatabaseService();
  String? _notificationTitle;
  List<Habit> _habits = <Habit>[];
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final notification = await _db.getNotificationSetting(
      widget.notificationSettingId,
    );

    final habits = <Habit>[];
    for (final habitId in widget.habitIds) {
      final habit = await _db.getHabit(habitId);
      if (habit != null) habits.add(habit);
    }

    if (!mounted) return;
    setState(() {
      _notificationTitle = notification?.title;
      _habits = habits;
    });
  }

  Future<void> _logAndClose({
    required String status,
    required String note,
  }) async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
    });

    try {
      for (final habitId in widget.habitIds) {
        final log = HabitLog(
          habitId: habitId,
          completedAt: DateTime.now(),
          note: note,
          inputMethod: 'notification_fullscreen',
          status: status,
        );
        await _db.logHabit(log);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _snooze() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
    });

    try {
      final title = (_notificationTitle != null && _notificationTitle!.isNotEmpty)
        ? _notificationTitle!
        : 'Alarm';
      final body = 'Snoozed for ${_defaultSnoozeDuration.inMinutes} minutes';
      final payload =
        'custom_notification:alarm:${widget.notificationSettingId}:${widget.habitIds.join(",")}';

      await NotificationService().scheduleSnoozedAlarm(
        title: title,
        body: body,
        payload: payload,
        delay: _defaultSnoozeDuration,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final title = (_notificationTitle != null && _notificationTitle!.isNotEmpty)
      ? _notificationTitle!
      : 'Alarm';

    final primaryHabit = _habits.isNotEmpty ? _habits.first : null;
    final habitIcon = Helpers.getHabitIcon(primaryHabit?.iconName ?? 'star');
    final habitColor = primaryHabit != null
      ? Helpers.getHabitColor(primaryHabit.colorCode)
      : Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'It\'s time for your habit',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
                ),
              ),
              const Spacer(),
              CircleAvatar(
                radius: 64,
                backgroundColor: habitColor.withAlpha(51),
                child: Icon(habitIcon, size: 64, color: habitColor),
              ),
              const SizedBox(height: 18),
              if (_habits.isNotEmpty)
                Text(
                  _habits.length == 1
                      ? _habits.first.name
                      : '${_habits.length} habits',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              if (_habits.length > 1) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _habits.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final habit = _habits[index];
                      return Text(
                        habit.name,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(204),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Choose an option',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AlarmActionButton(
                    label: 'Dismiss',
                    icon: Icons.close,
                    backgroundColor: AppTheme.errorColor,
                    onPressed: _isBusy
                        ? null
                        : () => _logAndClose(
                            status: 'skipped',
                            note: 'Skipped via alarm notification',
                          ),
                  ),
                  _AlarmActionButton(
                    label: 'Snooze',
                    icon: Icons.snooze,
                    backgroundColor: AppTheme.warningColor,
                    onPressed: _isBusy ? null : _snooze,
                  ),
                  _AlarmActionButton(
                    label: 'Accept',
                    icon: Icons.check,
                    backgroundColor: AppTheme.successColor,
                    onPressed: _isBusy
                        ? null
                        : () => _logAndClose(
                            status: 'completed',
                            note: 'Completed via alarm notification',
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlarmActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback? onPressed;

  const _AlarmActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 84,
          height: 84,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            onPressed: onPressed,
            child: Icon(icon, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
