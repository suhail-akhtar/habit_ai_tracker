import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/voice_provider.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';
import '../widgets/premium_dialog.dart';
import '../config/app_config.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer2<UserProvider, VoiceProvider>(
        builder: (context, userProvider, voiceProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAccountSection(context, userProvider),
                const SizedBox(height: AppTheme.spacingL),
                _buildAppearanceSection(context, userProvider),
                const SizedBox(height: AppTheme.spacingL),
                _buildVoiceSection(context, userProvider, voiceProvider),
                const SizedBox(height: AppTheme.spacingL),
                _buildNotificationsSection(context, userProvider),
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
            Text(
              'Account',
              style: AppTheme.titleMedium,
            ),
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
                  ? Icon(
                      Icons.star,
                      color: AppTheme.warningColor,
                    )
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

  Widget _buildAppearanceSection(
      BuildContext context, UserProvider userProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: AppTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacingM),
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('Theme'),
              subtitle: Text(
                _getThemeDisplayName(userProvider.getSetting('theme_mode')),
              ),
              onTap: () => _showThemeDialog(context, userProvider),
            ),
            if (userProvider.isPremium) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.color_lens),
                title: const Text('Custom Colors'),
                subtitle: const Text('Personalize your app colors'),
                onTap: () => _showCustomColorsDialog(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceSection(BuildContext context, UserProvider userProvider,
      VoiceProvider voiceProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voice & AI',
              style: AppTheme.titleMedium,
            ),
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
                userProvider.getSetting('voice_language',
                    defaultValue: 'English (US)'),
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
                value: userProvider.getBoolSetting('ai_enabled',
                    defaultValue: true),
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

  Widget _buildNotificationsSection(
      BuildContext context, UserProvider userProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications',
              style: AppTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacingM),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Habit Reminders'),
              subtitle: const Text('Get reminded about your habits'),
              trailing: Switch(
                value: userProvider.getBoolSetting('notifications_enabled',
                    defaultValue: true),
                onChanged: (value) {
                  userProvider.updateSetting(
                      'notifications_enabled', value.toString());
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Reminder Time'),
              subtitle: Text(
                userProvider.getSetting('reminder_time',
                    defaultValue: '09:00 AM'),
              ),
              onTap: () => _showTimePickerDialog(context, userProvider),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.celebration),
              title: const Text('Achievement Notifications'),
              subtitle: const Text('Celebrate your streaks and milestones'),
              trailing: Switch(
                value: userProvider.getBoolSetting('achievement_notifications',
                    defaultValue: true),
                onChanged: (value) {
                  userProvider.updateSetting(
                      'achievement_notifications', value.toString());
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
            Text(
              'Data & Privacy',
              style: AppTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacingM),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Analytics'),
              subtitle: const Text('Help improve the app with usage data'),
              trailing: Switch(
                value: userProvider.getBoolSetting('analytics_enabled',
                    defaultValue: true),
                onChanged: (value) {
                  userProvider.updateSetting(
                      'analytics_enabled', value.toString());
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
              leading:
                  const Icon(Icons.delete_forever, color: AppTheme.errorColor),
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
            Text(
              'About',
              style: AppTheme.titleMedium,
            ),
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

  // Helper methods for dialogs and actions
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

  void _showLanguageDialog(BuildContext context, UserProvider userProvider,
      VoiceProvider voiceProvider) {
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
                  .map((language) => RadioListTile<String>(
                        title: Text(_getLanguageDisplayName(language)),
                        value: language,
                        groupValue: userProvider.getSetting('voice_language'),
                        onChanged: (value) {
                          userProvider.updateSetting('voice_language', value!);
                          Navigator.of(context).pop();
                        },
                      ))
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

  void _showTimePickerDialog(
      BuildContext context, UserProvider userProvider) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time != null) {
      final timeString = time.format(context);
      userProvider.updateSetting('reminder_time', timeString);
    }
  }

  void _showSubscriptionDialog(
      BuildContext context, UserProvider userProvider) {
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
            'Your data is automatically backed up to the cloud. Last backup: Just now'),
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
    // In a real app, this would open the App Store/Play Store
  }
}
