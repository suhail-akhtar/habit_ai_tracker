import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onboarding_screen.dart';
import '../main.dart' show MainNavigationScreen;

class BootstrapScreen extends StatelessWidget {
  const BootstrapScreen({super.key});

  static const _prefOnboardingComplete = 'onboarding_complete';

  Future<bool> _isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefOnboardingComplete) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isOnboardingComplete(),
      builder: (context, snapshot) {
        final done = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done || done == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!done) {
          return const OnboardingScreen();
        }

        return const MainNavigationScreen();
      },
    );
  }
}
