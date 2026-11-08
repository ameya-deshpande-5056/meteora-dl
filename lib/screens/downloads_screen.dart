import 'package:flutter/material.dart';
import '../services/native_bridge.dart';
import '../state/download_state.dart';
import '../theme/liquid_glass_theme.dart';
import '../widgets/glass_card.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  int _selectedTab = 0; // 0 = Active, 1 = Completed

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: LiquidGlassTheme.textSecondary),
            onPressed: () {
              // Clear completed
            },
            tooltip: 'Clear Completed',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: DownloadStateManager.instance,
        builder: (context, _) {
          final activeTasks = DownloadStateManager.instance.activeTasks;
          final completedTasks = DownloadStateManager.instance.completedTasks;
          final currentList = _selectedTab == 0 ? activeTasks : completedTasks;

          return Column(
            children: [
              // Segmented Tab Switcher
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: LiquidGlassTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: LiquidGlassTheme.glassBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TabButton(
                          title: 'Active (${activeTasks.length})',
                          isSelected: _selectedTab == 0,
                          onTap: () => setState(() => _selectedTab = 0),
                        ),
                      ),
                      Expanded(
                        child: _TabButton(
                          title: 'Completed (${completedTasks.length})',
                          isSelected: _selectedTab == 1,
                          onTap: () => setState(() => _selectedTab = 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Task List
              Expanded(
                child: currentList.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        itemCount: currentList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final task = currentList[index];
                          return _DownloadTaskCard(task: task);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _selectedTab == 0 ? Icons.downloading_rounded : Icons.check_circle_outline_rounded,
            size: 64,
            color: LiquidGlassTheme.textMuted.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedTab == 0 ? 'No active downloads' : 'No completed downloads yet',
            style: const TextStyle(
              color: LiquidGlassTheme.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Paste or share a URL on Home to start downloading',
            style: TextStyle(color: LiquidGlassTheme.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? LiquidGlassTheme.cyanAccent.withAlpha(40) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: LiquidGlassTheme.cyanAccent.withAlpha(100)) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? LiquidGlassTheme.cyanAccent : LiquidGlassTheme.textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _DownloadTaskCard extends StatelessWidget {
  final DownloadTask task;

  const _DownloadTaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final isDownloading = task.status == TaskStatus.downloading;
    final isCompleted = task.status == TaskStatus.completed;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderColor: isDownloading ? LiquidGlassTheme.cyanAccent.withAlpha(60) : LiquidGlassTheme.glassBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: LiquidGlassTheme.surfaceHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle_rounded : Icons.movie_outlined,
                  color: isCompleted ? LiquidGlassTheme.emeraldAccent : LiquidGlassTheme.cyanAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        color: LiquidGlassTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${task.formatLabel} • ${task.totalSizeText.isNotEmpty ? task.totalSizeText : task.status.label}',
                      style: const TextStyle(color: LiquidGlassTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isDownloading)
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: LiquidGlassTheme.roseAccent, size: 20),
                  onPressed: () {
                    NativeBridge.cancelDownload(task.taskId);
                    DownloadStateManager.instance.cancelTask(task.taskId);
                  },
                ),
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: task.progressPercent / 100.0,
                backgroundColor: LiquidGlassTheme.surfaceHigh,
                valueColor: const AlwaysStoppedAnimation(LiquidGlassTheme.cyanAccent),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${task.progressPercent.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: LiquidGlassTheme.cyanAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${task.speedText} • ETA ${task.etaText}',
                  style: const TextStyle(color: LiquidGlassTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
