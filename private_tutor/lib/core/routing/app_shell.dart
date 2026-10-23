import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: navigationShell,
    bottomNavigationBar: navigationShell.currentIndex == 2
        ? null
        : NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primary.withValues(alpha: 0.1),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline_rounded),
                selectedIcon: Icon(Icons.people_rounded),
                label: 'Students',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_rounded),
                label: 'Add',
              ),
              NavigationDestination(
                icon: Icon(Icons.credit_card_outlined),
                selectedIcon: Icon(Icons.credit_card_rounded),
                label: 'Dues',
              ),
            ],
          ),
  );
}
