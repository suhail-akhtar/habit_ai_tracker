import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/voice_provider.dart';
import '../utils/theme.dart';

class VoiceButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isFloating;
  final double size;
  final bool showAnimation;

  const VoiceButton({
    super.key,
    this.onPressed,
    this.isFloating = true,
    this.size = 56,
    this.showAnimation = true,
  });

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late AnimationController _scaleController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceProvider>(
      builder: (context, voiceProvider, child) {
        _updateAnimations(voiceProvider);

        return AnimatedBuilder(
          animation: Listenable.merge([
            _pulseAnimation,
            _rippleAnimation,
            _scaleAnimation,
          ]),
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Ripple effect when listening
                  if (voiceProvider.isListening && widget.showAnimation)
                    CustomPaint(
                      painter: _RipplePainter(
                        animation: _rippleAnimation,
                        color: _getButtonColor(context, voiceProvider),
                      ),
                      size: Size(widget.size * 2.5, widget.size * 2.5),
                    ),

                  // Main button
                  Transform.scale(
                    scale: _pulseAnimation.value,
                    child: widget.isFloating
                        ? _buildFloatingActionButton(context, voiceProvider)
                        : _buildRegularButton(context, voiceProvider),
                  ),

                  // Lottie animation overlay
                  if (voiceProvider.isListening && widget.showAnimation)
                    _buildLottieOverlay(voiceProvider),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFloatingActionButton(
    BuildContext context,
    VoiceProvider voiceProvider,
  ) {
    return FloatingActionButton(
      onPressed: _isButtonEnabled(voiceProvider)
          ? () => _handleButtonPress(voiceProvider)
          : null,
      backgroundColor: _getButtonColor(context, voiceProvider),
      foregroundColor: _getIconColor(context, voiceProvider),
      elevation: voiceProvider.isListening ? 8 : 4,
      child: AnimatedSwitcher(
        duration: AppTheme.shortAnimation,
        child: _buildButtonIcon(voiceProvider),
      ),
    );
  }

  Widget _buildRegularButton(
    BuildContext context,
    VoiceProvider voiceProvider,
  ) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: _getButtonColor(context, voiceProvider),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _getButtonColor(context, voiceProvider).withOpacity(0.3),
            blurRadius: voiceProvider.isListening ? 12 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isButtonEnabled(voiceProvider)
              ? () => _handleButtonPress(voiceProvider)
              : null,
          onTapDown: (_) => _scaleController.forward(),
          onTapUp: (_) => _scaleController.reverse(),
          onTapCancel: () => _scaleController.reverse(),
          borderRadius: BorderRadius.circular(widget.size / 2),
          child: Center(
            child: AnimatedSwitcher(
              duration: AppTheme.shortAnimation,
              child: _buildButtonIcon(voiceProvider),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonIcon(VoiceProvider voiceProvider) {
    IconData iconData;
    String key;

    if (voiceProvider.error != null) {
      iconData = Icons.error_outline;
      key = 'error';
    } else if (voiceProvider.isProcessing) {
      iconData = Icons.psychology;
      key = 'processing';
    } else if (voiceProvider.isListening) {
      iconData = Icons.stop;
      key = 'stop';
    } else {
      iconData = Icons.mic;
      key = 'mic';
    }

    return Icon(
      iconData,
      key: ValueKey(key),
      color: _getIconColor(context, voiceProvider),
      size: widget.isFloating ? 28 : widget.size * 0.4,
    );
  }

  Widget _buildLottieOverlay(VoiceProvider voiceProvider) {
    return SizedBox(width: widget.size * 1.5, height: widget.size * 1.5);
  }

  void _updateAnimations(VoiceProvider voiceProvider) {
    if (voiceProvider.isListening) {
      _pulseController.repeat(reverse: true);
      _rippleController.repeat();
    } else {
      _pulseController.stop();
      _rippleController.stop();
    }
  }

  void _handleButtonPress(VoiceProvider voiceProvider) async {
    if (voiceProvider.isListening) {
      await voiceProvider.stopListening();
    } else {
      if (widget.onPressed != null) {
        widget.onPressed!();
      } else {
        await voiceProvider.startListening();
      }
    }
  }

  bool _isButtonEnabled(VoiceProvider voiceProvider) {
    return voiceProvider.isInitialized && !voiceProvider.isProcessing;
  }

  Color _getButtonColor(BuildContext context, VoiceProvider voiceProvider) {
    if (voiceProvider.error != null) {
      return AppTheme.errorColor;
    } else if (voiceProvider.isListening) {
      return AppTheme
          .successColor; // 🔧 CHANGED: Green when listening (was errorColor/red)
    } else if (voiceProvider.isProcessing) {
      return AppTheme.infoColor;
    } else {
      return Theme.of(context).colorScheme.primary;
    }
  }

  Color _getIconColor(BuildContext context, VoiceProvider voiceProvider) {
    return Colors.white;
  }
}

class _RipplePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _RipplePainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw multiple ripples with different phases
    for (int i = 0; i < 3; i++) {
      final phase = (i * 0.3);
      final rippleRadius = radius * ((animation.value + phase) % 1.0);
      final opacity = (1 - ((animation.value + phase) % 1.0)) * 0.4;

      if (rippleRadius > 0 && opacity > 0) {
        final paint = Paint()
          ..color = color.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

        canvas.drawCircle(center, rippleRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
