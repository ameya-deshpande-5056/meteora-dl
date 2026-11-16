import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_shapes.dart';
import '../theme/app_spacing.dart';

/// Segment gap between connected rows in a settings group (matches Morphe's SegmentGap: 2dp).
const double kSegmentGap = 2.0;

/// Groups related settings or options into a cohesive Material 3 Expressive block,
/// modeled directly on Morphe App's `SettingsGroup` and `ConnectedShapes.Card.inColumn`.
///
/// Members of the group connect seamlessly: top item has rounded top corners and nearly-square
/// bottom corners, middle items have nearly-square corners, and bottom item has rounded
/// bottom corners.
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double segmentGap;

  const SettingsGroup({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
    this.segmentGap = kSegmentGap,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final count = children.length;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < count; i++) ...[
            if (i > 0 && segmentGap > 0) SizedBox(height: segmentGap),
            _ConnectedItemScope(
              index: i,
              count: count,
              child: children[i],
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectedItemScope extends InheritedWidget {
  final int index;
  final int count;

  const _ConnectedItemScope({
    required this.index,
    required this.count,
    required super.child,
  });

  static _ConnectedItemScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ConnectedItemScope>();
  }

  @override
  bool updateShouldNotify(_ConnectedItemScope oldWidget) {
    return index != oldWidget.index || count != oldWidget.count;
  }
}

/// A Material 3 Expressive surface card that respects its position inside a [SettingsGroup].
class ExpressiveSurfaceCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final RoundedRectangleBorder? shape;
  final bool enabled;

  const ExpressiveSurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.shape,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAmoled = theme.scaffoldBackgroundColor == Colors.black;

    final groupScope = _ConnectedItemScope.of(context);
    final effectiveShape = shape ??
        (groupScope != null
            ? ConnectedShapes.card.inColumn(groupScope.index, groupScope.count)
            : AppShapes.sectionCardShape);

    final effectiveColor = color ??
        (isAmoled
            ? const Color(0xD90E0E0E)
            : colorScheme.surfaceContainerLow.withAlpha(215));

    final borderSide = BorderSide(
      color: isAmoled
          ? Colors.white.withAlpha(24)
          : colorScheme.outlineVariant.withAlpha(80),
      width: 0.8,
    );

    final shapedBorder = effectiveShape.copyWith(side: borderSide);

    return Material(
      color: effectiveColor,
      shape: shapedBorder,
      clipBehavior: Clip.antiAlias,
      child: onTap != null
          ? InkWell(
              onTap: enabled
                  ? () {
                      HapticFeedback.selectionClick();
                      onTap!();
                    }
                  : null,
              customBorder: shapedBorder,
              child: child,
            )
          : child,
    );
  }
}

/// A settings item tile with expressive iconography, typography, and controls,
/// conforming to Morphe App's `SettingsItem` / `SettingsSwitchItem`.
class SettingsCardTile extends StatelessWidget {
  final Widget? leading;
  final IconData? icon;
  final Color? iconColor;
  final Color? iconContainerColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final EdgeInsetsGeometry contentPadding;

  const SettingsCardTile({
    super.key,
    this.leading,
    this.icon,
    this.iconColor,
    this.iconContainerColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget? effectiveLeading = leading;
    if (effectiveLeading == null && icon != null) {
      effectiveLeading = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconContainerColor ?? colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(AppShapes.medium),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 22,
          color: iconColor ?? colorScheme.onSecondaryContainer,
        ),
      );
    }

    return ExpressiveSurfaceCard(
      onTap: onTap,
      enabled: enabled,
      child: Padding(
        padding: contentPadding,
        child: Row(
          children: [
            if (effectiveLeading != null) ...[
              effectiveLeading,
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: enabled ? null : colorScheme.onSurface.withAlpha(120),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Connected button group row modeled after Morphe App's `ButtonGroupRow`
/// and `ConnectedShapes.Pill.inRow`.
class ConnectedButtonGroup<T> extends StatelessWidget {
  final List<T> items;
  final T selectedItem;
  final ValueChanged<T> onSelected;
  final Widget Function(BuildContext context, T item, bool isSelected) labelBuilder;
  final bool Function(T item)? isItemEnabled;
  final double height;

  const ConnectedButtonGroup({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.onSelected,
    required this.labelBuilder,
    this.isItemEnabled,
    this.height = 42.0,
  });

  @override
  Widget build(BuildContext context) {
    final count = items.length;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: kSegmentGap),
            Expanded(
              child: Builder(
                builder: (context) {
                  final item = items[i];
                  final isSelected = item == selectedItem;
                  final enabled = isItemEnabled?.call(item) ?? true;
                  final shape = ConnectedShapes.pill.inRow(i, count);

                  final activeColor = colorScheme.primaryContainer;
                  final activeTextColor = colorScheme.onPrimaryContainer;
                  final inactiveColor = colorScheme.surfaceContainerHigh.withAlpha(180);

                  final borderSide = BorderSide(
                    color: isSelected
                        ? colorScheme.primary.withAlpha(90)
                        : colorScheme.outlineVariant.withAlpha(60),
                    width: 0.8,
                  );

                  return Material(
                    color: isSelected ? activeColor : inactiveColor,
                    shape: shape.copyWith(side: borderSide),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: enabled
                          ? () {
                              if (!isSelected) {
                                HapticFeedback.selectionClick();
                                onSelected(item);
                              }
                            }
                          : null,
                      customBorder: shape,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: (theme.textTheme.labelMedium ?? const TextStyle()).copyWith(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: !enabled
                                ? colorScheme.onSurface.withAlpha(90)
                                : (isSelected ? activeTextColor : colorScheme.onSurface),
                          ),
                          child: labelBuilder(context, item, isSelected),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
