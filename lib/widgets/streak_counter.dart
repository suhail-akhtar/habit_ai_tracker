import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';

class StreakCounter extends StatefulWidget {
  final int streak;
  final bool showAnimation;
  final VoidCallback? onTap;

  const StreakCounter({
    super.key,
    required this.streak,
    this.showAnimation = true,
    this.onTap,
  });

  @override
  State<StreakCounter> createState() => _StreakCounterState();
}

class _StreakCounterState extends State<StreakCounter>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _countController;
  late Animation<double> _pulseAnimation;
  late Animation<int> _countAnimation;

  int _previousStreak = 0;

  @override
  void initState() {
    super.initState();
    _previousStreak = widget.streak;

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _countController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.elasticOut),
    );

    _countAnimation = IntTween(begin: 0, end: widget.streak).animate(
      CurvedAnimation(parent: _countController, curve: Curves.easeOutCubic),
    );

    if (widget.showAnimation) {
      _countController.forward();
    }
  }

  @override
  void didUpdateWidget(StreakCounter oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.streak != oldWidget.streak) {
      if (widget.streak > _previousStreak) {
        // Streak increased - show celebration animation
        _pulseController.forward().then((_) {
          _pulseController.reverse();
        });
      }

      // Update count animation
      _countAnimation = IntTween(begin: _previousStreak, end: widget.streak)
          .animate(
            CurvedAnimation(
              parent: _countController,
              curve: Curves.easeOutCubic,
            ),
          );

      _countController.reset();
      _countController.forward();
      _previousStreak = widget.streak;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _countAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                gradient: _buildGradient(),
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                boxShadow: [
                  BoxShadow(
                    color: Helpers.getStreakColor(widget.streak).withAlpha(77),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Text(
                        widget.showAnimation
                            ? _countAnimation.value.toString()
                            : widget.streak.toString(),
                        style: AppTheme.headlineLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    widget.streak == 1 ? 'Day Streak' : 'Days Streak',
                    style: AppTheme.titleMedium.copyWith(
                      color: Colors.white.withAlpha(230),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    _getStreakMessage(),
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.white.withAlpha(204),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  LinearGradient _buildGradient() {
    final color = Helpers.getStreakColor(widget.streak);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [color, color.withAlpha(204)],
    );
  }

  String _getStreakMessage() {
    if (widget.streak == 0) {
      return 'Start your streak today!';
    } else if (widget.streak < 7) {
      return 'Keep it up! You\'re building momentum.';
    } else if (widget.streak < 30) {
      return 'Amazing! You\'re on a roll!';
    } else if (widget.streak < 100) {
      return 'Incredible dedication! You\'re a habit master!';
    } else {
      return 'Legendary! You\'re an inspiration!';
    }
  }
}

class MiniStreakCounter extends StatelessWidget {
  final int streak;
  final Color? color;

  const MiniStreakCounter({super.key, required this.streak, this.color});

  @override
  Widget build(BuildContext context) {
    final streakColor = color ?? Helpers.getStreakColor(streak);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: streakColor.withAlpha(26),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: streakColor.withAlpha(77), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, size: 12, color: streakColor),
          const SizedBox(width: AppTheme.spacingXS),
          Text(
            streak.toString(),
            style: AppTheme.bodySmall.copyWith(
              color: streakColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
