import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 640;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isWide) {
      // Tablet / Landscape floating Liquid Glass NavigationRail
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
                      onDestinationSelected: onNavigationChanged,
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
                  children: screens,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Mobile Portrait Floating Liquid Glass Navigation Bar
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: currentIndex,
        children: screens,
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
            borderRadius: AppShapes.extraLarge,
            blurSigma: 20,
            child: Row(
              children: List.generate(destinations.length, (index) {
                final dest = destinations[index];
                final selected = index == currentIndex;

                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: dest.label,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppShapes.extraLarge),
                      onTap: () => onNavigationChanged(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: selected
                              ? colorScheme.primaryContainer.withAlpha(
                                  theme.brightness == Brightness.dark ? 150 : 190,
                                )
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppShapes.extraLarge),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              selected ? dest.selectedIcon : dest.icon,
                              size: 22,
                              color: selected
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurfaceVariant,
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
          ),
        ),
      ),
    );
  }
}
