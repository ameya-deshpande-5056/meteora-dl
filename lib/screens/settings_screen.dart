import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_engine/media_engine.dart';

import '../services/app_update_service.dart';
import '../services/native_bridge.dart';
import '../state/download_state.dart';
import '../state/theme_manager.dart';
import '../theme/app_shapes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass_container.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isCheckingUpdates = false;
  String? _updateStatusMessage;
  bool _isRefreshingEjs = false;
  String? _ejsRefreshStatusMessage;
  String? _engineVersion;
  JsRuntimeInfo _jsRuntime = JsRuntimeInfo.unavailable();

  bool _isCheckingAppUpdate = false;
  String? _appUpdateMessage;
  AppReleaseInfo? _availableAppUpdate;

  DeviceCapabilities _deviceCapabilities =
      DeviceCapabilities.standardAndroidArm64();

  @override
  void initState() {
    super.initState();
    _loadEngineState();
    DownloadStateManager.instance.refreshDownloadLocation();
  }

  Future<void> _pickDownloadDirectory() async {
    final picked = await DownloadStateManager.instance.pickDownloadLocation();
    if (picked != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download location set to ${picked.displayPath}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _resetDownloadLocation() async {
    final reset = await DownloadStateManager.instance.resetDownloadLocation();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download location reset to ${reset.displayPath}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadEngineState() async {
    final caps = await NativeBridge.getDeviceCapabilities();
    final version = await NativeBridge.getEngineVersion();
    final jsRuntime = await NativeBridge.getJsRuntimeStatus();
    if (!mounted) return;
    setState(() {
      _deviceCapabilities = caps;
      _jsRuntime = jsRuntime;
      if (version != null && version.isNotEmpty) {
        _engineVersion = version;
      }
    });
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isCheckingUpdates = true;
      _updateStatusMessage = 'Checking the embedded yt-dlp update channel...';
    });

    try {
      final status = await NativeBridge.updateEngine();
      final version = await NativeBridge.getEngineVersion();
      if (!mounted) return;
      setState(() {
        _isCheckingUpdates = false;
        if (version != null && version.isNotEmpty) {
          _engineVersion = version;
        }
        if (status == 'DONE') {
          _updateStatusMessage =
              'yt-dlp updated to ${_engineVersion ?? 'the latest release'}.';
        } else if (status == null) {
          _updateStatusMessage =
              'The update check did not return a status. Try again when online.';
        } else {
          _updateStatusMessage =
              'yt-dlp is already current (${_engineVersion ?? 'bundled version'}).';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCheckingUpdates = false;
        _updateStatusMessage =
            'Update failed: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  Future<void> _refreshEjsComponents() async {
    setState(() {
      _isRefreshingEjs = true;
      _ejsRefreshStatusMessage = 'Clearing the cached EJS component…';
    });
    try {
      final refreshed = await NativeBridge.refreshEjsComponents();
      if (!mounted) return;
      setState(() {
        _isRefreshingEjs = false;
        _ejsRefreshStatusMessage = refreshed
            ? 'EJS will be refreshed from the official channel on the next extraction or download.'
            : 'Could not refresh EJS. Try again after active downloads finish.';
      });
      if (refreshed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'EJS component cache cleared — it will refresh on the next extraction or download.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRefreshingEjs = false;
        _ejsRefreshStatusMessage =
            'EJS refresh failed: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  Future<void> _checkAppUpdate() async {
    setState(() {
      _isCheckingAppUpdate = true;
      _appUpdateMessage = 'Checking GitHub for updates…';
      _availableAppUpdate = null;
    });

    try {
      final release = await AppUpdateService.checkForUpdate();
      if (!mounted) return;

      if (release == null) {
        setState(() {
          _isCheckingAppUpdate = false;
          _appUpdateMessage =
              'Could not reach GitHub. Please check your network connection.';
        });
        return;
      }

      final isNewer = AppUpdateService.isNewerVersion(release.tagName);
      setState(() {
        _isCheckingAppUpdate = false;
        if (isNewer) {
          _availableAppUpdate = release;
          _appUpdateMessage =
              'Update available: ${release.tagName} (${release.name})';
        } else {
          _availableAppUpdate = null;
          _appUpdateMessage =
              'Meteora is up to date (v${AppUpdateService.currentVersion}).';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCheckingAppUpdate = false;
        _appUpdateMessage = 'Check failed: $e';
      });
    }
  }

  void _showAboutAppDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: LiquidGlassContainer(
            padding: const EdgeInsets.all(AppSpacing.xl),
            borderRadius: AppShapes.extraLarge,
            enableBlur: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.tertiary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppShapes.large),
                      ),
                      child: Icon(
                        Icons.cloud_download_rounded,
                        color: colorScheme.onPrimary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Meteora',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Version ${AppUpdateService.currentVersion} (Build ${AppUpdateService.currentBuildNumber})',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'A lightweight, high-performance Android media downloader built clean-room style.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: AppSpacing.cardPadding,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withAlpha(120),
                    borderRadius: BorderRadius.circular(AppShapes.medium),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        'Engine',
                        'yt-dlp (embedded Android Python)',
                        theme,
                      ),
                      const Divider(height: AppSpacing.md),
                      _buildInfoRow(
                        'JS Solver',
                        'QuickJS-NG (libqjs.so + EJS)',
                        theme,
                      ),
                      const Divider(height: AppSpacing.md),
                      _buildInfoRow(
                        'Muxer',
                        'FFmpeg & FFprobe (stream copy)',
                        theme,
                      ),
                      const Divider(height: AppSpacing.md),
                      _buildInfoRow(
                        'Database',
                        'SQLite (sqlite3 ACID storage)',
                        theme,
                      ),
                      const Divider(height: AppSpacing.md),
                      _buildInfoRow(
                        'UI Presentation',
                        'Material 3 Expressive & Liquid Glass',
                        theme,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        showLicensePage(
                          context: context,
                          applicationName: 'Meteora',
                          applicationVersion:
                              'v${AppUpdateService.currentVersion}',
                        );
                      },
                      child: const Text('Licenses'),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  IconData _themeModeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return Icons.brightness_auto_outlined;
      case AppThemeMode.light:
        return Icons.light_mode_outlined;
      case AppThemeMode.dark:
        return Icons.dark_mode_outlined;
      case AppThemeMode.amoled:
        return Icons.contrast_rounded;
    }
  }

  void _showThemePickerDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final currentMode = ThemeManager.instance.currentMode;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: LiquidGlassContainer(
            padding: const EdgeInsets.only(
              top: AppSpacing.xl,
              bottom: AppSpacing.md,
            ),
            borderRadius: AppShapes.extraLarge,
            enableBlur: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: Text(
                    'Choose theme',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ...AppThemeMode.values.map((mode) {
                  final isSelected = currentMode == mode;
                  return InkWell(
                    onTap: () {
                      ThemeManager.instance.setThemeMode(mode);
                      Navigator.pop(dialogContext);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          _ThemePreviewSwatch(mode: mode),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mode.label,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                                Text(
                                  mode.description,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: const LiquidGlassAppBar(title: Text('Settings')),
      body: LiquidGlassBackground(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            MediaQuery.paddingOf(context).bottom + 108,
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeader('Appearance', context),
                const SizedBox(height: AppSpacing.sm),
                ListenableBuilder(
                  listenable: ThemeManager.instance,
                  builder: (context, _) {
                    final currentMode = ThemeManager.instance.currentMode;
                    return LiquidGlassContainer(
                      padding: EdgeInsets.zero,
                      borderRadius: AppShapes.large,
                      child: Material(
                        type: MaterialType.transparency,
                        borderRadius: BorderRadius.circular(AppShapes.large),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppShapes.large),
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(
                                AppShapes.medium,
                              ),
                            ),
                            child: Icon(
                              _themeModeIcon(currentMode),
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          title: const Text('Theme'),
                          subtitle: Text(currentMode.label),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _showThemePickerDialog(context),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSectionHeader('Storage', context),
                const SizedBox(height: AppSpacing.sm),
                ListenableBuilder(
                  listenable: DownloadStateManager.instance,
                  builder: (context, _) {
                    final location =
                        DownloadStateManager.instance.downloadLocation;
                    return LiquidGlassContainer(
                      padding: EdgeInsets.zero,
                      borderRadius: AppShapes.large,
                      child: Material(
                        type: MaterialType.transparency,
                        borderRadius: BorderRadius.circular(AppShapes.large),
                        child: Column(
                          children: [
                            ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppShapes.large,
                                ),
                              ),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(
                                    AppShapes.medium,
                                  ),
                                ),
                                child: Icon(
                                  Icons.folder_outlined,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                              ),
                              title: const Text('Download Location'),
                              subtitle: Text(
                                location.isCustom
                                    ? location.displayPath
                                    : '${location.displayPath} (Default)',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: _pickDownloadDirectory,
                            ),
                            if (location.isCustom) ...[
                              const Divider(height: 1),
                              ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppShapes.large,
                                  ),
                                ),
                                leading: const Icon(Icons.restore_rounded),
                                title: const Text('Reset to Default Folder'),
                                subtitle: const Text(
                                  'Save downloads to Internal Storage/Download',
                                ),
                                onTap: _resetDownloadLocation,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSectionHeader('Download Engine', context),
                const SizedBox(height: AppSpacing.sm),
                LiquidGlassContainer(
                  padding: AppSpacing.cardPadding,
                  borderRadius: AppShapes.large,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'yt-dlp (embedded)',
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(
                                AppShapes.extraSmall,
                              ),
                            ),
                            child: Text(
                              _engineVersion ?? 'reading…',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Bundled with the app and used for every extraction and download. '
                        'Updates are fetched from the official yt-dlp release channel.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isCheckingUpdates
                              ? null
                              : _checkForUpdates,
                          icon: _isCheckingUpdates
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                          label: Text(
                            _isCheckingUpdates
                                ? 'Checking…'
                                : 'Check for yt-dlp Updates',
                          ),
                        ),
                      ),
                      if (_updateStatusMessage != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: AppSpacing.compactCardPadding,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(
                              AppShapes.small,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: colorScheme.onPrimaryContainer,
                                size: 16,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  _updateStatusMessage!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSectionHeader('JavaScript Challenge Solver', context),
                const SizedBox(height: AppSpacing.sm),
                LiquidGlassContainer(
                  padding: AppSpacing.cardPadding,
                  borderRadius: AppShapes.large,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(AppShapes.medium),
                        ),
                        child: Icon(
                          Icons.bolt_rounded,
                          color: colorScheme.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _jsRuntime.available
                                        ? '${_jsRuntime.displayName} (bundled)'
                                        : 'No JavaScript runtime',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _jsRuntime.available
                                        ? colorScheme.primaryContainer
                                        : colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(
                                      AppShapes.extraSmall,
                                    ),
                                  ),
                                  child: Text(
                                    _jsRuntime.available ? 'ACTIVE' : 'MISSING',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: _jsRuntime.available
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              _jsRuntime.available
                                  ? 'Used for EJS player-script challenges '
                                        '(`--js-runtimes ${_jsRuntime.name}:…`). '
                                        'Solver components are cached on device after the first fetch.'
                                  : 'yt-dlp cannot solve YouTube JavaScript challenges without a runtime. '
                                        'Extracted formats may be limited and downloads can fail with HTTP 403.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (_jsRuntime.available) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                _jsRuntime.version ?? _jsRuntime.path ?? '',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _isRefreshingEjs
                                      ? null
                                      : _refreshEjsComponents,
                                  icon: _isRefreshingEjs
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.refresh_rounded),
                                  label: Text(
                                    _isRefreshingEjs
                                        ? 'Refreshing EJS…'
                                        : 'Refresh EJS Components',
                                  ),
                                ),
                              ),
                              if (_ejsRefreshStatusMessage != null) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  _ejsRefreshStatusMessage!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSectionHeader('Media Tools', context),
                const SizedBox(height: AppSpacing.sm),
                LiquidGlassContainer(
                  padding: AppSpacing.cardPadding,
                  borderRadius: AppShapes.large,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.movie_filter_outlined,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FFmpeg & FFprobe (bundled)',
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'These native tools are packaged with the app and update with app releases. '
                              'Android only permits this app to execute native libraries installed with the APK, '
                              'so downloading replacements at runtime is not supported safely.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSectionHeader('Browser & Content', context),
                const SizedBox(height: AppSpacing.sm),
                LiquidGlassContainer(
                  padding: AppSpacing.cardPadding,
                  borderRadius: AppShapes.large,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'In-app WebView browser (beta)',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'MeteoraDL now ships an in-app browser so downloads can reuse '
                        'the same cookies, user agent and headers as the page. '
                        'External browsers cannot share this context on Android due to '
                        'sandboxing.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Content blockers & userscripts',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'uBlock-style filters, Dark Reader-style theming and '
                        'Violentmonkey-style userscripts are adapted for WebView. '
                        'Full WebExtension parity requires GeckoView.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSectionHeader('Hardware Diagnostics', context),
                const SizedBox(height: AppSpacing.sm),
                LiquidGlassContainer(
                  padding: AppSpacing.cardPadding,
                  borderRadius: AppShapes.large,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Display Resolution',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '${_deviceCapabilities.displayWidth}x${_deviceCapabilities.displayHeight}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Refresh Rate',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '${_deviceCapabilities.displayRefreshRate.round()} Hz of ${_deviceCapabilities.displayMaxRefreshRate.round()} Hz',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Available Storage',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '${(_deviceCapabilities.freeStorageBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: AppSpacing.xl),
                      Text(
                        'Hardware Video Decoders',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          _CodecChip(
                            label: 'AV1 (av01)',
                            isSupported: _deviceCapabilities.supportsVideoCodec(
                              'av1',
                            ),
                          ),
                          _CodecChip(
                            label: 'VP9',
                            isSupported: _deviceCapabilities.supportsVideoCodec(
                              'vp9',
                            ),
                          ),
                          _CodecChip(
                            label: 'HEVC / H.265',
                            isSupported: _deviceCapabilities.supportsVideoCodec(
                              'hevc',
                            ),
                          ),
                          _CodecChip(
                            label: 'AVC / H.264',
                            isSupported: _deviceCapabilities.supportsVideoCodec(
                              'h264',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Hardware Audio Decoders',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          _CodecChip(
                            label: 'Opus',
                            isSupported: _deviceCapabilities.supportsAudioCodec(
                              'opus',
                            ),
                          ),
                          _CodecChip(
                            label: 'AAC',
                            isSupported: _deviceCapabilities.supportsAudioCodec(
                              'aac',
                            ),
                          ),
                          _CodecChip(
                            label: 'MP3',
                            isSupported: _deviceCapabilities.supportsAudioCodec(
                              'mp3',
                            ),
                          ),
                          _CodecChip(
                            label: 'FLAC',
                            isSupported: _deviceCapabilities.supportsAudioCodec(
                              'flac',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSectionHeader('About App', context),
                const SizedBox(height: AppSpacing.sm),
                LiquidGlassContainer(
                  padding: AppSpacing.cardPadding,
                  borderRadius: AppShapes.large,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.primary,
                                  colorScheme.tertiary,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppShapes.medium,
                              ),
                            ),
                            child: Icon(
                              Icons.cloud_download_rounded,
                              color: colorScheme.onPrimary,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Meteora',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(
                                          AppShapes.extraSmall,
                                        ),
                                      ),
                                      child: Text(
                                        'v${AppUpdateService.currentVersion}',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.onPrimaryContainer,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'High-performance Android media downloader',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Powered by yt-dlp, QuickJS, FFmpeg, and Material 3 Expressive UI. '
                        '100% on-device processing, Scoped Storage compliant, zero telemetry.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              _isCheckingAppUpdate ? null : _checkAppUpdate,
                          icon: _isCheckingAppUpdate
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sync_rounded),
                          label: Text(
                            _isCheckingAppUpdate
                                ? 'Checking GitHub…'
                                : 'Check for Updates',
                          ),
                        ),
                      ),
                      if (_appUpdateMessage != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: AppSpacing.compactCardPadding,
                          decoration: BoxDecoration(
                            color: _availableAppUpdate != null
                                ? colorScheme.primaryContainer
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(
                              AppShapes.small,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _availableAppUpdate != null
                                        ? Icons.new_releases_rounded
                                        : Icons.info_outline_rounded,
                                    color: _availableAppUpdate != null
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurfaceVariant,
                                    size: 16,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      _appUpdateMessage!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: _availableAppUpdate != null
                                            ? colorScheme.onPrimaryContainer
                                            : colorScheme.onSurfaceVariant,
                                        fontWeight: _availableAppUpdate != null
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_availableAppUpdate != null) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () {
                                        final url =
                                            _availableAppUpdate!.htmlUrl;
                                        NativeBridge.openUrl(url);
                                      },
                                      icon: const Icon(
                                        Icons.open_in_new_rounded,
                                        size: 14,
                                      ),
                                      label: const Text('View Release'),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    FilledButton.icon(
                                      onPressed: () {
                                        final apkUrl =
                                            _availableAppUpdate!
                                                .apkDownloadUrl ??
                                            _availableAppUpdate!.htmlUrl;
                                        NativeBridge.openUrl(apkUrl);
                                      },
                                      icon: const Icon(
                                        Icons.download_rounded,
                                        size: 14,
                                      ),
                                      label: const Text('Download APK'),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                LiquidGlassContainer(
                  padding: EdgeInsets.zero,
                  borderRadius: AppShapes.large,
                  child: Material(
                    type: MaterialType.transparency,
                    borderRadius: BorderRadius.circular(AppShapes.large),
                    child: Column(
                      children: [
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppShapes.large,
                            ),
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(
                                AppShapes.medium,
                              ),
                            ),
                            child: Icon(
                              Icons.info_outline_rounded,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                          title: const Text('About Meteora'),
                          subtitle: const Text(
                            'Architecture, core engine & privacy',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _showAboutAppDialog(context),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppShapes.large,
                            ),
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(
                                AppShapes.medium,
                              ),
                            ),
                            child: Icon(
                              Icons.code_rounded,
                              color: colorScheme.onTertiaryContainer,
                            ),
                          ),
                          title: const Text('GitHub Repository'),
                          subtitle: const Text(
                            'ameya-deshpande-5056/meteora-dl',
                          ),
                          trailing: const Icon(Icons.open_in_new_rounded),
                          onTap: () async {
                            final opened = await NativeBridge.openUrl(
                              AppUpdateService.githubUrl,
                            );
                            if (!opened && context.mounted) {
                              await Clipboard.setData(
                                const ClipboardData(
                                  text: AppUpdateService.githubUrl,
                                ),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'GitHub link copied to clipboard.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppShapes.large,
                            ),
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(
                                AppShapes.medium,
                              ),
                            ),
                            child: Icon(
                              Icons.description_outlined,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          title: const Text('Open Source Licenses'),
                          subtitle: const Text(
                            'Third-party software notices',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            showLicensePage(
                              context: context,
                              applicationName: 'Meteora',
                              applicationVersion:
                                  'v${AppUpdateService.currentVersion}',
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildSectionHeader(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _CodecChip extends StatelessWidget {
  final String label;
  final bool isSupported;

  const _CodecChip({required this.label, required this.isSupported});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Chip(
      avatar: Icon(
        isSupported ? Icons.check_circle_rounded : Icons.cancel_outlined,
        size: 16,
        color: isSupported ? colorScheme.primary : colorScheme.outline,
      ),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: isSupported
          ? colorScheme.surfaceContainerHighest
          : colorScheme.surfaceContainerLow,
    );
  }
}

class _ThemePreviewSwatch extends StatelessWidget {
  final AppThemeMode mode;

  const _ThemePreviewSwatch({required this.mode});

  @override
  Widget build(BuildContext context) {
    final outlineColor = Theme.of(context).colorScheme.outlineVariant;

    if (mode == AppThemeMode.system) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: outlineColor, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: const Row(
          children: [
            Expanded(child: ColoredBox(color: Color(0xFFF5F7FA))),
            Expanded(child: ColoredBox(color: Color(0xFF1A1F29))),
          ],
        ),
      );
    }

    final Color fillColor;
    switch (mode) {
      case AppThemeMode.light:
        fillColor = const Color(0xFFF8FAFC);
        break;
      case AppThemeMode.dark:
        fillColor = const Color(0xFF1E2430);
        break;
      case AppThemeMode.amoled:
        fillColor = const Color(0xFF000000);
        break;
      case AppThemeMode.system:
        fillColor = const Color(0xFF1E2430);
        break;
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: fillColor,
        shape: BoxShape.circle,
        border: Border.all(color: outlineColor, width: 1.2),
      ),
    );
  }
}
