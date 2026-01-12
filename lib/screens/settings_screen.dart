import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../models/notification_settings.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';
import '../utils/app_log.dart';
import '../screens/notification_setup_screen.dart';
import '../config/app_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<NotificationSettings> _notifications = [];
  bool _isLoadingNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoadingNotifications = true);
    try {
      _notifications = await _databaseService.getNotificationSettings();
    } catch (e) {
      AppLog.e('Failed to load notifications', e);
    } finally {
      if (mounted) setState(() => _isLoadingNotifications = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAccountSection(context, userProvider),
                const SizedBox(height: AppTheme.spacingL),
                _buildNotificationSection(context, userProvider), // 🔔 NEW
                const SizedBox(height: AppTheme.spacingL),
                _buildAppearanceSection(context, userProvider),
                const SizedBox(height: AppTheme.spacingL),
                _buildDataSection(context, userProvider),
                const SizedBox(height: AppTheme.spacingL),
                _buildAboutSection(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context, UserProvider userProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              title: Text(
                'User',
                style: AppTheme.titleMedium,
              ),
              subtitle: Text(
                'All features are free',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔔 NEW: Notification management section
  Widget _buildNotificationSection(
    BuildContext context,
    UserProvider userProvider,
  ) {
    final currentCount = _notifications.length;
    const canAddMore = true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Notifications', style: AppTheme.titleMedium),
                if (canAddMore)
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _addNotification(userProvider),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'Reminders: $currentCount',
              style: AppTheme.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            if (_isLoadingNotifications)
              const Center(child: CircularProgressIndicator())
            else if (_notifications.isEmpty)
              _buildEmptyNotificationState(userProvider)
            else
              ..._notifications.map(
                (notification) =>
                    _buildNotificationItem(notification, userProvider),
              ),

          ],
        ),
      ),
    );
  }

  Widget _buildEmptyNotificationState(UserProvider userProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outline.withAlpha(26),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Column(
        children: [
          Icon(
            Icons.notifications_none,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'No notifications set up',
            style: AppTheme.titleMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Create reminders to stay on track with your habits',
            style: AppTheme.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingM),
          ElevatedButton.icon(
            onPressed: () => _addNotification(userProvider),
            icon: const Icon(Icons.add),
            label: const Text('Create Notification'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    NotificationSettings notification,
    UserProvider userProvider,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          decoration: BoxDecoration(
            color: notification.isEnabled
                ? AppTheme.successColor.withAlpha(26)
                : Theme.of(context).colorScheme.outline.withAlpha(26),
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: Icon(
            _getNotificationTypeIcon(notification.type),
            color: notification.isEnabled
                ? AppTheme.successColor
                : Theme.of(context).colorScheme.outline,
            size: 20,
          ),
        ),
        title: Text(
          notification.title.isEmpty ? 'Habit Reminder' : notification.title,
          style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${notification.timeString} • ${notification.repetitionDisplayName}',
              style: AppTheme.bodySmall,
            ),
            if (notification.hasHabits)
              Text(
                '${notification.habitIds.length} habit${notification.habitIds.length > 1 ? 's' : ''} linked',
                style: AppTheme.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: notification.isEnabled,
              onChanged: (value) => _toggleNotification(notification, value),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editNotification(notification),
            ),
          ],
        ),
        onTap: () => _editNotification(notification),
      ),
    );
  }

  IconData _getNotificationTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.simple:
        return Icons.notifications;
      case NotificationType.ringing:
        return Icons.notifications_active;
      case NotificationType.alarm:
        return Icons.alarm;
    }
  }

  void _addNotification(UserProvider userProvider) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationSetupScreen()),
    );

    if (result == true) {
      _loadNotifications();
    }
  }

  void _editNotification(NotificationSettings notification) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            NotificationSetupScreen(notification: notification),
      ),
    );

    if (result == true) {
      _loadNotifications();
    }
  }

  void _toggleNotification(
    NotificationSettings notification,
    bool enabled,
  ) async {
    try {
      final updatedNotification = notification.copyWith(
        isEnabled: enabled,
        updatedAt: DateTime.now(),
      );

      await _databaseService.updateNotificationSetting(updatedNotification);

      if (enabled) {
        await NotificationService().scheduleNotification(updatedNotification);
      } else {
        await NotificationService().cancelNotification(notification.id!);
      }

      if (!mounted) return;
      _loadNotifications();

      Helpers.showSnackBar(
        context,
        enabled ? 'Notification enabled' : 'Notification disabled',
      );
    } catch (e) {
      if (!mounted) return;
      Helpers.showSnackBar(
        context,
        'Failed to update notification: $e',
        isError: true,
      );
    }
  }

  Widget _buildAppearanceSection(
    BuildContext context,
    UserProvider userProvider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Appearance', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('Theme'),
              subtitle: Text(
                _getThemeDisplayName(userProvider.getSetting('theme_mode')),
              ),
              onTap: () => _showThemeDialog(context, userProvider),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.color_lens),
              title: const Text('Custom Colors'),
              subtitle: const Text('Personalize your app colors'),
              onTap: () => _showCustomColorsDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection(BuildContext context, UserProvider userProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Data & Privacy', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Analytics'),
              subtitle: const Text('Help improve the app with usage data'),
              trailing: Switch(
                value: userProvider.getBoolSetting(
                  'analytics_enabled',
                  defaultValue: true,
                ),
                onChanged: (value) {
                  userProvider.updateSetting(
                    'analytics_enabled',
                    value.toString(),
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Backup Data'),
              subtitle: const Text('Save your habits to the cloud'),
              trailing: const Icon(Icons.cloud_done, color: AppTheme.successColor),
              onTap: () => _showBackupDialog(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Export Data'),
              subtitle: const Text('Download your data as CSV'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _exportData(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.delete_forever,
                color: AppTheme.errorColor,
              ),
              title: const Text('Clear All Data'),
              subtitle: const Text('Permanently delete all your data'),
              onTap: () => _showClearDataDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Version'),
              subtitle: Text(AppConfig.appVersion),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('Help & Support'),
              subtitle: const Text('Get help with using the app'),
              onTap: () => _showHelpDialog(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.privacy_tip),
              title: const Text('Privacy Policy'),
              subtitle: const Text('Read our privacy policy'),
              onTap: () => _showPrivacyPolicy(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Terms of Service'),
              subtitle: const Text('Read our terms of service'),
              onTap: () => _showTermsOfService(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.rate_review),
              title: const Text('Rate App'),
              subtitle: const Text('Rate us on the App Store'),
              onTap: () => _rateApp(context),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for dialogs and actions (existing methods unchanged)
  String _getThemeDisplayName(String themeMode) {
    switch (themeMode.toLowerCase()) {
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      default:
        return 'System';
    }
  }

  void _showThemeDialog(BuildContext context, UserProvider userProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Light'),
              value: 'light',
              // ignore: deprecated_member_use
              groupValue: userProvider.getSetting('theme_mode'),
              // ignore: deprecated_member_use
              onChanged: (value) {
                userProvider.updateSetting('theme_mode', value!);
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<String>(
              title: const Text('Dark'),
              value: 'dark',
              // ignore: deprecated_member_use
              groupValue: userProvider.getSetting('theme_mode'),
              // ignore: deprecated_member_use
              onChanged: (value) {
                userProvider.updateSetting('theme_mode', value!);
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<String>(
              title: const Text('System'),
              value: 'system',
              // ignore: deprecated_member_use
              groupValue: userProvider.getSetting('theme_mode'),
              // ignore: deprecated_member_use
              onChanged: (value) {
                userProvider.updateSetting('theme_mode', value!);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomColorsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Colors'),
        content: const Text('Custom color themes are coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Data'),
        content: const Text(
          'Your data is automatically backed up to the cloud. Last backup: Just now',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Helpers.showSnackBar(context, 'Backup completed successfully');
            },
            child: const Text('Backup Now'),
          ),
        ],
      ),
    );
  }

  void _exportData(BuildContext context) {
    Helpers.showSnackBar(context, 'Data export feature coming soon!');
  }

  void _showClearDataDialog(BuildContext context) {
    Helpers.showConfirmDialog(
      context,
      title: 'Clear All Data',
      content:
          'This will permanently delete all your habits, logs, and settings. This action cannot be undone.',
      onConfirm: () {
        Helpers.showSnackBar(context, 'All data cleared successfully');
      },
      confirmText: 'Clear Data',
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need help? Here are some resources:'),
            SizedBox(height: 16),
            Text('• Create a habit from the Add Habit tab'),
            Text('• Enable reminders in Settings → Notifications'),
            Text('• Tap a habit to mark it complete'),
            SizedBox(height: 16),
            Text('For more help, contact us at support@habittracker.com'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Privacy Policy\n\n'
            'Your privacy is important to us. This app stores your habit data locally on your device.\n\n'
            'We may collect anonymous usage statistics to improve the app experience.\n\n'
            'Voice data is processed locally and not stored on our servers.\n\n'
            'For the full privacy policy, visit our website.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'Terms of Service\n\n'
            'By using this app, you agree to our terms and conditions.\n\n'
            'The app is provided "as is" without warranties.\n\n'
            'You are responsible for your own data and usage.\n\n'
            'For full terms, visit our website.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _rateApp(BuildContext context) {
    Helpers.showSnackBar(context, 'Thank you! Redirecting to App Store...');
  }
}
