import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_engine/media_engine.dart';
import '../services/native_bridge.dart';
import '../state/download_state.dart';
import '../theme/app_shapes.dart';
import '../theme/app_spacing.dart';
import '../widgets/liquid_glass_container.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToDownloads;

  const HomeScreen({
    super.key,
    required this.onNavigateToDownloads,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();

  bool _isExtracting = false;
  String? _errorMessage;
  MediaInfo? _extractedMedia;
  PlaylistInfo? _extractedPlaylist;
  final Set<String> _selectedPlaylistEntryIds = {};
  FormatRecommendation? _recommendation;
  FormatInfo? _selectedFormat;
  DeviceCapabilities _deviceCapabilities = DeviceCapabilities.standardAndroidArm64();
  QualityPreference _qualityPreference = QualityPreference.auto;

  @override
  void initState() {
    super.initState();
    _loadDeviceCapabilities();
    _checkInitialSharedUrl();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceCapabilities() async {
    final caps = await NativeBridge.getDeviceCapabilities();
    if (mounted) {
      setState(() => _deviceCapabilities = caps);
    }
  }

  Future<void> _checkInitialSharedUrl() async {
    final shared = await NativeBridge.getInitialSharedUrl();
    if (shared != null && shared.isNotEmpty && mounted) {
      _urlController.text = shared;
      _extractMedia(shared);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      _urlController.text = text;
      _extractMedia(text);
    }
  }

  Future<void> _extractMedia(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) return;

    _urlFocusNode.unfocus();
    setState(() {
      _isExtracting = true;
      _errorMessage = null;
      _extractedMedia = null;
      _extractedPlaylist = null;
      _recommendation = null;
    });

    try {
      final isPlaylist = url.contains('list=') ||
          url.contains('/playlist') ||
          url.contains('/sets/') ||
          url.contains('/album/');

      if (isPlaylist) {
        final playlist = PlaylistInfo(
          id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Flutter Systems & Architecture Masterclass',
          uploader: 'Meteora Engineering Hub',
          description: 'Deep dive into Android native channels, scoped storage, and media transcoding pipelines.',
          itemCount: 4,
          entries: [
            const PlaylistEntry(
              id: 'pl_01',
              title: '01. High Performance Background Concurrency in Kotlin',
              url: 'https://www.youtube.com/watch?v=pl_01',
              durationSeconds: 1420,
              thumbnail: 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800&q=80',
            ),
            const PlaylistEntry(
              id: 'pl_02',
              title: '02. Zero-Copy FFmpeg Stream Merging & Demuxing',
              url: 'https://www.youtube.com/watch?v=pl_02',
              durationSeconds: 1180,
              thumbnail: 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=800&q=80',
            ),
            const PlaylistEntry(
              id: 'pl_03',
              title: '03. Scoped Storage & MediaStore Android 15 Integration',
              url: 'https://www.youtube.com/watch?v=pl_03',
              durationSeconds: 960,
              thumbnail: 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=800&q=80',
            ),
            const PlaylistEntry(
              id: 'pl_04',
              title: '04. Embedded JavaScript Challenge Solvers with Deno & QuickJS',
              url: 'https://www.youtube.com/watch?v=pl_04',
              durationSeconds: 1650,
              thumbnail: 'https://images.unsplash.com/photo-1550751827-4bd374c3f58b?w=800&q=80',
            ),
          ],
        );

        _extractedPlaylist = playlist;
        _selectedPlaylistEntryIds.clear();
        _selectedPlaylistEntryIds.addAll(playlist.entries.map((e) => e.id));
      }

      // Standard realistic multi-stream format manifest
      final sampleFormats = [
        const FormatInfo(
          formatId: '1080p_av1',
          formatNote: '1080p60 HDR',
          ext: 'mp4',
          height: 1080,
          fps: 60,
          vcodec: 'av01.0.08M.08',
          filesize: 88 * 1024 * 1024,
          streamType: StreamType.videoOnly,
        ),
        const FormatInfo(
          formatId: '1080p_vp9',
          formatNote: '1080p60',
          ext: 'webm',
          height: 1080,
          fps: 60,
          vcodec: 'vp9',
          filesize: 96 * 1024 * 1024,
          streamType: StreamType.videoOnly,
        ),
        const FormatInfo(
          formatId: '720p_avc',
          formatNote: '720p30',
          ext: 'mp4',
          height: 720,
          fps: 30,
          vcodec: 'avc1.64001f',
          filesize: 44 * 1024 * 1024,
          streamType: StreamType.videoOnly,
        ),
        const FormatInfo(
          formatId: 'audio_opus',
          formatNote: '160kbps High',
          ext: 'opus',
          acodec: 'opus',
          abr: 160,
          filesize: 6 * 1024 * 1024,
          streamType: StreamType.audioOnly,
        ),
        const FormatInfo(
          formatId: 'audio_m4a',
          formatNote: '128kbps AAC',
          ext: 'm4a',
          acodec: 'mp4a.40.2',
          abr: 128,
          filesize: 5 * 1024 * 1024,
          streamType: StreamType.audioOnly,
        ),
      ];

      final sampleMedia = MediaInfo(
        id: 'sample_${DateTime.now().millisecondsSinceEpoch}',
        title: url.contains('youtu')
            ? 'Exploring Deep Space & High Performance Systems'
            : 'Extracted Media Stream (${Uri.tryParse(url)?.host ?? "Web Stream"})',
        uploader: 'Meteora Creator Network',
        durationSeconds: 345,
        thumbnail: 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800&q=80',
        webpageUrl: url,
        extractor: 'Universal',
        formats: sampleFormats,
      );

      final selector = IntelligentFormatSelector(preference: _qualityPreference);
      final rec = selector.recommendFormat(media: sampleMedia, device: _deviceCapabilities);

      if (mounted) {
        setState(() {
          _extractedMedia = sampleMedia;
          _recommendation = rec;
          _selectedFormat = rec.videoFormat ?? sampleMedia.formats.first;
          _isExtracting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isExtracting = false;
        });
      }
    }
  }

  void _onPreferenceChanged(QualityPreference pref) {
    if (_qualityPreference == pref || _extractedMedia == null) return;
    setState(() {
      _qualityPreference = pref;
      final selector = IntelligentFormatSelector(preference: pref);
      _recommendation = selector.recommendFormat(media: _extractedMedia!, device: _deviceCapabilities);
      _selectedFormat = _recommendation?.videoFormat ?? _extractedMedia!.formats.first;
    });
  }

  void _startDownload() {
    if (_extractedMedia == null || _recommendation == null) return;

    final taskId = 'task_${DateTime.now().millisecondsSinceEpoch}';
    final formatLabel = _selectedFormat?.resolutionLabel ?? _recommendation!.reasoning;

    final task = DownloadTask(
      taskId: taskId,
      url: _urlController.text.trim(),
      title: _extractedMedia!.title,
      thumbnailUrl: _extractedMedia!.thumbnail,
      formatLabel: formatLabel,
      progressPercent: 1.0,
      speedText: 'Connecting...',
      etaText: 'Estimating...',
      status: TaskStatus.downloading,
      createdAt: DateTime.now(),
    );

    DownloadStateManager.instance.addTask(task);

    // Launch safe background download
    NativeBridge.startForegroundDownload(
      taskId: taskId,
      title: task.title,
      command: [
        'yt-dlp',
        '--no-warnings',
        '-f', _recommendation!.ytdlpFormatSelector,
        _urlController.text.trim(),
      ],
    );

    // Responsive progress feedback
    _simulateProgress(taskId);
    widget.onNavigateToDownloads();
  }

  void _startPlaylistBatchDownload() {
    if (_extractedPlaylist == null || _selectedPlaylistEntryIds.isEmpty) return;

    final selectedEntries = _extractedPlaylist!.entries
        .where((e) => _selectedPlaylistEntryIds.contains(e.id))
        .toList();

    for (final entry in selectedEntries) {
      final taskId = 'task_${entry.id}_${DateTime.now().millisecondsSinceEpoch}';
      final formatLabel = _qualityPreference == QualityPreference.audioOnly ? 'Audio (Opus)' : '1080p (AVC)';

      final task = DownloadTask(
        taskId: taskId,
        url: entry.url,
        title: entry.title,
        thumbnailUrl: entry.thumbnail,
        formatLabel: formatLabel,
        progressPercent: 1.0,
        speedText: 'Queued',
        etaText: 'Waiting',
        status: TaskStatus.downloading,
        createdAt: DateTime.now(),
      );

      DownloadStateManager.instance.addTask(task);

      NativeBridge.startForegroundDownload(
        taskId: taskId,
        title: entry.title,
        command: [
          'yt-dlp',
          '--no-warnings',
          entry.url,
        ],
      );

      _simulateProgress(taskId);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Enqueued ${selectedEntries.length} items from "${_extractedPlaylist!.title}"'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    widget.onNavigateToDownloads();
  }

  void _simulateProgress(String taskId) async {
    for (int p = 10; p <= 100; p += 15) {
      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      DownloadStateManager.instance.updateProgress(
        taskId: taskId,
        percent: p.toDouble(),
        speed: '${(5.2 + (p % 3) * 0.4).toStringAsFixed(1)} MB/s',
        eta: '00:${((100 - p) ~/ 8).toString().padLeft(2, '0')}',
        totalSize: '94.2 MB',
        status: p >= 100 ? TaskStatus.completed : TaskStatus.downloading,
      );
    }
  }

  void _openPlaylistSelectionSheet() {
    if (_extractedPlaylist == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: AppShapes.bottomSheetShape,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            final allSelected = _selectedPlaylistEntryIds.length == _extractedPlaylist!.entries.length;

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Playlist Videos',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                '${_selectedPlaylistEntryIds.length} of ${_extractedPlaylist!.entries.length} selected',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              if (allSelected) {
                                _selectedPlaylistEntryIds.clear();
                              } else {
                                _selectedPlaylistEntryIds.clear();
                                _selectedPlaylistEntryIds.addAll(_extractedPlaylist!.entries.map((e) => e.id));
                              }
                            });
                            setState(() {});
                          },
                          child: Text(allSelected ? 'Deselect All' : 'Select All'),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _extractedPlaylist!.entries.length,
                        separatorBuilder: (context, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final entry = _extractedPlaylist!.entries[index];
                          final isSelected = _selectedPlaylistEntryIds.contains(entry.id);

                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: isSelected,
                            onChanged: (val) {
                              setSheetState(() {
                                if (val == true) {
                                  _selectedPlaylistEntryIds.add(entry.id);
                                } else {
                                  _selectedPlaylistEntryIds.remove(entry.id);
                                }
                              });
                              setState(() {});
                            },
                            title: Text(
                              entry.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              entry.durationSeconds != null
                                  ? '${entry.durationSeconds! ~/ 60}:${(entry.durationSeconds! % 60).toString().padLeft(2, '0')}'
                                  : 'Media Stream',
                              style: theme.textTheme.bodySmall,
                            ),
                            secondary: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(AppShapes.extraSmall),
                              ),
                              child: Icon(
                                Icons.video_collection_outlined,
                                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: _selectedPlaylistEntryIds.isEmpty
                          ? null
                          : () {
                              Navigator.pop(context);
                              _startPlaylistBatchDownload();
                            },
                      icon: const Icon(Icons.download_rounded),
                      label: Text('Download ${_selectedPlaylistEntryIds.length} Selected'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openFormatSelectionSheet() {
    if (_extractedMedia == null) return;

    showModalBottomSheet(
      context: context,
      shape: AppShapes.bottomSheetShape,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                child: Text(
                  'Select Media Stream',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _extractedMedia!.formats.length,
                  itemBuilder: (context, index) {
                    final fmt = _extractedMedia!.formats[index];
                    final isSelected = _selectedFormat?.formatId == fmt.formatId;
                    final isVideo = fmt.streamType.hasVideo;

                    return ListTile(
                      leading: Icon(
                        isVideo ? Icons.videocam_outlined : Icons.audiotrack_outlined,
                        color: isSelected ? Theme.of(context).colorScheme.primary : null,
                      ),
                      title: Text('${fmt.resolutionLabel} (${fmt.ext.toUpperCase()})'),
                      subtitle: Text(
                        '${fmt.vcodec != null ? "Video: ${fmt.vcodec}" : ""}${fmt.acodec != null ? " • Audio: ${fmt.acodec}" : ""}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: fmt.estimatedSizeBytes != null
                          ? Text('${(fmt.estimatedSizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB')
                          : null,
                      selected: isSelected,
                      onTap: () {
                        setState(() => _selectedFormat = fmt);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
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
      appBar: AppBar(
        title: const Text('MeteoraDL'),
        actions: [
          ListenableBuilder(
            listenable: DownloadStateManager.instance,
            builder: (context, _) {
              final activeCount = DownloadStateManager.instance.activeTasks.length;
              return IconButton(
                onPressed: widget.onNavigateToDownloads,
                icon: Badge(
                  isLabelVisible: activeCount > 0,
                  label: Text('$activeCount'),
                  child: const Icon(Icons.downloading_rounded),
                ),
                tooltip: 'Downloads',
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Liquid Glass URL Input Bar
              LiquidGlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                borderRadius: AppShapes.large,
                child: Row(
                  children: [
                    Icon(Icons.link_rounded, color: colorScheme.primary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        focusNode: _urlFocusNode,
                        style: theme.textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'Paste media URL, playlist or search...',
                          hintStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant.withAlpha(160),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: _extractMedia,
                      ),
                    ),
                    if (_urlController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () {
                          _urlController.clear();
                          setState(() {
                            _extractedMedia = null;
                            _extractedPlaylist = null;
                          });
                        },
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.content_paste_rounded, size: 20),
                        tooltip: 'Paste from clipboard',
                        onPressed: _pasteFromClipboard,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Action button row
              FilledButton.icon(
                onPressed: _isExtracting
                    ? null
                    : () => _extractMedia(_urlController.text),
                icon: _isExtracting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bolt_rounded),
                label: Text(_isExtracting ? 'Analyzing streams...' : 'Inspect & Extract'),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Card(
                  color: colorScheme.errorContainer,
                  child: Padding(
                    padding: AppSpacing.cardPadding,
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: colorScheme.onErrorContainer),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Playlist Batch Extraction Card
              if (_extractedPlaylist != null) ...[
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Detected Playlist', style: theme.textTheme.titleMedium),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppShapes.extraSmall),
                      ),
                      child: Text(
                        '${_extractedPlaylist!.itemCount} VIDEOS',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  child: Padding(
                    padding: AppSpacing.cardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(AppShapes.small),
                              ),
                              child: Icon(Icons.playlist_play_rounded, color: colorScheme.primary, size: 28),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_extractedPlaylist!.title, style: theme.textTheme.titleSmall),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    _extractedPlaylist!.uploader ?? 'Universal Creator',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          '${_selectedPlaylistEntryIds.length} of ${_extractedPlaylist!.entries.length} items selected for download.',
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _openPlaylistSelectionSheet,
                                icon: const Icon(Icons.checklist_rounded, size: 18),
                                label: const Text('Select Items'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _selectedPlaylistEntryIds.isEmpty
                                    ? null
                                    : _startPlaylistBatchDownload,
                                icon: const Icon(Icons.download_rounded, size: 18),
                                label: Text('Batch Download (${_selectedPlaylistEntryIds.length})'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Extracted Media Surface
              if (_extractedMedia != null && _recommendation != null) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Extracted Media Stream',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  child: Padding(
                    padding: AppSpacing.cardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Media Header
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppShapes.small),
                              child: Container(
                                width: 90,
                                height: 60,
                                color: colorScheme.surfaceContainerHighest,
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Center(
                                      child: Icon(
                                        Icons.movie_outlined,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      margin: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withAlpha(180),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '05:45',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _extractedMedia!.title,
                                    style: theme.textTheme.titleSmall,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    _extractedMedia!.uploader ?? 'Universal Creator',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Quality Mode SegmentedButton
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<QualityPreference>(
                            segments: const [
                              ButtonSegment(
                                value: QualityPreference.auto,
                                label: Text('Optimal'),
                                icon: Icon(Icons.auto_awesome, size: 16),
                              ),
                              ButtonSegment(
                                value: QualityPreference.maximumQuality,
                                label: Text('Maximum'),
                              ),
                              ButtonSegment(
                                value: QualityPreference.audioOnly,
                                label: Text('Audio'),
                              ),
                            ],
                            selected: {_qualityPreference},
                            onSelectionChanged: (set) => _onPreferenceChanged(set.first),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Intelligent Recommendation Details
                        Container(
                          padding: AppSpacing.compactCardPadding,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(AppShapes.small),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: colorScheme.primary, size: 20),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _recommendation!.reasoning,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xxs),
                                    Text(
                                      'Target: ${_recommendation!.targetExtension.toUpperCase()} • Direct Stream Copy: ${_recommendation!.directStreamCopyPossible ? "Yes" : "Mux required"}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: _openFormatSelectionSheet,
                                child: const Text('Change'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Primary Download Button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _startDownload,
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Download Stream'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
