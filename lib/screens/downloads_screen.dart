import 'package:flutter/material.dart';
import '../services/native_bridge.dart';
import '../state/download_state.dart';
import '../theme/app_shapes.dart';
import '../theme/app_spacing.dart';
import '../widgets/liquid_glass_container.dart';

class DownloadsScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHome;

  const DownloadsScreen({
    super.key,
    this.onNavigateToHome,
  });

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  int _selectedTab = 0; // 0 = Active, 1 = Completed

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: LiquidGlassAppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: 'Clear completed',
            onPressed: () {
              DownloadStateManager.instance.clearCompletedTasks();
            },
          ),
        ],
      ),
      body: LiquidGlassBackground(
        child: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: DownloadStateManager.instance,
            builder: (context, _) {
              final activeTasks = DownloadStateManager.instance.activeTasks;
              final completedTasks = DownloadStateManager.instance.completedTasks;
              final currentList = _selectedTab == 0 ? activeTasks : completedTasks;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Segmented Button Tab Switcher
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    child: SegmentedButton<int>(
                      segments: [
                        ButtonSegment(
                          value: 0,
                          label: Text('Active (${activeTasks.length})'),
                          icon: const Icon(Icons.downloading_rounded, size: 16),
                        ),
                        ButtonSegment(
                          value: 1,
                          label: Text('Completed (${completedTasks.length})'),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                        ),
                      ],
                      selected: {_selectedTab},
                      onSelectionChanged: (set) => setState(() => _selectedTab = set.first),
                    ),
                  ),

                  // Task List or Empty State
                  Expanded(
                    child: currentList.isEmpty
                        ? _buildEmptyState(context)
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.md,
                              AppSpacing.lg,
                              MediaQuery.paddingOf(context).bottom + 96,
                            ),
                            itemCount: currentList.length,
                            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
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
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isActiveTab = _selectedTab == 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActiveTab ? Icons.downloading_rounded : Icons.check_circle_outline_rounded,
                size: 48,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              isActiveTab ? 'No Active Downloads' : 'No Completed Downloads',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isActiveTab
                  ? 'Active media transfers will appear here with live speed and progress.'
                  : 'Completed media downloads are saved to your offline library.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (isActiveTab && widget.onNavigateToHome != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: widget.onNavigateToHome,
                icon: const Icon(Icons.add_link_rounded),
                label: const Text('Add Download'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final DownloadTask task;

  const _TaskCard({required this.task});

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

    final isVideo = !task.formatLabel.startsWith('Audio Only') &&
        !task.formatLabel.startsWith('Subtitles Only');
    final mimeType = task.formatLabel.startsWith('Subtitles Only') ? 'text/*' : null;

    final opened = await NativeBridge.openInExternalPlayer(
      filePath: path,
      title: task.title,
      isVideo: isVideo,
      mimeType: mimeType,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No external player found or file could not be opened.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDownloading = task.status == TaskStatus.downloading;
    final isCompleted = task.status == TaskStatus.completed;
    final isError = task.status == TaskStatus.error;
    final canOpen = isCompleted && task.filePath != null && task.filePath!.isNotEmpty;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppShapes.medium),
        onTap: canOpen ? () => _openTaskFile(context) : null,
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppShapes.small),
                    child: Container(
                      width: 44,
                      height: 44,
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        isCompleted
                            ? Icons.check_circle_rounded
                            : isError
                                ? Icons.error_outline_rounded
                                : Icons.movie_outlined,
                        color: isCompleted
                            ? colorScheme.primary
                            : isError
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${task.formatLabel} • ${task.totalSizeText.isNotEmpty ? task.totalSizeText : task.status.label}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (isDownloading)
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Cancel download',
                      onPressed: () {
                        NativeBridge.cancelDownload(task.taskId);
                        DownloadStateManager.instance.cancelTask(task.taskId);
                      },
                    )
                  else if (canOpen)
                    IconButton(
                      icon: const Icon(Icons.open_in_new_rounded),
                      color: colorScheme.primary,
                      tooltip: 'Open in external player',
                      onPressed: () => _openTaskFile(context),
                    ),
                ],
              ),
              if (isDownloading) ...[
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppShapes.extraSmall),
                  child: LinearProgressIndicator(
                    value: task.progressPercent / 100.0,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${task.progressPercent.toStringAsFixed(1)}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${task.speedText} • ETA ${task.etaText}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
              if (isError) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  task.errorMessage ?? 'Download failed',
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
