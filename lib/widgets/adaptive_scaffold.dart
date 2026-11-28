import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_shapes.dart';
import '../theme/app_spacing.dart';
import 'liquid_glass_container.dart';
import 'liquid_glass_nav_bar.dart';

class AdaptiveDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const AdaptiveDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class AdaptiveScaffold extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onNavigationChanged;
  final List<AdaptiveDestination> destinations;
  final List<Widget> screens;

  const AdaptiveScaffold({
    super.key,
    required this.currentIndex,
    required this.onNavigationChanged,
    required this.destinations,
    required this.screens,
  });

  void _select(int index) {
    if (index == currentIndex) return;
    HapticFeedback.selectionClick();
    onNavigationChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 640;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isWide) {
      // Tablet / landscape floating Liquid Glass navigation rail.
      return Scaffold(
        body: LiquidGlassBackground(
          child: Row(
            children: [
              SafeArea(
                right: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                  ),
                  child: LiquidGlassContainer(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    borderRadius: AppShapes.extraLarge,
                    child: NavigationRail(
                      backgroundColor: Colors.transparent,
                      selectedIndex: currentIndex,
                      onDestinationSelected: _select,
                      labelType: NavigationRailLabelType.all,
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Icon(
                          Icons.downloading_rounded,
                          color: colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      destinations: destinations.map((d) {
                        return NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: currentIndex,
                  children: List.generate(screens.length, (i) {
                    return TickerMode(
                      enabled: i == currentIndex,
                      child: screens[i],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Phone dock: floating iOS Liquid Glass pill with a spring-driven,
    // scrubbable refractive lens indicator.
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: currentIndex,
        children: List.generate(screens.length, (i) {
          return TickerMode(
            enabled: i == currentIndex,
            child: screens[i],
          );
        }),
      ),
      bottomNavigationBar: LiquidGlassNavBar(
        currentIndex: currentIndex,
        onDestinationSelected: _select,
        destinations: destinations
            .map(
              (d) => LiquidGlassNavDestination(
                icon: d.icon,
                selectedIcon: d.selectedIcon,
                label: d.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
