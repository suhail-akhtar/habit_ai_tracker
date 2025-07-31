import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ai_chatbot_service.dart';
import '../services/text_to_speech_service.dart';
import '../providers/habit_provider.dart';
import '../providers/user_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/theme.dart';
import '../widgets/premium_dialog.dart';

/// AI Chatbot screen for habit coaching and FAQ support
class AIChatbotScreen extends StatefulWidget {
  const AIChatbotScreen({super.key});

  @override
  State<AIChatbotScreen> createState() => _AIChatbotScreenState();
}

class _AIChatbotScreenState extends State<AIChatbotScreen> {
  final AIChatbotService _chatbotService = AIChatbotService();
  final TextToSpeechService _ttsService = TextToSpeechService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isTtsEnabled = false;

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _addWelcomeMessage();
  }

  Future<void> _initializeTts() async {
    await _ttsService.initialize();
    setState(() {
      _isTtsEnabled = _ttsService.isEnabled;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(
        ChatMessage(
          id: 'welcome',
          content:
              "Hi! I'm your AI habit coach. I'm here to help you build better habits, stay motivated, and answer any questions about the app. What can I help you with today?",
          isUser: false,
          timestamp: DateTime.now(),
          messageType: ChatMessageType.coaching,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Habit Coach'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          Consumer<UserProvider>(
            builder: (context, userProvider, child) {
              return FutureBuilder<UsageLimitResult>(
                future: _chatbotService.checkUsageLimits(
                  userProvider.isPremium,
                ),
                builder: (context, snapshot) {
                  final limits =
                      snapshot.data ??
                      UsageLimitResult(
                        canSendMessage: false,
                        remainingMessages: 0,
                      );
                  return Padding(
                    padding: const EdgeInsets.only(right: AppTheme.spacingM),
                    child: Center(
                      child: Text(
                        '${limits.remainingMessages} left',
                        style: AppTheme.bodySmall.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimary.withOpacity(0.8),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: Icon(_isTtsEnabled ? Icons.volume_up : Icons.volume_off),
            onPressed: _toggleTts,
            tooltip: _isTtsEnabled
                ? 'Disable text-to-speech'
                : 'Enable text-to-speech',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showFAQDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildUsageBanner(),
          Expanded(child: _buildChatMessages()),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildUsageBanner() {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        return FutureBuilder<UsageLimitResult>(
          future: _chatbotService.checkUsageLimits(userProvider.isPremium),
          builder: (context, snapshot) {
            final limits =
                snapshot.data ??
                UsageLimitResult(canSendMessage: false, remainingMessages: 0);

            if (userProvider.isPremium) {
              return Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: Theme.of(context).colorScheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      limits.remainingMessages > 0
                          ? 'Premium: ${limits.remainingMessages} messages remaining today'
                          : 'Premium: ${Constants.premiumChatbotMessages}/${Constants.premiumChatbotMessages} messages used today',
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              );
            } else {
              return Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      color: Theme.of(context).colorScheme.error,
                      size: 16,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Text(
                        limits.remainingMessages > 0
                            ? 'Free: ${limits.remainingMessages}/${Constants.freeChatbotMessages} messages left today'
                            : 'Free: ${Constants.freeChatbotMessages}/${Constants.freeChatbotMessages} messages used today',
                        style: AppTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: () => showPremiumDialog(
                        context,
                        feature: 'Get 50 daily AI chat messages',
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingS,
                        ),
                      ),
                      child: const Text('Upgrade'),
                    ),
                  ],
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildChatMessages() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppTheme.spacingM),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoading && index == _messages.length) {
          return _buildTypingIndicator();
        }

        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusM).copyWith(
                  bottomRight: isUser
                      ? const Radius.circular(AppTheme.radiusS)
                      : null,
                  bottomLeft: isUser
                      ? null
                      : const Radius.circular(AppTheme.radiusS),
                ),
              ),
              child: Text(
                message.content,
                style: AppTheme.bodyMedium.copyWith(
                  color: isUser
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isUser) ...[
                  Text(
                    message.messageType.icon,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: AppTheme.spacingXS),
                  if (_isTtsEnabled) ...[
                    InkWell(
                      onTap: () => _speakMessage(message.content),
                      child: Icon(
                        Icons.volume_up,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingXS),
                  ],
                ],
                Text(
                  Helpers.formatTimeAgo(message.timestamp),
                  style: AppTheme.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(
            AppTheme.radiusM,
          ).copyWith(bottomLeft: const Radius.circular(AppTheme.radiusS)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              'AI is typing...',
              style: AppTheme.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Consumer2<UserProvider, HabitProvider>(
      builder: (context, userProvider, habitProvider, child) {
        return FutureBuilder<UsageLimitResult>(
          future: _chatbotService.checkUsageLimits(userProvider.isPremium),
          builder: (context, snapshot) {
            final limits =
                snapshot.data ??
                UsageLimitResult(canSendMessage: false, remainingMessages: 0);

            return Container(
              padding: EdgeInsets.only(
                left: AppTheme.spacingM,
                right: AppTheme.spacingM,
                top: AppTheme.spacingS,
                bottom:
                    MediaQuery.of(context).padding.bottom + AppTheme.spacingS,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: limits.canSendMessage
                            ? 'Ask me about habits, motivation, or app features...'
                            : 'Daily message limit reached',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusL),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingM,
                          vertical: AppTheme.spacingS,
                        ),
                      ),
                      maxLines: null,
                      enabled: limits.canSendMessage && !_isLoading,
                      onSubmitted: (value) =>
                          _sendMessage(userProvider, habitProvider),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  IconButton(
                    onPressed: limits.canSendMessage && !_isLoading
                        ? () => _sendMessage(userProvider, habitProvider)
                        : null,
                    icon: Icon(_isLoading ? Icons.hourglass_empty : Icons.send),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _sendMessage(
    UserProvider userProvider,
    HabitProvider habitProvider,
  ) async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Add user message to chat
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: message,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      // Get AI response
      final response = await _chatbotService.sendMessage(
        message: message,
        isPremiumUser: userProvider.isPremium,
        userHabits: habitProvider.habits,
        conversationHistory: _messages.where((m) => !m.isUser).take(3).toList(),
      );

      // Add AI response to chat
      final aiMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: response.message,
        isUser: false,
        timestamp: DateTime.now(),
        messageType: response.messageType,
      );

      setState(() {
        _messages.add(aiMessage);
        _isLoading = false;
      });

      _scrollToBottom();

      // Handle action results if any action was executed
      if (response.actionExecuted && response.actionResult != null) {
        final actionResult = response.actionResult!;

        // Show toast message for action feedback
        if (actionResult.showToast && actionResult.toastMessage != null) {
          Helpers.showSnackBar(
            context,
            actionResult.toastMessage!,
            isError: !actionResult.success,
          );
        }

        // Handle follow-up questions
        if (actionResult.needsMoreInfo &&
            actionResult.followUpQuestion != null) {
          // Add follow-up question as AI message
          Future.delayed(const Duration(milliseconds: 500), () {
            final followUpMessage = ChatMessage(
              id: '${DateTime.now().millisecondsSinceEpoch}_followup',
              content: actionResult.followUpQuestion!,
              isUser: false,
              timestamp: DateTime.now(),
              messageType: ChatMessageType.coaching,
            );

            setState(() {
              _messages.add(followUpMessage);
            });

            _scrollToBottom();

            // Speak follow-up question if TTS is enabled
            if (_isTtsEnabled) {
              _speakMessage(actionResult.followUpQuestion!);
            }
          });
        }
      }

      // Automatically speak AI response if TTS is enabled
      if (_isTtsEnabled && !response.isError) {
        _speakMessage(response.message);
      }

      // Show error if there was one
      if (response.isError && mounted) {
        Helpers.showSnackBar(context, response.message, isError: true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Failed to get response. Please try again.',
          isError: true,
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showFAQDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Frequently Asked Questions'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFAQItem(
                'How to use voice commands?',
                'Tap the microphone and say "I completed [habit name]" or "I skipped [habit name]". You can also set reminders.',
              ),
              _buildFAQItem(
                'What is Premium?',
                'Premium unlocks unlimited habits, advanced AI insights, data export, and 50 daily AI chat messages (vs 3 for free).',
              ),
              _buildFAQItem(
                'How to delete a habit?',
                'Tap on a habit card, then tap edit and choose "Delete Habit". This cannot be undone.',
              ),
              _buildFAQItem(
                'Voice not working?',
                'Check microphone permissions in device settings. Speak clearly with good internet connection.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(answer, style: AppTheme.bodySmall),
        ],
      ),
    );
  }

  /// Toggle text-to-speech functionality
  Future<void> _toggleTts() async {
    setState(() {
      _isTtsEnabled = !_isTtsEnabled;
    });

    await _ttsService.setEnabled(_isTtsEnabled);

    if (mounted) {
      Helpers.showSnackBar(
        context,
        _isTtsEnabled ? 'Text-to-speech enabled' : 'Text-to-speech disabled',
      );
    }
  }

  /// Speak the given message using TTS
  Future<void> _speakMessage(String message) async {
    if (!_isTtsEnabled) return;

    try {
      await _ttsService.speak(message);
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to speak message', isError: true);
      }
    }
  }
}
