import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_engine/media_engine.dart';
import 'package:package_manager/package_manager.dart';
import 'package:path_provider/path_provider.dart';
import '../services/direct_media_engine.dart';
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
  bool _isInstallingEngine = false;
  bool _engineInstalled = false;
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
    _checkEngineStatus();
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

  Future<void> _checkEngineStatus() async {
    final installed = await NativeBridge.isEngineInstalled();
    if (mounted) {
      setState(() => _engineInstalled = installed);
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

  Future<Map<String, dynamic>?> _fetchOEmbedMetadata(String url) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final oembedUri = Uri.parse(
        'https://www.youtube.com/oembed?url=${Uri.encodeComponent(url)}&format=json',
      );
      final request = await client.getUrl(oembedUri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _installEngineNow() async {
    setState(() {
      _isInstallingEngine = true;
      _errorMessage = null;
    });

    try {
      final client = GitHubReleaseClient();
      final release = await client.fetchLatestRelease(
        packageType: PackageType.ytdlp,
        targetAbi: 'arm64-v8a',
        channel: UpdateChannel.stable,
      );

      if (release != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final dirManager = AtomicDirectoryManager(rootPackagesDir: '${appDir.path}/packages');
        final updateManager = PackageUpdateManager(directoryManager: dirManager);

        final result = await updateManager.installPackage(release: release);
        if (result.success && mounted) {
          setState(() {
            _engineInstalled = true;
            _isInstallingEngine = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('yt-dlp engine installed successfully! Extracting streams...')),
          );
          if (_urlController.text.isNotEmpty) {
            _extractMedia(_urlController.text);
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isInstallingEngine = false;
          _errorMessage = 'Could not download yt-dlp release. Check internet connection or configure in Settings.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInstallingEngine = false;
          _errorMessage = 'Installation error: $e';
        });
      }
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
      // 1. Direct Media Extraction Engine (Fast, native Dart stream resolution)
      if (DirectMediaEngine.instance.isSupported(url)) {
        try {
          if (url.contains('list=') || url.contains('/playlist')) {
            final playlist = await DirectMediaEngine.instance.extractPlaylist(url);
            if (playlist != null && playlist.entries.isNotEmpty && mounted) {
              setState(() {
                _extractedPlaylist = playlist;
                _selectedPlaylistEntryIds.clear();
                _selectedPlaylistEntryIds.addAll(playlist.entries.map((e) => e.id));
                _isExtracting = false;
              });
              return;
            }
          }

          final media = await DirectMediaEngine.instance.extractVideo(url);
          if (media != null && mounted) {
            final selector = IntelligentFormatSelector(preference: _qualityPreference);
            final rec = selector.recommendFormat(media: media, device: _deviceCapabilities);

            setState(() {
              _extractedMedia = media;
              _recommendation = rec;
              _selectedFormat = rec.videoFormat ?? (media.formats.isNotEmpty ? media.formats.first : null);
              _isExtracting = false;
            });
            return;
          }
        } catch (_) {
          // Network unavailable or in widget test: fall through to native process engine / mock channel
        }
      }

      // 2. Native Process-Based yt-dlp Extraction
      await _checkEngineStatus();
      if (_engineInstalled) {
        final command = [
          'yt-dlp',
          '--dump-single-json',
          '--no-warnings',
          '--no-call-home',
          '--skip-download',
          url,
        ];

        final rawJson = await NativeBridge.executeExtraction(command);
        if (rawJson != null && rawJson.trim().isNotEmpty) {
          final Map<String, dynamic> json = jsonDecode(rawJson);

          if (json['_type'] == 'playlist') {
            final playlist = PlaylistInfo.fromJson(json);
            if (mounted) {
              setState(() {
                _extractedPlaylist = playlist;
                _selectedPlaylistEntryIds.clear();
                _selectedPlaylistEntryIds.addAll(playlist.entries.map((e) => e.id));
                _isExtracting = false;
              });
            }
            return;
          }

          final media = MediaInfo.fromJson(json);
          final selector = IntelligentFormatSelector(preference: _qualityPreference);
          final rec = selector.recommendFormat(media: media, device: _deviceCapabilities);

          if (mounted) {
            setState(() {
              _extractedMedia = media;
              _recommendation = rec;
              _selectedFormat = rec.videoFormat ?? (media.formats.isNotEmpty ? media.formats.first : null);
              _isExtracting = false;
            });
          }
          return;
        }
      }

      // 3. Fallback to oEmbed metadata preview if available
      final oembed = await _fetchOEmbedMetadata(url);
      if (oembed != null) {
        final title = (oembed['title'] ?? 'Online Media Stream').toString();
        final author = (oembed['author_name'] ?? 'Web Publisher').toString();
        final thumb = (oembed['thumbnail_url'] ?? '').toString();

        final fallbackMedia = MediaInfo(
          id: 'web_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          uploader: author,
          thumbnail: thumb.isNotEmpty ? thumb : null,
          webpageUrl: url,
          formats: const [],
        );

        if (mounted) {
          setState(() {
            _extractedMedia = fallbackMedia;
            _engineInstalled = false;
            _isExtracting = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isExtracting = false;
          _errorMessage = 'Could not extract media info for "$url". Verify the URL or install the yt-dlp engine.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isExtracting = false;
        });
      }
    }
  }

  void _onPreferenceChanged(QualityPreference pref) {
    if (_qualityPreference == pref || _extractedMedia == null) return;
    setState(() {
      _qualityPreference = pref;
      if (_extractedMedia!.formats.isNotEmpty) {
        final selector = IntelligentFormatSelector(preference: pref);
        _recommendation = selector.recommendFormat(media: _extractedMedia!, device: _deviceCapabilities);
        _selectedFormat = _recommendation?.videoFormat ?? _extractedMedia!.formats.first;
      }
    });
  }

  void _startDownload() {
    if (_extractedMedia == null) return;

    final taskId = 'task_${DateTime.now().millisecondsSinceEpoch}';
    final formatLabel = _selectedFormat?.resolutionLabel ?? _recommendation?.reasoning ?? 'Default Stream';
    final targetUrl = _urlController.text.trim();

    final task = DownloadTask(
      taskId: taskId,
      url: targetUrl,
      title: _extractedMedia!.title,
      thumbnailUrl: _extractedMedia!.thumbnail,
      formatLabel: formatLabel,
      progressPercent: 0.0,
      speedText: 'Connecting...',
      etaText: 'Starting...',
      status: TaskStatus.downloading,
      createdAt: DateTime.now(),
    );

    DownloadStateManager.instance.addTask(task);

    // If DirectMediaEngine supports this URL, download actual media byte streams directly
    if (DirectMediaEngine.instance.isSupported(targetUrl)) {
      DirectMediaEngine.instance.startDownload(
        taskId: taskId,
        videoUrl: targetUrl,
        title: _extractedMedia!.title,
        thumbnailUrl: _extractedMedia!.thumbnail,
        formatId: _selectedFormat?.formatId ?? 'muxed',
        formatLabel: formatLabel,
      );
    } else {
      // Dispatch to native Kotlin foreground service with yt-dlp
      NativeBridge.startForegroundDownload(
        taskId: taskId,
        title: task.title,
        command: [
          'yt-dlp',
          '--no-warnings',
          if (_recommendation != null) ...[
            '-f', _recommendation!.ytdlpFormatSelector,
          ],
          targetUrl,
        ],
      );
    }

    widget.onNavigateToDownloads();
  }

  void _startPlaylistBatchDownload() {
    if (_extractedPlaylist == null || _selectedPlaylistEntryIds.isEmpty) return;

    final selectedEntries = _extractedPlaylist!.entries
        .where((e) => _selectedPlaylistEntryIds.contains(e.id))
        .toList();

    for (final entry in selectedEntries) {
      final taskId = 'task_${entry.id}_${DateTime.now().millisecondsSinceEpoch}';
      final formatLabel = _qualityPreference == QualityPreference.audioOnly ? 'Audio' : 'Optimal Video';

      final task = DownloadTask(
        taskId: taskId,
        url: entry.url,
        title: entry.title,
        thumbnailUrl: entry.thumbnail,
        formatLabel: formatLabel,
        progressPercent: 0.0,
        speedText: 'Queued',
        etaText: 'Waiting',
        status: TaskStatus.downloading,
        createdAt: DateTime.now(),
      );

      DownloadStateManager.instance.addTask(task);

      if (DirectMediaEngine.instance.isSupported(entry.url)) {
        DirectMediaEngine.instance.startDownload(
          taskId: taskId,
          videoUrl: entry.url,
          title: entry.title,
          thumbnailUrl: entry.thumbnail,
          formatId: _qualityPreference == QualityPreference.audioOnly ? 'audio' : 'muxed',
          formatLabel: formatLabel,
        );
      } else {
        NativeBridge.startForegroundDownload(
          taskId: taskId,
          title: entry.title,
          command: [
            'yt-dlp',
            '--no-warnings',
            entry.url,
          ],
        );
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Enqueued ${selectedEntries.length} items from "${_extractedPlaylist!.title}"'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    widget.onNavigateToDownloads();
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
    if (_extractedMedia == null || _extractedMedia!.formats.isEmpty) return;

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

              // Engine Installation Banner (shown if local binary is missing and link requires it)
              if (!_engineInstalled) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: AppSpacing.cardPadding,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppShapes.medium),
                    border: Border.all(color: colorScheme.outlineVariant.withAlpha(120)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.hardware_rounded, color: colorScheme.primary, size: 22),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'yt-dlp Extractor Engine Required for Other Sites',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'YouTube downloads work directly. To download from Instagram, Twitter/X, TikTok, and Bilibili, install the yt-dlp binary into app storage.',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: _isInstallingEngine ? null : _installEngineNow,
                          icon: _isInstallingEngine
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download_rounded, size: 18),
                          label: Text(_isInstallingEngine ? 'Installing yt-dlp engine...' : 'Install yt-dlp Extractor Engine'),
                        ),
                      ),
                    ],
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
              if (_extractedMedia != null) ...[
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
                                child: _extractedMedia!.thumbnail != null && _extractedMedia!.thumbnail!.isNotEmpty
                                    ? Image.network(
                                        _extractedMedia!.thumbnail!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, _, __) => Center(
                                          child: Icon(Icons.movie_outlined, color: colorScheme.onSurfaceVariant),
                                        ),
                                      )
                                    : Center(
                                        child: Icon(Icons.movie_outlined, color: colorScheme.onSurfaceVariant),
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
                                    _extractedMedia!.uploader ?? 'Web Publisher',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        if (_extractedMedia!.formats.isNotEmpty && _recommendation != null) ...[
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
                        ],

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
