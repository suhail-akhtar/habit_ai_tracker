import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../utils/theme.dart';
import '../utils/constants.dart';

class PremiumDialog extends StatefulWidget {
  final String? feature;
  final VoidCallback? onUpgrade;
  final VoidCallback? onClose;

  const PremiumDialog({super.key, this.feature, this.onUpgrade, this.onClose});

  @override
  State<PremiumDialog> createState() => _PremiumDialogState();
}

class _PremiumDialogState extends State<PremiumDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🔧 FIXED: Get screen dimensions for better positioning
    final screenHeight = MediaQuery.of(context).size.height;
    final safeAreaPadding = MediaQuery.of(context).padding;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          widget.onClose?.call();
        }
      },
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Dialog(
                // 🔧 FIXED: Use Dialog instead of AlertDialog for better control
                backgroundColor: Colors.transparent,
                insetPadding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: safeAreaPadding.top + AppTheme.spacingL,
                ),
                child: Container(
                  // 🔧 FIXED: Constrain height to ensure buttons are accessible
                  constraints: BoxConstraints(
                    maxHeight: screenHeight * 0.8, // Max 80% of screen height
                    minHeight: 400, // Minimum height
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withAlpha(204),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // 🔧 FIXED: Use min size
                    children: [
                      _buildHeader(),
                      Flexible(
                        // 🔧 FIXED: Use Flexible instead of Expanded
                        child: _buildContent(),
                      ),
                      _buildActions(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        mainAxisSize: MainAxisSize.min, // 🔧 FIXED: Minimize header size
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars,
              size: 40, // 🔧 FIXED: Reduced icon size
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'Upgrade to Premium',
            style: AppTheme.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20, // 🔧 FIXED: Slightly smaller font
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          if (widget.feature != null)
            Text(
              'Unlock "${widget.feature}" and more!',
              style: AppTheme.bodyMedium.copyWith(
                color: Colors.white.withAlpha(230),
                fontSize: 14, // 🔧 FIXED: Smaller subtitle
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      padding: const EdgeInsets.all(
        AppTheme.spacingM,
      ), // 🔧 FIXED: Reduced padding
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppTheme.radiusL),
          bottomRight: Radius.circular(AppTheme.radiusL),
        ),
      ),
      child: SingleChildScrollView(
        // 🔧 FIXED: Make content scrollable
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Premium Features', style: AppTheme.titleMedium),
            const SizedBox(
              height: AppTheme.spacingS,
            ), // 🔧 FIXED: Reduced spacing
            ...Constants.premiumFeatures.map(
              (feature) => _buildFeatureItem(feature),
            ),
            const SizedBox(height: AppTheme.spacingS),
            // Show current usage for free users
            Consumer<UserProvider>(
              builder: (context, userProvider, child) {
                if (!userProvider.isPremium) {
                  return Container(
                    padding: const EdgeInsets.all(
                      AppTheme.spacingS,
                    ), // 🔧 FIXED: Reduced padding
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withAlpha(26),
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      border: Border.all(
                        color: AppTheme.warningColor.withAlpha(77),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info,
                          color: AppTheme.warningColor,
                          size: 16, // 🔧 FIXED: Smaller icon
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          child: Text(
                            'You have ${userProvider.habitCount}/${Constants.freeHabitLimit} habits. Upgrade for unlimited habits!',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.warningColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12, // 🔧 FIXED: Smaller text
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: AppTheme.spacingS),
            Container(
              padding: const EdgeInsets.all(
                AppTheme.spacingS,
              ), // 🔧 FIXED: Reduced padding
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(26),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: Theme.of(context).colorScheme.primary,
                    size: 16, // 🔧 FIXED: Smaller icon
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Text(
                      'Limited time offer: 30% off first month!',
                      style: AppTheme.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12, // 🔧 FIXED: Smaller text
                      ),
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

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppTheme.spacingXS,
      ), // 🔧 FIXED: Reduced spacing
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppTheme.successColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              size: 12, // 🔧 FIXED: Smaller check icon
              color: Colors.white,
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              feature,
              style: AppTheme.bodySmall.copyWith(
                // 🔧 FIXED: Smaller text
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppTheme.radiusL),
          bottomRight: Radius.circular(AppTheme.radiusL),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // 🔧 FIXED: Minimize action area
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _handleUpgrade(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacingM,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                minimumSize: const Size(
                  double.infinity,
                  48,
                ), // 🔧 FIXED: Ensure tappable size
              ),
              child: Text(
                'Upgrade Now - \$9.99/month',
                style: AppTheme.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16, // 🔧 FIXED: Consistent button text size
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onClose?.call();
                  },
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      double.infinity,
                      44,
                    ), // 🔧 FIXED: Ensure tappable size
                  ),
                  child: const Text('Maybe Later'),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: TextButton(
                  onPressed: () => _showPricingOptions(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      double.infinity,
                      44,
                    ), // 🔧 FIXED: Ensure tappable size
                  ),
                  child: const Text('View All Plans'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleUpgrade() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Simulate upgrade process
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      // Update user provider
      await context.read<UserProvider>().upgradeToPremium();

      if (!mounted) return;

      // Close premium dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Welcome to Premium! 🎉'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Call onUpgrade callback if provided
      widget.onUpgrade?.call();
    } catch (e) {
      // Close loading dialog if open
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upgrade failed: $e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPricingOptions() {
    showDialog(
      context: context,
      builder: (context) => const PricingOptionsDialog(),
    );
  }
}

class PricingOptionsDialog extends StatelessWidget {
  const PricingOptionsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose Your Plan'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPricingOption(
            context,
            'Monthly',
            '\$9.99',
            'per month',
            'Most flexible',
            false,
          ),
          const SizedBox(height: AppTheme.spacingM),
          _buildPricingOption(
            context,
            'Yearly',
            '\$99.99',
            'per year',
            'Save 17%',
            true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildPricingOption(
    BuildContext context,
    String title,
    String price,
    String period,
    String badge,
    bool isRecommended,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        border: Border.all(
          color: isRecommended
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline.withAlpha(77),
          width: isRecommended ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTheme.titleMedium),
              if (isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS,
                    vertical: AppTheme.spacingXS,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Text(
                    'RECOMMENDED',
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXS),
          RichText(
            text: TextSpan(
              text: price,
              style: AppTheme.headlineSmall.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
              children: [
                TextSpan(
                  text: ' $period',
                  style: AppTheme.bodyMedium.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(179),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            badge,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.successColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper function with optional close callback
void showPremiumDialog(
  BuildContext context, {
  String? feature,
  VoidCallback? onClose,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => PremiumDialog(
      feature: feature,
      onClose: onClose,
      onUpgrade: () {
        // Handle post-upgrade actions
      },
    ),
  );
}
