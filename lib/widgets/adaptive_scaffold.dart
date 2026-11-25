import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_spacing.dart';
import 'liquid_glass_container.dart';

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

    // Phone dock: floating glass pill with a sliding glass indicator ribbon.
    final reduceMotion = MediaQuery.of(context).disableAnimations;
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: LiquidGlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 6),
            borderRadius: AppShapes.full,
            blurSigma: 14,
            enableBlur: true,
            style: LiquidGlassStyle.regular,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final count = destinations.length;
                final tabWidth = constraints.maxWidth / count;
                final indicatorLeft = currentIndex * tabWidth;
                final duration = reduceMotion ? Duration.zero : AppMotion.medium;
                final curve = AppMotion.spring;

                return SizedBox(
                  height: 62,
                  child: Stack(
                    children: [
                      // Sliding glass indicator (no blur during motion: static tint only).
                      AnimatedPositioned(
                        duration: duration,
                        curve: curve,
                        left: indicatorLeft,
                        top: 0,
                        bottom: 0,
                        width: tabWidth,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: AnimatedContainer(
                            duration: duration,
                            curve: curve,
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withAlpha(
                                theme.brightness == Brightness.dark ? 165 : 205,
                              ),
                              borderRadius: BorderRadius.circular(AppShapes.full),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: List.generate(destinations.length, (index) {
                          final dest = destinations[index];
                          final selected = index == currentIndex;

                          return Expanded(
                            child: Semantics(
                              button: true,
                              selected: selected,
                              label: dest.label,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(AppShapes.full),
                                onTap: () => _select(index),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 7),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedScale(
                                        scale: selected ? 1.12 : 1.0,
                                        duration: duration,
                                        curve: curve,
                                        child: Icon(
                                          selected ? dest.selectedIcon : dest.icon,
                                          size: 22,
                                          color: selected
                                              ? colorScheme.onPrimaryContainer
                                              : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        dest.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: selected
                                              ? colorScheme.onPrimaryContainer
                                              : colorScheme.onSurfaceVariant,
                                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
