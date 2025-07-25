import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/analytics_models.dart';
import '../providers/advanced_analytics_provider.dart';
import '../providers/user_provider.dart';
import '../providers/habit_provider.dart';

class PredictiveInsightsWidget extends StatefulWidget {
  final int maxInsights;
  final bool showTitle;

  const PredictiveInsightsWidget({
    super.key,
    this.maxInsights = 5,
    this.showTitle = true,
  });

  @override
  State<PredictiveInsightsWidget> createState() =>
      _PredictiveInsightsWidgetState();
}

class _PredictiveInsightsWidgetState extends State<PredictiveInsightsWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateInsights();
    });
  }

  void _generateInsights() {
    final analyticsProvider = Provider.of<AdvancedAnalyticsProvider>(
      context,
      listen: false,
    );
    final habitProvider = Provider.of<HabitProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    analyticsProvider.generatePredictiveInsights(
      habits: habitProvider.habits,
      isPremium: userProvider.isPremium,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AdvancedAnalyticsProvider, UserProvider, HabitProvider>(
      builder: (context, analyticsProvider, userProvider, habitProvider, child) {
        if (!userProvider.isPremium) {
          return _buildPremiumUpgradeCard(context);
        }

        if (analyticsProvider.isLoadingInsights) {
          return Card(
            margin: const EdgeInsets.all(16.0),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Analyzing your habits...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }

        if (analyticsProvider.error != null) {
          return Card(
            margin: const EdgeInsets.all(16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to generate insights',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    analyticsProvider.error!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _generateInsights,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final insights = analyticsProvider.predictiveInsights
            .take(widget.maxInsights)
            .toList();

        if (insights.isEmpty) {
          return Card(
            margin: const EdgeInsets.all(16.0),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No insights available yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete more habits to get personalized insights!',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          margin: const EdgeInsets.all(16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showTitle) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.psychology,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI Insights',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
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
                  const SizedBox(height: 16),
                ],
                ...insights.map(
                  (insight) => _buildInsightCard(context, insight),
                ),
                if (insights.length <
                    analyticsProvider.predictiveInsights.length) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => _showAllInsights(
                        context,
                        analyticsProvider.predictiveInsights,
                      ),
                      child: Text(
                        'View all ${analyticsProvider.predictiveInsights.length} insights',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInsightCard(BuildContext context, PredictiveInsight insight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getInsightColor(context, insight.type).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getInsightColor(context, insight.type).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                insight.icon,
                color: _getInsightColor(context, insight.type),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: _getInsightColor(context, insight.type),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildConfidenceBadge(context, insight.confidence),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insight.description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (insight.data['actionRecommendation'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tips_and_updates,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      insight.data['actionRecommendation'],
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfidenceBadge(BuildContext context, double confidence) {
    final percentage = (confidence * 100).toInt();
    Color badgeColor;

    if (confidence >= 0.8) {
      badgeColor = Colors.green;
    } else if (confidence >= 0.6) {
      badgeColor = Colors.orange;
    } else {
      badgeColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$percentage%',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: badgeColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getInsightColor(BuildContext context, String type) {
    switch (type) {
      case 'risk_warning':
        return Colors.red;
      case 'success_prediction':
        return Colors.green;
      case 'trend_positive':
        return Colors.blue;
      case 'trend_negative':
        return Colors.orange;
      case 'behavioral_pattern':
        return Colors.purple;
      case 'performance_excellent':
        return Colors.green;
      case 'performance_needs_attention':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Widget _buildPremiumUpgradeCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.psychology,
              color: Theme.of(context).colorScheme.primary,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'AI-Powered Insights',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Get personalized predictions and recommendations based on your habit patterns.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildFeatureChip(context, Icons.trending_up, 'Trend Analysis'),
                _buildFeatureChip(context, Icons.warning, 'Risk Prediction'),
                _buildFeatureChip(
                  context,
                  Icons.psychology,
                  'Behavioral Patterns',
                ),
                _buildFeatureChip(
                  context,
                  Icons.auto_awesome,
                  'Smart Recommendations',
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // TODO: Navigate to premium upgrade
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Premium upgrade coming soon!')),
                );
              },
              child: const Text('Upgrade to Premium'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  void _showAllInsights(
    BuildContext context,
    List<PredictiveInsight> allInsights,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
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
                'All AI Insights',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: allInsights.length,
                  itemBuilder: (context, index) =>
                      _buildInsightCard(context, allInsights[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
