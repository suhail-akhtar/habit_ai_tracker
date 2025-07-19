import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/voice_provider.dart';
import '../utils/theme.dart';

class VoiceButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isFloating;
  final double size;

  const VoiceButton({
    super.key,
    this.onPressed,
    this.isFloating = true,
    this.size = 56,
  });

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceProvider>(
      builder: (context, voiceProvider, child) {
        // Start/stop animations based on listening state
        if (voiceProvider.isListening) {
          _pulseController.repeat(reverse: true);
          _rippleController.repeat();
        } else {
          _pulseController.stop();
          _rippleController.stop();
        }

        return AnimatedBuilder(
          animation: Listenable.merge([_pulseAnimation, _rippleAnimation]),
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Ripple effect when listening
                if (voiceProvider.isListening)
                  CustomPaint(
                    painter: _RipplePainter(
                      animation: _rippleAnimation,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    size: Size(widget.size * 2, widget.size * 2),
                  ),

                // Main button
                Transform.scale(
                  scale: _pulseAnimation.value,
                  child: widget.isFloating
                      ? _buildFloatingActionButton(context, voiceProvider)
                      : _buildRegularButton(context, voiceProvider),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFloatingActionButton(
      BuildContext context, VoiceProvider voiceProvider) {
    return FloatingActionButton(
      onPressed: voiceProvider.isListening ? null : widget.onPressed,
      backgroundColor: _getButtonColor(context, voiceProvider),
      foregroundColor: _getIconColor(context, voiceProvider),
      elevation: voiceProvider.isListening ? 8 : 4,
      child: AnimatedSwitcher(
        duration: AppTheme.shortAnimation,
        child: Icon(
          _getButtonIcon(voiceProvider),
          key: ValueKey(voiceProvider.isListening),
          size: 28,
        ),
      ),
    );
  }

  Widget _buildRegularButton(
      BuildContext context, VoiceProvider voiceProvider) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: _getButtonColor(context, voiceProvider),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: voiceProvider.isListening ? 12 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: voiceProvider.isListening ? null : widget.onPressed,
          borderRadius: BorderRadius.circular(widget.size / 2),
          child: Center(
            child: AnimatedSwitcher(
              duration: AppTheme.shortAnimation,
              child: Icon(
                _getButtonIcon(voiceProvider),
                key: ValueKey(voiceProvider.isListening),
                color: _getIconColor(context, voiceProvider),
                size: widget.size * 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getButtonColor(BuildContext context, VoiceProvider voiceProvider) {
    if (voiceProvider.error != null) {
      return AppTheme.errorColor;
    } else if (voiceProvider.isListening) {
      return AppTheme.errorColor;
    } else {
      return Theme.of(context).colorScheme.primary;
    }
  }

  Color _getIconColor(BuildContext context, VoiceProvider voiceProvider) {
    return Colors.white;
  }

  IconData _getButtonIcon(VoiceProvider voiceProvider) {
    if (voiceProvider.error != null) {
      return Icons.error;
    } else if (voiceProvider.isListening) {
      return Icons.stop;
    } else {
      return Icons.mic;
    }
  }
}

class _RipplePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _RipplePainter({
    required this.animation,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw multiple ripples
    for (int i = 0; i < 3; i++) {
      final rippleRadius = radius * animation.value * (1 - i * 0.3);
      final opacity = (1 - animation.value) * (1 - i * 0.3);

      if (rippleRadius > 0 && opacity > 0) {
        final paint = Paint()
          ..color = color.withOpacity(opacity * 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

        canvas.drawCircle(center, rippleRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class VoiceToggleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? label;

  const VoiceToggleButton({
    super.key,
    this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceProvider>(
      builder: (context, voiceProvider, child) {
        return ElevatedButton.icon(
          onPressed: voiceProvider.isListening
              ? () => voiceProvider.stopListening()
              : onPressed,
          icon: Icon(
            voiceProvider.isListening ? Icons.stop : Icons.mic,
          ),
          label: Text(
            label ?? (voiceProvider.isListening ? 'Stop' : 'Start Voice'),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: voiceProvider.isListening
                ? AppTheme.errorColor
                : Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
        );
      },
    );
  }
}
