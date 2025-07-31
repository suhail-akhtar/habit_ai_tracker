import 'package:flutter/material.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  final VoidCallback onSplashComplete;

  const SplashScreen({super.key, required this.onSplashComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    _startSplashSequence();
  }

  void _startSplashSequence() async {
    await _animationController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    widget.onSplashComplete();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6366f1), // Indigo
              Color(0xFF8b5cf6), // Purple
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Responsive sizing based on screen size
              final isSmallScreen = constraints.maxHeight < 600;
              final iconSize = isSmallScreen ? 80.0 : 120.0;
              final titleSize = isSmallScreen ? 24.0 : 32.0;
              final subtitleSize = isSmallScreen ? 14.0 : 16.0;
              final verticalSpacing = isSmallScreen ? 20.0 : 40.0;

              return Center(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // App Icon
                            _buildAppIcon(iconSize),
                            SizedBox(height: verticalSpacing),

                            // App Name
                            Text(
                              'AI Habit Tracker',
                              style: TextStyle(
                                fontSize: titleSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    blurRadius: 10,
                                    color: Colors.black26,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: isSmallScreen ? 8 : 12),

                            // Tagline
                            Text(
                              'Build Better Habits with AI',
                              style: TextStyle(
                                fontSize: subtitleSize,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withOpacity(0.9),
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: verticalSpacing + 20),

                            // Loading Animation
                            _buildLoadingAnimation(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAppIcon([double size = 120]) {
    final borderRadius = size * 0.233; // Maintain proportion
    final iconSize = size * 0.5; // Main icon is 50% of container
    final smallIconSize = size * 0.15; // Small icons are 15% of container
    final smallIconContainerSize = size * 0.167; // Small icon containers

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: size * 0.167,
            offset: Offset(0, size * 0.067),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Main checkmark
          Center(
            child: Icon(
              Icons.check_rounded,
              size: iconSize,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 8,
                  color: Colors.black26,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),

          // AI brain icon (top-right)
          Positioned(
            top: size * 0.125,
            right: size * 0.125,
            child: Container(
              width: smallIconContainerSize,
              height: smallIconContainerSize,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(smallIconContainerSize / 2),
              ),
              child: Icon(
                Icons.psychology,
                size: smallIconSize,
                color: Color(0xFF6366f1),
              ),
            ),
          ),

          // Mic icon (bottom-left)
          Positioned(
            bottom: size * 0.125,
            left: size * 0.125,
            child: Container(
              width: smallIconContainerSize * 0.9,
              height: smallIconContainerSize * 0.9,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(
                  smallIconContainerSize * 0.45,
                ),
              ),
              child: Icon(
                Icons.mic,
                size: smallIconSize * 0.8,
                color: Color(0xFF6366f1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingAnimation() {
    return SizedBox(
      width: 60,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLoadingDot(0),
          _buildLoadingDot(1),
          _buildLoadingDot(2),
        ],
      ),
    );
  }

  Widget _buildLoadingDot(int index) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delay = index * 0.2;
        final progress = (_animationController.value - delay).clamp(0.0, 1.0);
        final opacity = (math.sin(progress * math.pi * 3) * 0.4 + 0.6).clamp(
          0.3,
          1.0,
        );

        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }
}
