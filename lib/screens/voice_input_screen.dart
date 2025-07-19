import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Input'),
        centerTitle: true,
      ),
      body: Consumer2<VoiceProvider, HabitProvider>(
        builder: (context, voiceProvider, habitProvider, child) {
          // Control wave animation based on listening state
          if (voiceProvider.isListening) {
            _waveController.repeat(reverse: true);
          } else {
            _waveController.stop();
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildVoiceVisualizer(voiceProvider),
                        const SizedBox(height: AppTheme.spacingXL),
                        _buildStatusText(voiceProvider),
                        const SizedBox(height: AppTheme.spacingL),
                        _buildVoiceText(voiceProvider),
                        const SizedBox(height: AppTheme.spacingXL),
                        _buildActionButtons(voiceProvider, habitProvider),
                      ],
                    ),
                  ),
                  _buildInstructions(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVoiceVisualizer(VoiceProvider voiceProvider) {
    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        return Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.3),
                Theme.of(context).colorScheme.primary.withOpacity(0.1),
                Colors.transparent,
              ],
            ),
          ),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer ring
                if (voiceProvider.isListening)
                  Container(
                    width: 160 + (20 * _waveAnimation.value),
                    height: 160 + (20 * _waveAnimation.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                  ),

                // Middle ring
                if (voiceProvider.isListening)
                  Container(
                    width: 120 + (15 * _waveAnimation.value),
                    height: 120 + (15 * _waveAnimation.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                  ),

                // Inner circle
                VoiceButton(
                  size: 80,
                  isFloating: false,
                  onPressed: () => _handleVoiceButtonPressed(voiceProvider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusText(VoiceProvider voiceProvider) {
    String statusText;
    Color statusColor;

    if (voiceProvider.error != null) {
      statusText = 'Error: ${voiceProvider.error}';
      statusColor = AppTheme.errorColor;
    } else if (voiceProvider.isListening) {
      statusText = 'Listening...';
      statusColor = AppTheme.successColor;
    } else if (voiceProvider.status == 'Processing with AI...') {
      statusText = 'Processing with AI...';
      statusColor = AppTheme.infoColor;
    } else {
      statusText = 'Tap to start voice input';
      statusColor = Theme.of(context).colorScheme.onSurface;
    }

    return AnimatedSwitcher(
      duration: AppTheme.shortAnimation,
      child: Text(
        statusText,
        key: ValueKey(statusText),
        style: AppTheme.titleMedium.copyWith(
          color: statusColor,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildVoiceText(VoiceProvider voiceProvider) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: AnimatedSwitcher(
        duration: AppTheme.shortAnimation,
        child: Text(
          voiceProvider.currentWords.isEmpty
              ? 'Your voice input will appear here...'
              : voiceProvider.currentWords,
          key: ValueKey(voiceProvider.currentWords),
          style: AppTheme.bodyLarge.copyWith(
            color: voiceProvider.currentWords.isEmpty
                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                : Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildActionButtons(
      VoiceProvider voiceProvider, HabitProvider habitProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (voiceProvider.currentWords.isNotEmpty &&
            !voiceProvider.isListening) ...[
          ElevatedButton.icon(
            onPressed: () => _processVoiceInput(voiceProvider, habitProvider),
            icon: const Icon(Icons.psychology),
            label: const Text('Process'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.infoColor,
              foregroundColor: Colors.white,
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _clearVoiceInput(voiceProvider),
            icon: const Icon(Icons.clear),
            label: const Text('Clear'),
          ),
        ],
      ],
    );
  }

  Widget _buildInstructions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
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
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              '• "I completed [habit name]"\n'
              '• "I did [habit name] today"\n'
              '• "I skipped [habit name]"\n'
              '• "I missed [habit name]"',
              style: AppTheme.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleVoiceButtonPressed(VoiceProvider voiceProvider) async {
    if (voiceProvider.isListening) {
      voiceProvider.stopListening();
    } else {
      await voiceProvider.startListening();
    }
  }

  void _processVoiceInput(
      VoiceProvider voiceProvider, HabitProvider habitProvider) async {
    if (voiceProvider.currentWords.isEmpty) return;

    final result = await voiceProvider.processVoiceInput(
      voiceProvider.currentWords,
      habitProvider.habits,
    );

    if (result['habit'] != null && result['confidence'] > 0.6) {
      await voiceProvider.executeVoiceCommand(result, habitProvider);

      // Show success feedback
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Voice command executed successfully!',
          isError: false,
        );
      }
    } else {
      // Show confidence or error feedback
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
    // Clear the current words
    // Note: This would require adding a clear method to VoiceProvider
    setState(() {
      // Reset UI state
    });
  }
}
