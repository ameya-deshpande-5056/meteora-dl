import 'package:flutter/material.dart';
import '../services/native_bridge.dart';
import '../state/download_state.dart';
import '../theme/app_shapes.dart';
import '../theme/app_spacing.dart';
import 'liquid_glass_container.dart';

/// Guided first-launch setup prompting the user to grant required device
/// permissions and choose where downloaded media files should be stored.
class FirstLaunchSetupDialog extends StatefulWidget {
  const FirstLaunchSetupDialog({super.key});

  @override
  State<FirstLaunchSetupDialog> createState() => _FirstLaunchSetupDialogState();
}

class _FirstLaunchSetupDialogState extends State<FirstLaunchSetupDialog> {
  PermissionStatusInfo _permissionStatus = PermissionStatusInfo.unknown();
  bool _isRequestingPermissions = false;
  bool _isPickingFolder = false;
  bool _isFinishing = false;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final status = await NativeBridge.getPermissionStatus();
    await DownloadStateManager.instance.refreshDownloadLocation();
    if (mounted) {
      setState(() => _permissionStatus = status);
    }
  }

  Future<void> _grantPermissions() async {
    setState(() => _isRequestingPermissions = true);
    final updated = await NativeBridge.requestPermissions();
    if (mounted) {
      setState(() {
        _permissionStatus = updated;
        _isRequestingPermissions = false;
      });
    }
  }

  Future<void> _chooseFolder() async {
    setState(() => _isPickingFolder = true);
    await DownloadStateManager.instance.pickDownloadLocation();
    if (mounted) {
      setState(() => _isPickingFolder = false);
    }
  }

  Future<void> _finishSetup() async {
    setState(() => _isFinishing = true);
    if (!_permissionStatus.allGranted) {
      final updated = await NativeBridge.requestPermissions();
      if (mounted) {
        _permissionStatus = updated;
      }
    }
    DownloadStateManager.instance.completeFirstLaunchSetup();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
        child: LiquidGlassContainer(
          padding: AppSpacing.cardPadding,
          borderRadius: AppShapes.extraLarge,
          child: SingleChildScrollView(
            child: ListenableBuilder(
              listenable: DownloadStateManager.instance,
              builder: (context, _) {
                final location = DownloadStateManager.instance.downloadLocation;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(AppShapes.medium),
                          ),
                          child: Icon(
                            Icons.folder_special_outlined,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Welcome to MeteoraDL', style: theme.textTheme.titleMedium),
                              Text(
                                'Set up storage & permissions',
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
                      'Choose where your downloads will be saved and grant permissions so background downloads and media indexing work properly.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // 1. Download Folder Selection
                    Container(
                      padding: AppSpacing.compactCardPadding,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh.withAlpha(170),
                        borderRadius: BorderRadius.circular(AppShapes.medium),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withAlpha(80),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.folder_outlined, size: 20, color: colorScheme.primary),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Download Location',
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            location.isCustom
                                ? location.displayPath
                                : '${location.displayPath} (Default public folder)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isPickingFolder ? null : _chooseFolder,
                              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                              label: Text(
                                location.isCustom ? 'Change Folder' : 'Choose Folder',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // 2. Permissions Card
                    Container(
                      padding: AppSpacing.compactCardPadding,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh.withAlpha(170),
                        borderRadius: BorderRadius.circular(AppShapes.medium),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withAlpha(80),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _permissionStatus.allGranted
                                    ? Icons.verified_user_rounded
                                    : Icons.security_rounded,
                                size: 20,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'App Permissions',
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                              if (_permissionStatus.allGranted)
                                Text(
                                  'Granted',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Notifications for download progress and media access for saved videos & audio.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (!_permissionStatus.allGranted) ...[
                            const SizedBox(height: AppSpacing.sm),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.tonalIcon(
                                onPressed: _isRequestingPermissions ? null : _grantPermissions,
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                                label: Text(
                                  _isRequestingPermissions
                                      ? 'Requesting permissions...'
                                      : 'Grant All Permissions',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // 3. Finish CTA
                    FilledButton.icon(
                      onPressed: _isFinishing ? null : _finishSetup,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(
                        _permissionStatus.allGranted
                            ? 'Continue'
                            : 'Allow Permissions & Continue',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
