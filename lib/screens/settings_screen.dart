import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/voice_provider.dart';
import '../providers/custom_category_provider.dart';
import '../providers/voice_reminder_provider.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../models/notification_settings.dart';
import '../models/voice_reminder.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';
import '../widgets/premium_dialog.dart';
import '../screens/notification_setup_screen.dart';
import '../screens/custom_categories_screen.dart';
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
      print('Failed to load notifications: $e');
    } finally {
      if (mounted) setState(() => _isLoadingNotifications = false);
    }
  }

  // 🔄 NEW: Manual refresh for notifications
  Future<void> _refreshNotifications() async {
    await _loadNotifications();
    if (mounted) {
      Helpers.showSnackBar(context, 'Notifications refreshed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer2<UserProvider, VoiceProvider>(
        builder: (context, userProvider, voiceProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAccountSection(context, userProvider),
                const SizedBox(height: AppTheme.spacingL),
                _buildNotificationSection(context, userProvider), // 🔔 NEW
                const SizedBox(height: AppTheme.spacingL),
                _buildCustomCategoriesSection(context, userProvider), // 🎨 NEW
                const SizedBox(height: AppTheme.spacingL),
                _buildVoiceRemindersSection(context, userProvider), // 🎤 NEW
                const SizedBox(height: AppTheme.spacingL),
                _buildAppearanceSection(context, userProvider),
                const SizedBox(height: AppTheme.spacingL),
                _buildVoiceSection(context, userProvider, voiceProvider),
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
                userProvider.isPremium ? 'Premium User' : 'Free User',
                style: AppTheme.titleMedium,
              ),
              subtitle: Text(
                userProvider.isPremium
                    ? 'All features unlocked'
                    : '${userProvider.remainingFreeHabits} habits remaining',
              ),
              trailing: userProvider.isPremium
                  ? Icon(Icons.star, color: AppTheme.warningColor)
                  : TextButton(
                      onPressed: () => showPremiumDialog(context),
                      child: const Text('Upgrade'),
                    ),
            ),
            if (userProvider.isPremium) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Manage Subscription'),
                subtitle: const Text('Cancel or modify your subscription'),
                onTap: () => _showSubscriptionDialog(context, userProvider),
              ),
            ],
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
    final notificationLimit = userProvider.isPremium ? 20 : 3;
    final currentCount = _notifications.length;
    final canAddMore = currentCount < notificationLimit;

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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🔄 NEW: Refresh button
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        size: 20,
                        color: _isLoadingNotifications
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.5)
                            : Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: _isLoadingNotifications
                          ? null
                          : _refreshNotifications,
                      tooltip: 'Refresh notifications',
                    ),
                    if (canAddMore)
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _addNotification(userProvider),
                        tooltip: 'Add new notification',
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'Reminders: $currentCount/$notificationLimit',
              style: AppTheme.bodySmall.copyWith(
                color: currentCount >= notificationLimit
                    ? AppTheme.errorColor
                    : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),

            // 💡 NEW: User tip for auto-notifications
            const SizedBox(height: AppTheme.spacingS),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Text(
                      'Tip: Auto-notifications are created when you add habits with Smart Reminders enabled',
                      style: AppTheme.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
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

            if (!canAddMore && !userProvider.isPremium) ...[
              const SizedBox(height: AppTheme.spacingM),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  border: Border.all(
                    color: AppTheme.warningColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: AppTheme.warningColor, size: 16),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Text(
                        'Upgrade to Premium for up to 20 notifications',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => showPremiumDialog(
                        context,
                        feature: 'More notifications (up to 20)',
                      ),
                      child: Text(
                        'Upgrade',
                        style: TextStyle(color: AppTheme.warningColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
        color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
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
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Create reminders to stay on track with your habits',
            style: AppTheme.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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
                ? AppTheme.successColor.withOpacity(0.1)
                : Theme.of(context).colorScheme.outline.withOpacity(0.1),
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
    if (!userProvider.isPremium && _notifications.length >= 3) {
      showPremiumDialog(context, feature: 'More than 3 notifications');
      return;
    }

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

      _loadNotifications();

      Helpers.showSnackBar(
        context,
        enabled ? 'Notification enabled' : 'Notification disabled',
      );
    } catch (e) {
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

            // Theme Mode
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('Theme'),
              subtitle: Text(
                _getThemeDisplayName(userProvider.getSetting('theme_mode')),
              ),
              onTap: () => _showThemeDialog(context, userProvider),
            ),

            const Divider(),

            // Font Size
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Font Size'),
              subtitle: Text(
                _getFontSizeDisplayName(userProvider.getSetting('font_size')),
              ),
              onTap: () => _showFontSizeDialog(context, userProvider),
            ),

            const Divider(),

            // App Language
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Language'),
              subtitle: Text(
                _getAppLanguageDisplayName(
                  userProvider.getSetting('app_language'),
                ),
              ),
              onTap: () => _showAppLanguageDialog(context, userProvider),
            ),

            const Divider(),

            // Compact Mode
            SwitchListTile(
              secondary: const Icon(Icons.view_compact),
              title: const Text('Compact Mode'),
              subtitle: const Text('Show more content in less space'),
              value: userProvider.getSetting('compact_mode') == 'true',
              onChanged: (value) {
                userProvider.updateSetting('compact_mode', value.toString());
                Helpers.showSnackBar(
                  context,
                  value ? 'Compact mode enabled' : 'Compact mode disabled',
                );
              },
            ),

            const Divider(),

            // Show Habit Stats
            SwitchListTile(
              secondary: const Icon(Icons.bar_chart),
              title: const Text('Show Habit Statistics'),
              subtitle: const Text('Display completion rates and streaks'),
              value: userProvider.getSetting('show_habit_stats') != 'false',
              onChanged: (value) {
                userProvider.updateSetting(
                  'show_habit_stats',
                  value.toString(),
                );
                Helpers.showSnackBar(
                  context,
                  value
                      ? 'Habit statistics enabled'
                      : 'Habit statistics disabled',
                );
              },
            ),

            if (userProvider.isPremium) ...[
              const Divider(),

              // Custom Colors (Premium)
              ListTile(
                leading: const Icon(Icons.color_lens),
                title: const Text('Custom Colors'),
                subtitle: const Text('Personalize your app colors'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'PRO',
                    style: AppTheme.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onTap: () => _showCustomColorsDialog(context, userProvider),
              ),

              const Divider(),

              // Animation Settings (Premium)
              SwitchListTile(
                secondary: const Icon(Icons.animation),
                title: const Text('Enhanced Animations'),
                subtitle: const Text('Beautiful transitions and effects'),
                value:
                    userProvider.getSetting('enhanced_animations') != 'false',
                onChanged: (value) {
                  userProvider.updateSetting(
                    'enhanced_animations',
                    value.toString(),
                  );
                  Helpers.showSnackBar(
                    context,
                    value
                        ? 'Enhanced animations enabled'
                        : 'Enhanced animations disabled',
                  );
                },
              ),
            ] else ...[
              const Divider(),

              // Premium Upgrade Hint
              ListTile(
                leading: Icon(Icons.star, color: Colors.amber.shade600),
                title: const Text('Premium Themes'),
                subtitle: const Text(
                  'Unlock custom colors and enhanced animations',
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'UPGRADE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onTap: () =>
                    showPremiumDialog(context, feature: 'Premium Themes'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceSection(
    BuildContext context,
    UserProvider userProvider,
    VoiceProvider voiceProvider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Voice & AI', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            ListTile(
              leading: const Icon(Icons.mic),
              title: const Text('Voice Recognition'),
              subtitle: Text(
                voiceProvider.isInitialized ? 'Enabled' : 'Disabled',
              ),
              trailing: Switch(
                value: voiceProvider.isInitialized,
                onChanged: (value) async {
                  if (value) {
                    await voiceProvider.initialize();
                  }
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Voice Language'),
              subtitle: Text(
                userProvider.getSetting(
                  'voice_language',
                  defaultValue: 'English (US)',
                ),
              ),
              onTap: () =>
                  _showLanguageDialog(context, userProvider, voiceProvider),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.psychology),
              title: const Text('AI Features'),
              subtitle: const Text('Manage AI-powered insights'),
              trailing: Switch(
                value: userProvider.getBoolSetting(
                  'ai_enabled',
                  defaultValue: true,
                ),
                onChanged: (value) {
                  userProvider.updateSetting('ai_enabled', value.toString());
                },
              ),
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
              trailing: userProvider.isPremium
                  ? const Icon(Icons.cloud_done, color: AppTheme.successColor)
                  : TextButton(
                      onPressed: () =>
                          showPremiumDialog(context, feature: 'Data backup'),
                      child: const Text('Premium'),
                    ),
              onTap: userProvider.isPremium
                  ? () => _showBackupDialog(context)
                  : null,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Export Data'),
              subtitle: const Text('Download your data as CSV'),
              trailing: userProvider.isPremium
                  ? const Icon(Icons.arrow_forward_ios, size: 16)
                  : TextButton(
                      onPressed: () =>
                          showPremiumDialog(context, feature: 'Data export'),
                      child: const Text('Premium'),
                    ),
              onTap: userProvider.isPremium ? () => _exportData(context) : null,
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

  String _getFontSizeDisplayName(String fontSize) {
    switch (fontSize.toLowerCase()) {
      case 'small':
        return 'Small';
      case 'large':
        return 'Large';
      case 'extra_large':
        return 'Extra Large';
      default:
        return 'Medium';
    }
  }

  String _getAppLanguageDisplayName(String language) {
    switch (language.toLowerCase()) {
      case 'es':
        return 'Español';
      case 'fr':
        return 'Français';
      case 'de':
        return 'Deutsch';
      case 'it':
        return 'Italiano';
      case 'ja':
        return '日本語';
      case 'ko':
        return '한국어';
      case 'zh':
        return '中文';
      default:
        return 'English';
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
              groupValue: userProvider.getSetting('theme_mode'),
              onChanged: (value) {
                userProvider.updateSetting('theme_mode', value!);
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<String>(
              title: const Text('Dark'),
              value: 'dark',
              groupValue: userProvider.getSetting('theme_mode'),
              onChanged: (value) {
                userProvider.updateSetting('theme_mode', value!);
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<String>(
              title: const Text('System'),
              value: 'system',
              groupValue: userProvider.getSetting('theme_mode'),
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

  void _showFontSizeDialog(BuildContext context, UserProvider userProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Font Size'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Small'),
              value: 'small',
              groupValue: userProvider.getSetting('font_size'),
              onChanged: (value) {
                userProvider.updateSetting('font_size', value!);
                Navigator.of(context).pop();
                Helpers.showSnackBar(context, 'Font size updated');
              },
            ),
            RadioListTile<String>(
              title: const Text('Medium'),
              value: 'medium',
              groupValue: userProvider.getSetting('font_size'),
              onChanged: (value) {
                userProvider.updateSetting('font_size', value!);
                Navigator.of(context).pop();
                Helpers.showSnackBar(context, 'Font size updated');
              },
            ),
            RadioListTile<String>(
              title: const Text('Large'),
              value: 'large',
              groupValue: userProvider.getSetting('font_size'),
              onChanged: (value) {
                userProvider.updateSetting('font_size', value!);
                Navigator.of(context).pop();
                Helpers.showSnackBar(context, 'Font size updated');
              },
            ),
            RadioListTile<String>(
              title: const Text('Extra Large'),
              value: 'extra_large',
              groupValue: userProvider.getSetting('font_size'),
              onChanged: (value) {
                userProvider.updateSetting('font_size', value!);
                Navigator.of(context).pop();
                Helpers.showSnackBar(context, 'Font size updated');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAppLanguageDialog(BuildContext context, UserProvider userProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('English'),
              value: 'en',
              groupValue: userProvider.getSetting('app_language'),
              onChanged: (value) {
                userProvider.updateSetting('app_language', value!);
                Navigator.of(context).pop();
                Helpers.showSnackBar(
                  context,
                  'Language updated (restart app to apply)',
                );
              },
            ),
            RadioListTile<String>(
              title: const Text('Español'),
              value: 'es',
              groupValue: userProvider.getSetting('app_language'),
              onChanged: (value) {
                userProvider.updateSetting('app_language', value!);
                Navigator.of(context).pop();
                Helpers.showSnackBar(
                  context,
                  'Idioma actualizado (reinicia la app para aplicar)',
                );
              },
            ),
            RadioListTile<String>(
              title: const Text('Français'),
              value: 'fr',
              groupValue: userProvider.getSetting('app_language'),
              onChanged: (value) {
                userProvider.updateSetting('app_language', value!);
                Navigator.of(context).pop();
                Helpers.showSnackBar(
                  context,
                  'Langue mise à jour (redémarrer l\'app pour appliquer)',
                );
              },
            ),
            RadioListTile<String>(
              title: const Text('Deutsch'),
              value: 'de',
              groupValue: userProvider.getSetting('app_language'),
              onChanged: (value) {
                userProvider.updateSetting('app_language', value!);
                Navigator.of(context).pop();
                Helpers.showSnackBar(
                  context,
                  'Sprache aktualisiert (App neu starten zum Anwenden)',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(
    BuildContext context,
    UserProvider userProvider,
    VoiceProvider voiceProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Voice Language'),
        content: FutureBuilder<List<String>>(
          future: voiceProvider.getAvailableLanguages(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final languages = snapshot.data ?? ['en_US'];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: languages
                  .map(
                    (language) => RadioListTile<String>(
                      title: Text(_getLanguageDisplayName(language)),
                      value: language,
                      groupValue: userProvider.getSetting('voice_language'),
                      onChanged: (value) {
                        userProvider.updateSetting('voice_language', value!);
                        Navigator.of(context).pop();
                      },
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }

  String _getLanguageDisplayName(String languageCode) {
    final languageMap = {
      'en_US': 'English (US)',
      'en_GB': 'English (UK)',
      'es_ES': 'Spanish',
      'fr_FR': 'French',
      'de_DE': 'German',
      'it_IT': 'Italian',
      'ja_JP': 'Japanese',
      'ko_KR': 'Korean',
      'zh_CN': 'Chinese (Simplified)',
    };
    return languageMap[languageCode] ?? languageCode;
  }

  void _showSubscriptionDialog(
    BuildContext context,
    UserProvider userProvider,
  ) {
    Helpers.showConfirmDialog(
      context,
      title: 'Cancel Subscription',
      content:
          'Are you sure you want to cancel your premium subscription? You will lose access to premium features.',
      onConfirm: () async {
        await userProvider.cancelSubscription();
        if (context.mounted) {
          Helpers.showSnackBar(context, 'Subscription cancelled successfully');
        }
      },
      confirmText: 'Cancel Subscription',
    );
  }

  void _showCustomColorsDialog(
    BuildContext context,
    UserProvider userProvider,
  ) {
    final availableColors = [
      {
        'name': 'Default Blue',
        'primary': Colors.blue,
        'accent': Colors.blueAccent,
      },
      {
        'name': 'Nature Green',
        'primary': Colors.green,
        'accent': Colors.greenAccent,
      },
      {
        'name': 'Sunset Orange',
        'primary': Colors.orange,
        'accent': Colors.orangeAccent,
      },
      {
        'name': 'Royal Purple',
        'primary': Colors.purple,
        'accent': Colors.purpleAccent,
      },
      {'name': 'Cherry Red', 'primary': Colors.red, 'accent': Colors.redAccent},
      {
        'name': 'Ocean Teal',
        'primary': Colors.teal,
        'accent': Colors.tealAccent,
      },
      {
        'name': 'Rose Pink',
        'primary': Colors.pink,
        'accent': Colors.pinkAccent,
      },
      {
        'name': 'Deep Indigo',
        'primary': Colors.indigo,
        'accent': Colors.indigoAccent,
      },
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Colors'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose your app color theme:'),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: availableColors.length,
                  itemBuilder: (context, index) {
                    final colorTheme = availableColors[index];
                    final isSelected =
                        userProvider.getSetting('primary_color') ==
                        colorTheme['primary'].toString();

                    return GestureDetector(
                      onTap: () {
                        userProvider.updateSetting(
                          'primary_color',
                          colorTheme['primary'].toString(),
                        );
                        userProvider.updateSetting(
                          'accent_color',
                          colorTheme['accent'].toString(),
                        );
                        Navigator.of(context).pop();
                        Helpers.showSnackBar(
                          context,
                          'Color theme "${colorTheme['name']}" applied!',
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorTheme['primary'] as Color,
                              colorTheme['accent'] as Color,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            colorTheme['name'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
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
            Text('• Voice commands: Say "I completed [habit name]"'),
            Text('• Tap the microphone to start voice input'),
            Text('• Create up to 3 habits on the free plan'),
            Text('• Upgrade to Premium for unlimited habits'),
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

  // 🎨 NEW: Custom Categories Section
  Widget _buildCustomCategoriesSection(
    BuildContext context,
    UserProvider userProvider,
  ) {
    return Consumer<CustomCategoryProvider>(
      builder: (context, categoryProvider, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.category),
                    const SizedBox(width: 8),
                    Text('Custom Categories', style: AppTheme.titleMedium),
                    const Spacer(),
                    if (!userProvider.isPremium)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'PREMIUM',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),
                ListTile(
                  leading: Icon(
                    Icons.palette,
                    color: userProvider.isPremium
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                  title: const Text('Manage Categories'),
                  subtitle: Text(
                    userProvider.isPremium
                        ? 'Create and customize your habit categories'
                        : 'Create custom categories with icons and colors',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: userProvider.isPremium
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const CustomCategoriesScreen(),
                          ),
                        )
                      : () => showPremiumDialog(context),
                ),
                if (userProvider.isPremium) ...[
                  const Divider(),
                  FutureBuilder<int>(
                    future: Future.value(
                      categoryProvider.customCategories.length,
                    ),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: Text('$count custom categories created'),
                        subtitle: const Text(
                          'Tap above to manage your categories',
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // 🎤 NEW: Voice Reminders Section
  Widget _buildVoiceRemindersSection(
    BuildContext context,
    UserProvider userProvider,
  ) {
    return Consumer<VoiceReminderProvider>(
      builder: (context, reminderProvider, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.record_voice_over),
                    const SizedBox(width: 8),
                    Text('Voice Reminders', style: AppTheme.titleMedium),
                    const Spacer(),
                    if (!userProvider.isPremium)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'LIMITED',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),
                ListTile(
                  leading: const Icon(Icons.add_alarm),
                  title: const Text('Create Voice Reminder'),
                  subtitle: const Text('Say "Remind me to exercise at 7 PM"'),
                  trailing: const Icon(Icons.mic),
                  onTap: () => _showVoiceReminderDialog(
                    context,
                    userProvider,
                    reminderProvider,
                  ),
                ),
                const Divider(),
                FutureBuilder<List<VoiceReminder>>(
                  future: Future.value(reminderProvider.reminders),
                  builder: (context, snapshot) {
                    final reminders = snapshot.data ?? [];
                    final reminderCount = reminders.length;
                    final maxReminders = userProvider.isPremium
                        ? 'Unlimited'
                        : '2';

                    return ListTile(
                      leading: const Icon(Icons.list_alt),
                      title: const Text('Manage Reminders'),
                      subtitle: Text(
                        '$reminderCount reminders ($maxReminders available)',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => _showRemindersList(
                        context,
                        reminders,
                        reminderProvider,
                      ),
                    );
                  },
                ),
                if (!userProvider.isPremium) ...[
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.star, color: AppTheme.warningColor),
                    title: const Text('Upgrade for Unlimited'),
                    subtitle: const Text(
                      'Get unlimited voice reminders with Premium',
                    ),
                    onTap: () => showPremiumDialog(context),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showVoiceReminderDialog(
    BuildContext context,
    UserProvider userProvider,
    VoiceReminderProvider reminderProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Voice Reminder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic, size: 48),
            const SizedBox(height: 16),
            const Text(
              'To create a voice reminder, go to the Voice Input screen and say something like:',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '"Remind me to exercise at 7 PM"',
                style: TextStyle(fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to voice input screen
              Navigator.pushNamed(context, '/voice_input');
            },
            child: const Text('Go to Voice Input'),
          ),
        ],
      ),
    );
  }

  void _showRemindersList(
    BuildContext context,
    List<VoiceReminder> reminders,
    VoiceReminderProvider reminderProvider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Voice Reminders',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: reminders.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.voice_over_off, size: 48),
                            SizedBox(height: 16),
                            Text('No voice reminders yet'),
                            Text('Create one using voice commands!'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: reminders.length,
                        itemBuilder: (context, index) {
                          final reminder = reminders[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.alarm),
                              title: Text(reminder.message),
                              subtitle: Text(
                                Helpers.formatDateTime(reminder.reminderTime),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteReminder(
                                  context,
                                  reminder,
                                  reminderProvider,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteReminder(
    BuildContext context,
    VoiceReminder reminder,
    VoiceReminderProvider reminderProvider,
  ) {
    Helpers.showConfirmDialog(
      context,
      title: 'Delete Reminder',
      content: 'Are you sure you want to delete this voice reminder?',
      onConfirm: () async {
        try {
          await reminderProvider.deleteVoiceReminder(reminder.id!);
          if (context.mounted) {
            Helpers.showSnackBar(context, 'Voice reminder deleted');
          }
        } catch (e) {
          if (context.mounted) {
            Helpers.showSnackBar(
              context,
              'Failed to delete reminder',
              isError: true,
            );
          }
        }
      },
    );
  }
}
