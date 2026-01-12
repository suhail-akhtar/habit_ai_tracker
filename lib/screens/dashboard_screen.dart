import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/habit_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/habit_card.dart';
import '../widgets/dashboard/bento_grid.dart'; // Import BentoGrid
import '../utils/theme.dart';
import '../utils/app_log.dart';
import 'habit_setup_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initial load
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<HabitProvider>().loadHabits();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppLog.d('📱 App resumed - refreshing data');
      context.read<HabitProvider>().loadHabits();
      context.read<UserProvider>().loadUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 600;
    // Dynamic padding to center content on tablets/desktop while maintaining mobile margins
    final horizontalPadding = isWide
        ? (screenWidth - 600) / 2
        : AppTheme.spacingM;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          final habitProvider = context.read<HabitProvider>();
          final userProvider = context.read<UserProvider>();

          await habitProvider.loadHabits();
          await userProvider.loadUserData();
        },
        child: Consumer2<HabitProvider, UserProvider>(
          builder: (context, habitProvider, userProvider, child) {
            if (habitProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(context, userProvider),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  sliver: SliverToBoxAdapter(
                    child: Padding(
                      // Inner padding is 0 because we handle it in SliverPadding now
                      padding: const EdgeInsets.all(0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppTheme.spacingM),
                          _buildGreeting(context),
                          const SizedBox(height: AppTheme.spacingL),
                          const BentoGrid(), // Use new component
                          const SizedBox(height: AppTheme.spacingL),
                          _buildSectionHeader(
                            context,
                            'Your Habits',
                            userProvider,
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: AppTheme.spacingS,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final habit = habitProvider.todayHabits[index];
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppTheme.spacingS,
                        ),
                        child: HabitCard(habit: habit),
                      );
                    }, childCount: habitProvider.todayHabits.length),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ), // Bottom padding for FAB
              ],
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _handleAddNewHabit(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, UserProvider userProvider) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: false,
      backgroundColor: Colors.transparent,

      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {}, // TODO: Implement notifications screen
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.pushNamed(context, '/settings'),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 17) greeting = 'Good Afternoon';
    if (hour >= 17) greeting = 'Good Evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greeting, style: AppTheme.headlineLarge.copyWith(height: 1.0)),
        const SizedBox(height: 4),
        Text(
          'Ready to crush your goals today?',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w400,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // Removed old _buildBentoStats and _buildBentoCard

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    UserProvider userProvider,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTheme.headlineSmall),
        IconButton(
          onPressed: () => _handleAddNewHabit(context),
          icon: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.add,
              size: 20,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  void _handleAddNewHabit(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const HabitSetupScreen()));
  }
}
