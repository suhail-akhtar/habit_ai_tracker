import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/voice_reminder.dart';
import '../services/voice_notification_service.dart';

/// Smart Notification System Widget
/// Provides an easy-to-use interface for creating intelligent voice reminders
class SmartNotificationSystem extends StatefulWidget {
  final List<Habit> userHabits;

  const SmartNotificationSystem({super.key, required this.userHabits});

  @override
  State<SmartNotificationSystem> createState() =>
      _SmartNotificationSystemState();
}

class _SmartNotificationSystemState extends State<SmartNotificationSystem> {
  final VoiceNotificationService _voiceService = VoiceNotificationService();
  final TextEditingController _inputController = TextEditingController();
  List<VoiceReminder> _activeReminders = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadActiveReminders();
  }

  Future<void> _loadActiveReminders() async {
    try {
      final reminders = await _voiceService.getActiveVoiceReminders();
      setState(() {
        _activeReminders = reminders;
      });
    } catch (e) {
      print('Error loading reminders: $e');
    }
  }

  Future<void> _createSmartReminder() async {
    if (_inputController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final reminder = await _voiceService.createSmartVoiceReminder(
        userInput: _inputController.text.trim(),
        userHabits: widget.userHabits,
      );

      if (reminder != null) {
        _inputController.clear();
        await _loadActiveReminders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎯 Smart reminder created: "${reminder.message}"'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to create reminder. Please try again.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      print('Error creating reminder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createQuickReminder(QuickReminderType type) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final reminder = await _voiceService.createQuickReminder(
        type: type,
        userHabits: widget.userHabits,
      );

      if (reminder != null) {
        await _loadActiveReminders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚡ Quick reminder set: "${reminder.message}"'),
              backgroundColor: Colors.blue,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      print('Error creating quick reminder: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎤 Smart Voice Notifications'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(16.0),
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.secondaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.psychology, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'AI-Powered Voice Reminders',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Create intelligent, personalized reminders that adapt to your patterns and preferences. Just tell me what you need!',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),

          // Input Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _inputController,
                  decoration: InputDecoration(
                    hintText:
                        'Tell me when you want to be reminded... (e.g., "Remind me to drink water every 2 hours")',
                    prefixIcon: const Icon(Icons.mic),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createSmartReminder,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: const Text('Create Smart Reminder'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Quick Actions Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⚡ Quick Reminders',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _QuickActionChip(
                      label: '🏆 Habit Check',
                      onTap: () =>
                          _createQuickReminder(QuickReminderType.habitCheck),
                      isLoading: _isLoading,
                    ),
                    _QuickActionChip(
                      label: '💧 Hydration',
                      onTap: () => _createQuickReminder(
                        QuickReminderType.hydrationReminder,
                      ),
                      isLoading: _isLoading,
                    ),
                    _QuickActionChip(
                      label: '🚶‍♀️ Movement',
                      onTap: () =>
                          _createQuickReminder(QuickReminderType.movementBreak),
                      isLoading: _isLoading,
                    ),
                    _QuickActionChip(
                      label: '🧘‍♀️ Mindfulness',
                      onTap: () => _createQuickReminder(
                        QuickReminderType.mindfulnessCheck,
                      ),
                      isLoading: _isLoading,
                    ),
                    _QuickActionChip(
                      label: '💪 Motivation',
                      onTap: () => _createQuickReminder(
                        QuickReminderType.motivationalBoost,
                      ),
                      isLoading: _isLoading,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Active Reminders Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📋 Active Voice Reminders',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _activeReminders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_off_outlined,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No active reminders yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Create your first smart reminder above!',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _activeReminders.length,
                            itemBuilder: (context, index) {
                              final reminder = _activeReminders[index];
                              return _ReminderCard(
                                reminder: reminder,
                                onDelete: () async {
                                  final success = await _voiceService
                                      .deleteVoiceReminder(reminder.id!);
                                  if (success) {
                                    await _loadActiveReminders();
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('✅ Reminder deleted'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }
}

class _QuickActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  const _QuickActionChip({
    required this.label,
    required this.onTap,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: isLoading ? null : onTap,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      side: BorderSide(
        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final VoiceReminder reminder;
  final VoidCallback onDelete;

  const _ReminderCard({required this.reminder, required this.onDelete});

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = DateTime(date.year, date.month, date.day);

    if (reminderDate == today) {
      return 'Today';
    } else if (reminderDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else {
      return '${date.day}/${date.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    reminder.message,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  color: Theme.of(context).colorScheme.error,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_formatDate(reminder.reminderTime)} at ${_formatTime(reminder.reminderTime)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 14,
                  ),
                ),
                if (reminder.habitIds.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.track_changes,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${reminder.habitIds.length} habit${reminder.habitIds.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
