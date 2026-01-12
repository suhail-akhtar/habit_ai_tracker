import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🔧 ADDED
import '../providers/voice_provider.dart';
import '../providers/habit_provider.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';
import '../widgets/voice_button.dart';

class VoiceInputScreen extends StatefulWidget {
  const VoiceInputScreen({super.key});

  @override
  State<VoiceInputScreen> createState() => _VoiceInputScreenState();
}

class _VoiceInputScreenState extends State<VoiceInputScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // 🔧 UPDATED: Auto-process state
  bool _autoProcess = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeVoiceProvider();
    _loadAutoProcessState(); // 🔧 ADDED: Load saved state
  }

  // 🔧 ADDED: Load auto-process state from storage
  void _loadAutoProcessState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _autoProcess = prefs.getBool('auto_process_voice') ?? false;
      });
    }
  }

  // 🔧 ADDED: Save auto-process state to storage
  void _saveAutoProcessState(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_process_voice', value);
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  void _initializeVoiceProvider() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final voiceProvider = context.read<VoiceProvider>();
      if (!voiceProvider.isInitialized) {
        voiceProvider.initialize();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Input'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tips_and_updates),
            onPressed: _showVoiceInputTips,
            tooltip: 'Voice Input Tips',
          ),
        ],
      ),
      body: Consumer2<VoiceProvider, HabitProvider>(
        builder: (context, voiceProvider, habitProvider, child) {
          // Auto-process logic
          if (_autoProcess &&
              !voiceProvider.isListening &&
              voiceProvider.currentWords.isNotEmpty &&
              !voiceProvider.isProcessing) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && voiceProvider.currentWords.isNotEmpty) {
                _processVoiceInput(voiceProvider, habitProvider);
              }
            });
          }

          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildVoiceVisualizer(voiceProvider),
                            const SizedBox(height: AppTheme.spacingXL),
                            _buildStatusCard(voiceProvider),
                            const SizedBox(height: AppTheme.spacingL),
                            _buildVoiceTextCard(voiceProvider),
                            const SizedBox(height: AppTheme.spacingL),
                            _buildAutoProcessCheckbox(),
                            const SizedBox(height: AppTheme.spacingXL),
                            _buildActionButtons(voiceProvider, habitProvider),
                            const SizedBox(height: AppTheme.spacingL),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacingM,
                        AppTheme.spacingS,
                        AppTheme.spacingM,
                        AppTheme.spacingM,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(26),
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          if (voiceProvider.isListening) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => voiceProvider.stopListening(),
                                icon: const Icon(Icons.stop),
                                label: const Text('Stop Listening'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.errorColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppTheme.spacingM,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingM),
                          ],
                          _buildInstructionsCard(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 🔧 UPDATED: Auto-process checkbox with persistence
  Widget _buildAutoProcessCheckbox() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Row(
          children: [
            Checkbox(
              value: _autoProcess,
              onChanged: (value) {
                setState(() {
                  _autoProcess = value ?? false;
                });
                _saveAutoProcessState(_autoProcess); // 🔧 ADDED: Save state
              },
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto-process voice commands',
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    'Automatically process commands when speech ends',
                    style: AppTheme.bodySmall.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(179),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... rest of your existing methods remain unchanged ...
  // (keeping all the other methods exactly as they were)

  Widget _buildVoiceVisualizer(VoiceProvider voiceProvider) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withAlpha(26),
            Theme.of(context).colorScheme.primary.withAlpha(13),
            Colors.transparent,
          ],
        ),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
            ),
            VoiceButton(
              size: 80,
              isFloating: false,
              onPressed: () => _handleVoiceButtonPressed(voiceProvider),
            ),
            if (voiceProvider.confidence > 0)
              Positioned(
                bottom: 20,
                child: _buildConfidenceIndicator(voiceProvider.confidence),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceIndicator(double confidence) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.graphic_eq,
            size: 12,
            color: _getConfidenceColor(confidence),
          ),
          const SizedBox(width: AppTheme.spacingXS),
          Text(
            '${(confidence * 100).toInt()}%',
            style: AppTheme.bodySmall.copyWith(
              color: _getConfidenceColor(confidence),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(VoiceProvider voiceProvider) {
    return AnimatedContainer(
      duration: AppTheme.shortAnimation,
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: _getStatusCardColor(voiceProvider),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: _getStatusBorderColor(voiceProvider),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getStatusIcon(voiceProvider),
                color: _getStatusIconColor(voiceProvider),
                size: 20,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Flexible(
                child: Text(
                  _getStatusText(voiceProvider),
                  style: AppTheme.titleMedium.copyWith(
                    color: _getStatusTextColor(voiceProvider),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          if (voiceProvider.isListening) ...[
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'Hold phone close to mouth • Speak clearly • Say "I completed [habit name]"',
              style: AppTheme.bodySmall.copyWith(
                color: _getStatusTextColor(voiceProvider).withAlpha(204),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (voiceProvider.confidence > 0 && !voiceProvider.isListening) ...[
            const SizedBox(height: AppTheme.spacingS),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.graphic_eq,
                  size: 16,
                  color: _getConfidenceColor(voiceProvider.confidence),
                ),
                const SizedBox(width: AppTheme.spacingXS),
                Text(
                  'Confidence: ${(voiceProvider.confidence * 100).toInt()}%',
                  style: AppTheme.bodySmall.copyWith(
                    color: _getConfidenceColor(voiceProvider.confidence),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return AppTheme.successColor;
    if (confidence >= 0.6) return AppTheme.warningColor;
    if (confidence >= 0.4) return AppTheme.infoColor;
    return AppTheme.errorColor;
  }

  Widget _buildVoiceTextCard(VoiceProvider voiceProvider) {
    return AnimatedContainer(
      duration: AppTheme.shortAnimation,
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(77),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppTheme.spacingXS),
              Text(
                'Voice Input',
                style: AppTheme.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          AnimatedSwitcher(
            duration: AppTheme.shortAnimation,
            child: Text(
              voiceProvider.currentWords.isEmpty
                  ? 'Your voice input will appear here...'
                  : voiceProvider.currentWords,
              key: ValueKey(voiceProvider.currentWords),
              style: AppTheme.bodyLarge.copyWith(
                color: voiceProvider.currentWords.isEmpty
                    ? Theme.of(context).colorScheme.onSurface.withAlpha(128)
                    : Theme.of(context).colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    VoiceProvider voiceProvider,
    HabitProvider habitProvider,
  ) {
    return AnimatedSwitcher(
      duration: AppTheme.shortAnimation,
      child: voiceProvider.currentWords.isNotEmpty && !voiceProvider.isListening
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: voiceProvider.isProcessing
                        ? null
                        : () =>
                              _processVoiceInput(voiceProvider, habitProvider),
                    icon: voiceProvider.isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.psychology),
                    label: Text(
                      voiceProvider.isProcessing ? 'Processing...' : 'Process',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.infoColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacingM,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _clearVoiceInput(voiceProvider),
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacingM,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildInstructionsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              'Voice Commands',
              style: AppTheme.titleMedium.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _showVoiceCommandsHelp,
              child: const Text('See All'),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingS),
        Text(
          '• "I completed [habit name]" • "I did [habit name] today"\n'
          '• "I skipped [habit name]" • "I missed [habit name]"',
          style: AppTheme.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(204),
            height: 1.3,
          ),
        ),
      ],
    );
  }

  // Helper methods for status styling
  Color _getStatusCardColor(VoiceProvider voiceProvider) {
    if (voiceProvider.error != null) {
      return AppTheme.errorColor.withAlpha(26);
    } else if (voiceProvider.isListening) {
      return AppTheme.successColor.withAlpha(26);
    } else if (voiceProvider.isProcessing) {
      return AppTheme.infoColor.withAlpha(26);
    } else {
      return Theme.of(context).colorScheme.surface;
    }
  }

  Color _getStatusBorderColor(VoiceProvider voiceProvider) {
    if (voiceProvider.error != null) {
      return AppTheme.errorColor;
    } else if (voiceProvider.isListening) {
      return AppTheme.successColor;
    } else if (voiceProvider.isProcessing) {
      return AppTheme.infoColor;
    } else {
      return Theme.of(context).colorScheme.outline.withAlpha(77);
    }
  }

  IconData _getStatusIcon(VoiceProvider voiceProvider) {
    if (voiceProvider.error != null) {
      return Icons.error_outline;
    } else if (voiceProvider.isListening) {
      return Icons.mic;
    } else if (voiceProvider.isProcessing) {
      return Icons.psychology;
    } else {
      return Icons.mic_none;
    }
  }

  Color _getStatusIconColor(VoiceProvider voiceProvider) {
    if (voiceProvider.error != null) {
      return AppTheme.errorColor;
    } else if (voiceProvider.isListening) {
      return AppTheme.successColor;
    } else if (voiceProvider.isProcessing) {
      return AppTheme.infoColor;
    } else {
      return Theme.of(context).colorScheme.onSurface.withAlpha(153);
    }
  }

  Color _getStatusTextColor(VoiceProvider voiceProvider) {
    return _getStatusIconColor(voiceProvider);
  }

  String _getStatusText(VoiceProvider voiceProvider) {
    if (voiceProvider.error != null) {
      return voiceProvider.error!;
    } else if (voiceProvider.isListening) {
      return 'Listening... Speak now';
    } else if (voiceProvider.isProcessing) {
      return 'Processing with AI...';
    } else if (!voiceProvider.isInitialized) {
      return 'Initializing voice recognition...';
    } else if (voiceProvider.currentWords.isNotEmpty) {
      return 'Speech captured! Tap Process to continue';
    } else {
      return 'Tap microphone to start voice input';
    }
  }

  void _handleVoiceButtonPressed(VoiceProvider voiceProvider) async {
    if (voiceProvider.isListening) {
      await voiceProvider.stopListening();
    } else {
      await voiceProvider.startListening();
    }
  }

  void _processVoiceInput(
    VoiceProvider voiceProvider,
    HabitProvider habitProvider,
  ) async {
    if (voiceProvider.currentWords.isEmpty) return;

    final command = await voiceProvider.processVoiceInput(
      voiceProvider.currentWords,
      habitProvider.habits,
    );

    if (command != null && command.confidence > 0.6) {
      final success = await voiceProvider.executeVoiceCommand(
        command,
        habitProvider,
      );

      if (mounted) {
        Helpers.showSnackBar(
          context,
          success
              ? 'Voice command executed successfully! 🎉'
              : 'Failed to execute command',
          isError: !success,
        );
      }

      if (success) {
        voiceProvider.clearWords();
      }
    } else {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Could not understand the command. Please try again.',
          isError: true,
        );
      }
    }
  }

  void _clearVoiceInput(VoiceProvider voiceProvider) {
    voiceProvider.clearWords();
  }

  void _showVoiceCommandsHelp() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusL),
        ),
      ),
      builder: (context) => const VoiceCommandsHelpSheet(),
    );
  }

  void _showVoiceInputTips() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.tips_and_updates,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppTheme.spacingS),
            const Text('Voice Input Tips'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTipItem('📱', 'Hold phone 6-8 inches from your mouth'),
            _buildTipItem('🔇', 'Find a quiet environment'),
            _buildTipItem('🗣️', 'Speak clearly and at normal pace'),
            _buildTipItem('⏱️', 'You have 25 seconds to speak'),
            _buildTipItem('✅', 'Say "I completed [exact habit name]"'),
            _buildTipItem('❌', 'Say "I skipped [exact habit name]"'),
            _buildTipItem('🤖', 'Enable auto-process for hands-free operation'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String emoji, String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(child: Text(tip, style: AppTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class VoiceCommandsHelpSheet extends StatelessWidget {
  const VoiceCommandsHelpSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text('Voice Commands Guide', style: AppTheme.headlineSmall),
          const SizedBox(height: AppTheme.spacingM),
          _buildCommandSection(context, 'Habit Completion', [
            '"I completed my morning run"',
            '"I did my meditation today"',
            '"I finished drinking water"',
            '"I just did my exercise"',
          ]),
          _buildCommandSection(context, 'Habit Skipping', [
            '"I skipped my workout"',
            '"I missed my reading today"',
            '"I didn\'t do my meditation"',
            '"I can\'t do my run today"',
          ]),
          _buildCommandSection(context, 'Tips for Better Recognition', [
            'Speak clearly and at normal pace',
            'Use exact habit names when possible',
            'Speak in a quiet environment',
            'Hold the button close to your mouth',
          ], isInfo: true),
          SizedBox(
            height: MediaQuery.of(context).padding.bottom + AppTheme.spacingM,
          ),
        ],
      ),
    );
  }

  Widget _buildCommandSection(
    BuildContext context,
    String title,
    List<String> commands, {
    bool isInfo = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.titleMedium.copyWith(
            color: isInfo
                ? AppTheme.infoColor
                : Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppTheme.spacingS),
        ...commands.map(
          (command) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingXS),
            child: Row(
              children: [
                Icon(
                  isInfo ? Icons.lightbulb_outline : Icons.mic,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Text(
                    command,
                    style: AppTheme.bodyMedium.copyWith(
                      fontStyle: isInfo ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
      ],
    );
  }
}
