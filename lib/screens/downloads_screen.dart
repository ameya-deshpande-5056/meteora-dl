import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/native_bridge.dart';
import '../state/download_state.dart';
import '../theme/app_shapes.dart';
import '../theme/app_spacing.dart';
import '../widgets/liquid_glass_container.dart';
import '../widgets/wavy_progress_indicator.dart';

class DownloadsScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHome;

  const DownloadsScreen({super.key, this.onNavigateToHome});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  int _selectedTab = 0; // 0 = Active, 1 = Completed, 2 = Failed

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: LiquidGlassAppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: 'Clear completed',
            onPressed: () {
              HapticFeedback.selectionClick();
              DownloadStateManager.instance.clearCompletedTasks();
            },
          ),
        ],
      ),
      body: LiquidGlassBackground(
        child: ListenableBuilder(
            listenable: DownloadStateManager.instance,
            builder: (context, _) {
              final inProgress = DownloadStateManager.instance.inProgressTasks;
              final completed = DownloadStateManager.instance.completedTasks;
              final failed = DownloadStateManager.instance.failedTasks;
              final currentList = _selectedTab == 0
                  ? inProgress
                  : _selectedTab == 1
                  ? completed
                  : failed;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    child: SegmentedButton<int>(
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        ),
                        textStyle: WidgetStatePropertyAll(
                          Theme.of(context).textTheme.labelMedium,
                        ),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppShapes.full),
                          ),
                        ),
                      ),
                      segments: [
                        ButtonSegment(
                          value: 0,
                          label: Text('Active (${inProgress.length})'),
                        ),
                        ButtonSegment(
                          value: 1,
                          label: Text('Completed (${completed.length})'),
                        ),
                        ButtonSegment(
                          value: 2,
                          label: Text('Failed (${failed.length})'),
                        ),
                      ],
                      selected: {_selectedTab},
                      onSelectionChanged: (set) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedTab = set.first);
                      },
                    ),
                  ),
                  Expanded(
                    child: currentList.isEmpty
                        ? _buildEmptyState(context)
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.md,
                              AppSpacing.lg,
                              MediaQuery.paddingOf(context).bottom + 108,
                            ),
                            itemCount: currentList.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.md),
                            itemBuilder: (context, index) {
                              final task = currentList[index];
                              return _TaskCard(task: task);
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final String title;
    final String message;
    final IconData icon;
    switch (_selectedTab) {
      case 0:
        title = 'No Active Downloads';
        message =
            'Active media transfers will appear here with live speed and progress.';
        icon = Icons.downloading_rounded;
        break;
      case 1:
        title = 'No Completed Downloads';
        message =
            'Completed media downloads are saved to your offline library.';
        icon = Icons.check_circle_outline_rounded;
        break;
      default:
        title = 'Nothing Failed';
        message =
            'Downloads that fail or are cancelled stay here so you can retry them.';
        icon = Icons.error_outline_rounded;
    }

    // This lives below the tab selector. Offset the centre by that selector's
    // full footprint so the card remains centred in the whole screen.
    return Transform.translate(
      offset: const Offset(0, -56),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: LiquidGlassContainer(
            key: const Key('downloads-empty-state'),
            padding: const EdgeInsets.all(AppSpacing.xl),
            borderRadius: AppShapes.extraLarge,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withAlpha(28),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 44, color: colorScheme.primary),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  title,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_selectedTab == 0 && widget.onNavigateToHome != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.tonalIcon(
                    onPressed: widget.onNavigateToHome,
                    icon: const Icon(Icons.add_link_rounded),
                    label: const Text('Add Download'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final DownloadTask task;

  const _TaskCard({required this.task});

  bool get _isVideo =>
      !task.formatLabel.startsWith('Audio Only') &&
      !task.formatLabel.startsWith('Subtitles Only');

  Future<void> _openTaskFile(BuildContext context) async {
    final path = task.filePath;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File path unavailable for this download.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final opened = await NativeBridge.openInExternalPlayer(
      filePath: path,
      title: task.title,
      isVideo: _isVideo,
      mimeType: task.formatLabel.startsWith('Subtitles Only') ? 'text/*' : null,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No external player found or file could not be opened.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _retry(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final started = await DownloadStateManager.instance.retryTask(task.taskId);
    if (!started && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This download was saved without its command. Paste the link again to restart it.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _cancel(BuildContext context) {
    HapticFeedback.selectionClick();
    NativeBridge.cancelDownload(task.taskId);
    DownloadStateManager.instance.cancelTask(task.taskId);
  }

  Widget _thumbnail(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fallback = ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        task.status == TaskStatus.completed
            ? Icons.check_circle_rounded
            : task.status == TaskStatus.error
            ? Icons.error_outline_rounded
            : Icons.movie_outlined,
        size: 20,
        color: task.status == TaskStatus.error
            ? colorScheme.error
            : colorScheme.onSurfaceVariant,
      ),
    );

    final url = task.thumbnailUrl;
    final hasRemote =
        url != null &&
        (url.startsWith('http://') || url.startsWith('https://'));

    return SizedBox(
      width: 56,
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppShapes.small),
        child: hasRemote
            ? Image.network(
                url,
                fit: BoxFit.cover,
                cacheWidth: 168,
                errorBuilder: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDownloading = task.status == TaskStatus.downloading;
    final isQueued = task.status == TaskStatus.queued;
    final isPaused = task.status == TaskStatus.paused;
    final isCompleted = task.status == TaskStatus.completed;
    final isError = task.status == TaskStatus.error;
    final isCancelled = task.status == TaskStatus.cancelled;
    final canOpen =
        isCompleted && task.filePath != null && task.filePath!.isNotEmpty;

    return RepaintBoundary(
      child: LiquidGlassContainer(
        padding: AppSpacing.cardPadding,
        borderRadius: AppShapes.large,
        onTap: canOpen ? () => _openTaskFile(context) : null,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumbnail(context),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      task.totalSizeText.isNotEmpty
                          ? '${task.formatLabel} • ${task.totalSizeText}'
                          : '${task.formatLabel} • ${task.status.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (canOpen)
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded),
                  color: colorScheme.primary,
                  tooltip: 'Open in external player',
                  onPressed: () => _openTaskFile(context),
                ),
            ],
          ),

          if (isDownloading || isQueued) ...[
            const SizedBox(height: AppSpacing.md),
            WavyProgressIndicator(
              value: isQueued || task.progressPercent <= 0
                  ? null
                  : task.progressPercent / 100.0,
              isAnimating: isDownloading || isQueued,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(
                  isQueued
                      ? 'Queued'
                      : '${task.progressPercent.toStringAsFixed(1)}%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                Text(
                  isQueued
                      ? 'Waiting for a free slot'
                      : '${task.speedText} • ETA ${task.etaText}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                if (DownloadStateManager.isDirectTask(task))
                  IconButton(
                    icon: const Icon(Icons.pause_rounded, size: 20),
                    tooltip: 'Pause download',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      DownloadStateManager.instance.pauseTask(task.taskId);
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Cancel download',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _cancel(context),
                ),
              ],
            ),
          ],

          if (isPaused) ...[
            const SizedBox(height: AppSpacing.sm),
            if (task.progressPercent > 0) ...[
              WavyProgressIndicator(
                value: task.progressPercent / 100.0,
                isAnimating: false,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Row(
              children: [
                Icon(
                  Icons.pause_circle_outline_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Interrupted at ${task.progressPercent.toStringAsFixed(0)}% — resume to finish it.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: task.canRetry || DownloadStateManager.isDirectTask(task)
                      ? () => _retry(context)
                      : null,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Resume'),
                ),
              ],
            ),
          ],

          if (isError || isCancelled) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              isCancelled
                  ? 'Cancelled by you.'
                  : (task.errorMessage ?? 'Download failed.'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: isError
                    ? colorScheme.error
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: task.canRetry || DownloadStateManager.isDirectTask(task)
                      ? () => _retry(context)
                      : null,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    DownloadStateManager.instance.removeTask(task.taskId);
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Dismiss'),
                ),
              ],
            ),
          ],

          if (isCompleted) ...[
            const SizedBox(height: AppSpacing.xxs),
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Saved to your library',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  tooltip: 'Remove from download list',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    DownloadStateManager.instance.removeTask(task.taskId);
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
  }
}
