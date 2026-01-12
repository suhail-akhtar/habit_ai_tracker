import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../models/habit_log.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../utils/helpers.dart';
import '../utils/theme.dart';

class IncomingCallScreen extends StatefulWidget {
  final int habitId;

  const IncomingCallScreen({super.key, required this.habitId});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final DatabaseService _db = DatabaseService();
  Habit? _habit;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadHabit();
  }

  Future<void> _loadHabit() async {
    final habit = await _db.getHabit(widget.habitId);
    if (!mounted) return;
    setState(() {
      _habit = habit;
    });
  }

  Future<void> _handleAction({required bool accept}) async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
    });

    try {
      final log = HabitLog(
        habitId: widget.habitId,
        completedAt: DateTime.now(),
        note: accept
            ? 'Completed via ringing notification'
            : 'Skipped via ringing notification',
        inputMethod: 'notification_fullscreen',
        status: accept ? 'completed' : 'skipped',
      );

      await _db.logHabit(log);

      // Best-effort: stop future ringing instances for this habit group.
      await NotificationService().cancelNotification(widget.habitId);
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
    final habitName = _habit?.name ?? 'Habit';
    final habitIcon = Helpers.getHabitIcon(_habit?.iconName ?? 'star');
    final habitColor = _habit != null
        ? Helpers.getHabitColor(_habit!.colorCode)
        : Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                'Incoming habit call',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              CircleAvatar(
                radius: 56,
                backgroundColor: habitColor.withAlpha(51),
                child: Icon(habitIcon, size: 56, color: habitColor),
              ),
              const SizedBox(height: 16),
              Text(
                habitName,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Swipe down or choose an option',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CallActionButton(
                    label: 'Reject',
                    icon: Icons.call_end,
                    backgroundColor: AppTheme.errorColor,
                    onPressed: _isBusy
                        ? null
                        : () => _handleAction(accept: false),
                  ),
                  _CallActionButton(
                    label: 'Accept',
                    icon: Icons.call,
                    backgroundColor: AppTheme.successColor,
                    onPressed: _isBusy
                        ? null
                        : () => _handleAction(accept: true),
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

class _CallActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback? onPressed;

  const _CallActionButton({
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
            child: Icon(icon, size: 34),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
