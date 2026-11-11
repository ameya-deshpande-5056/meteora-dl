import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_engine/media_engine.dart';
import 'package:package_manager/package_manager.dart';
import 'package:path_provider/path_provider.dart';
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();

  bool _isExtracting = false;
  bool _isInstallingEngine = false;
  bool _engineInstalled = false;
  String? _errorMessage;
  MediaInfo? _extractedMedia;
  PlaylistInfo? _extractedPlaylist;
  final Set<String> _selectedPlaylistEntryIds = {};
  DownloadMode _downloadMode = DownloadMode.videoAudioSubtitles;
  FormatInfo? _selectedVideoFormat;
  FormatInfo? _selectedAudioFormat;
  final List<SubtitleTrackInfo> _selectedSubtitles = [];
  String? _lastDetectedClipboardUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkEngineStatus();
    _checkInitialSharedUrl();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkInitialSharedUrl();
      _checkClipboardOnResume();
    }
  }

  Future<void> _checkClipboardOnResume() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text != null &&
          (text.startsWith('http://') || text.startsWith('https://')) &&
          text != _lastDetectedClipboardUrl &&
          text != _urlController.text) {
        _lastDetectedClipboardUrl = text;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Link detected on clipboard: ${text.length > 35 ? "${text.substring(0, 35)}..." : text}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Inspect',
              onPressed: () {
                _urlController.text = text;
                _extractMedia(text);
              },
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (_) {}
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
      _selectedVideoFormat = null;
      _selectedAudioFormat = null;
      _selectedSubtitles.clear();
    });

    try {
      // Native yt-dlp Extraction (Powered by embedded Python & FFmpeg)
      await _checkEngineStatus();
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
        final videoFormats = media.selectableVideoFormats;
        final audioFormats = media.selectableAudioFormats;
        final creatorSubs = media.availableSubtitleTracks.where((t) => !t.isAutoGenerated).toList();

        if (mounted) {
          setState(() {
            _extractedMedia = media;
            _selectedVideoFormat = videoFormats.isNotEmpty ? videoFormats.first : null;
            _selectedAudioFormat = audioFormats.isNotEmpty ? audioFormats.first : null;
            _selectedSubtitles
              ..clear()
              ..addAll(creatorSubs);
            if (_downloadMode == DownloadMode.subtitlesOnly && !media.hasAnySubtitles) {
              _downloadMode = DownloadMode.videoAudioSubtitles;
            }
            _isExtracting = false;
          });
        }
        return;
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

  void _startDownload() {
    if (_extractedMedia == null) return;

    final taskId = 'task_${DateTime.now().millisecondsSinceEpoch}';
    final effectiveVideo = (_downloadMode == DownloadMode.videoAudioSubtitles ||
            _downloadMode == DownloadMode.videoOnly)
        ? _selectedVideoFormat
        : null;
    final effectiveAudio = (_downloadMode == DownloadMode.videoAudioSubtitles ||
            _downloadMode == DownloadMode.audioOnly)
        ? _selectedAudioFormat
        : null;
    final effectiveSubs = _downloadMode == DownloadMode.audioOnly
        ? const <SubtitleTrackInfo>[]
        : List<SubtitleTrackInfo>.unmodifiable(_selectedSubtitles);

    final formatLabel = SimpleDownloadCommandBuilder.formatLabelFor(
      _downloadMode,
      media: _extractedMedia,
      selectedVideo: effectiveVideo,
      selectedAudio: effectiveAudio,
      selectedSubtitles: effectiveSubs,
    );
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

    final command = SimpleDownloadCommandBuilder.buildCommand(
      url: targetUrl,
      mode: _downloadMode,
      media: _extractedMedia,
      selectedVideo: effectiveVideo,
      selectedAudio: effectiveAudio,
      selectedSubtitles: effectiveSubs,
    );

    // Dispatch directly to native Android foreground service powered by embedded yt-dlp & FFmpeg
    NativeBridge.startForegroundDownload(
      taskId: taskId,
      title: task.title,
      command: command,
    );

    widget.onNavigateToDownloads();
  }

  void _startPlaylistBatchDownload() {
    if (_extractedPlaylist == null || _selectedPlaylistEntryIds.isEmpty) return;

    final selectedEntries = _extractedPlaylist!.entries
        .where((e) => _selectedPlaylistEntryIds.contains(e.id))
        .toList();

    for (final entry in selectedEntries) {
      final taskId = 'task_${entry.id}_${DateTime.now().millisecondsSinceEpoch}';
      final formatLabel = SimpleDownloadCommandBuilder.formatLabelFor(_downloadMode);

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

      NativeBridge.startForegroundDownload(
        taskId: taskId,
        title: entry.title,
        command: SimpleDownloadCommandBuilder.buildCommand(
          url: entry.url,
          mode: _downloadMode,
        ),
      );
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
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            final allSelected = _selectedPlaylistEntryIds.length == _extractedPlaylist!.entries.length;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: LiquidGlassContainer(
                  padding: AppSpacing.cardPadding,
                  borderRadius: AppShapes.extraLarge,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.72,
                    ),
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
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onDownloadModeChanged(DownloadMode mode, MediaInfo media) {
    setState(() {
      _downloadMode = mode;
      if ((mode == DownloadMode.videoAudioSubtitles || mode == DownloadMode.videoOnly) &&
          _selectedVideoFormat == null &&
          media.selectableVideoFormats.isNotEmpty) {
        _selectedVideoFormat = media.selectableVideoFormats.first;
      }
      if ((mode == DownloadMode.videoAudioSubtitles || mode == DownloadMode.audioOnly) &&
          _selectedAudioFormat == null &&
          media.selectableAudioFormats.isNotEmpty) {
        _selectedAudioFormat = media.selectableAudioFormats.first;
      }
      if (mode == DownloadMode.subtitlesOnly &&
          _selectedSubtitles.isEmpty &&
          media.availableSubtitleTracks.isNotEmpty) {
        _selectedSubtitles.add(media.availableSubtitleTracks.first);
      }
    });
  }

  void _openVideoFormatSheet(MediaInfo media) {
    final formats = media.selectableVideoFormats;
    if (formats.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            child: LiquidGlassContainer(
              padding: AppSpacing.cardPadding,
              borderRadius: AppShapes.extraLarge,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.65,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Video Resolution & Codec', style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Pick quality, framerate, and codec for this video.',
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const Divider(height: AppSpacing.lg),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: formats.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final fmt = formats[index];
                          final isSelected = _selectedVideoFormat?.formatId == fmt.formatId;
                          final bitrateText = fmt.vbr != null
                              ? '${fmt.vbr!.round()} kbps'
                              : (fmt.tbr != null ? '${fmt.tbr!.round()} kbps' : null);
                          final subtitleText = [
                            if (bitrateText != null) bitrateText,
                            if (fmt.streamType == StreamType.combined) '+Audio',
                          ].join(' • ');

                          return InkWell(
                            borderRadius: BorderRadius.circular(AppShapes.small),
                            onTap: () {
                              setState(() => _selectedVideoFormat = fmt);
                              Navigator.pop(sheetContext);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    constraints: const BoxConstraints(minWidth: 74),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? colorScheme.primaryContainer
                                          : colorScheme.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(AppShapes.small),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      fmt.resolutionLabel,
                                      maxLines: 1,
                                      softWrap: false,
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? colorScheme.onPrimaryContainer
                                            : colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${fmt.displayVideoCodec} • ${fmt.ext.toUpperCase()}',
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.fade,
                                          style: theme.textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (subtitleText.isNotEmpty)
                                          Text(
                                            subtitleText,
                                            maxLines: 1,
                                            softWrap: false,
                                            overflow: TextOverflow.fade,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  if (fmt.formattedSize.isNotEmpty) ...[
                                    Text(
                                      fmt.formattedSize,
                                      maxLines: 1,
                                      softWrap: false,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                  ],
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
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openAudioFormatSheet(MediaInfo media) {
    final formats = media.selectableAudioFormats;
    if (formats.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            child: LiquidGlassContainer(
              padding: AppSpacing.cardPadding,
              borderRadius: AppShapes.extraLarge,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Audio Bitrate & Codec', style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Select audio quality and codec.',
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const Divider(height: AppSpacing.lg),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: formats.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final fmt = formats[index];
                          final isSelected = _selectedAudioFormat?.formatId == fmt.formatId;
                          final bitrateNum = fmt.abr ?? (fmt.streamType == StreamType.audioOnly ? fmt.tbr : null);
                          final badgeTextColor = isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface;
                          final subtitleParts = [
                            if (fmt.asr != null) '${(fmt.asr! / 1000).toStringAsFixed(1)} kHz',
                            if (fmt.language != null && fmt.language!.isNotEmpty)
                              fmt.language!.toUpperCase(),
                            if (fmt.formatNote.isNotEmpty) fmt.formatNote,
                          ];

                          return InkWell(
                            borderRadius: BorderRadius.circular(AppShapes.small),
                            onTap: () {
                              setState(() => _selectedAudioFormat = fmt);
                              Navigator.pop(sheetContext);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    constraints: const BoxConstraints(minWidth: 64),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? colorScheme.primaryContainer
                                          : colorScheme.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(AppShapes.small),
                                    ),
                                    alignment: Alignment.center,
                                    child: bitrateNum != null && bitrateNum > 0
                                        ? Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${bitrateNum.round()}',
                                                maxLines: 1,
                                                softWrap: false,
                                                style: theme.textTheme.labelLarge?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.1,
                                                  color: badgeTextColor,
                                                ),
                                              ),
                                              Text(
                                                'kbps',
                                                maxLines: 1,
                                                softWrap: false,
                                                style: theme.textTheme.labelSmall?.copyWith(
                                                  height: 1.1,
                                                  color: badgeTextColor.withAlpha(200),
                                                ),
                                              ),
                                            ],
                                          )
                                        : Text(
                                            fmt.audioBitrateLabel,
                                            maxLines: 1,
                                            softWrap: false,
                                            style: theme.textTheme.labelMedium?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: badgeTextColor,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${fmt.displayAudioCodec} • ${fmt.ext.toUpperCase()}',
                                          maxLines: 1,
                                          softWrap: false,
                                          style: theme.textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (subtitleParts.isNotEmpty)
                                          Text(
                                            subtitleParts.join(' • '),
                                            style: theme.textTheme.bodySmall,
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  if (fmt.formattedSize.isNotEmpty) ...[
                                    Text(
                                      fmt.formattedSize,
                                      maxLines: 1,
                                      softWrap: false,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                  ],
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
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openSubtitlePickerSheet(MediaInfo media) {
    final tracks = media.availableSubtitleTracks;
    if (tracks.isEmpty) return;

    final tempSelected = List<SubtitleTrackInfo>.from(_selectedSubtitles);
    var filterQuery = '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);
            final visibleTracks = filterQuery.isEmpty
                ? tracks
                : tracks.where((t) {
                    final q = filterQuery.toLowerCase();
                    return t.displayLabel.toLowerCase().contains(q) ||
                        t.code.toLowerCase().contains(q);
                  }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.md,
                ),
                child: LiquidGlassContainer(
                  padding: AppSpacing.cardPadding,
                  borderRadius: AppShapes.extraLarge,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Subtitle Languages', style: theme.textTheme.titleMedium),
                            TextButton(
                              onPressed: () {
                                setSheetState(() => tempSelected.clear());
                              },
                              child: const Text('None'),
                            ),
                          ],
                        ),
                        if (tracks.length > 8) ...[
                          const SizedBox(height: AppSpacing.xs),
                          TextField(
                            decoration: const InputDecoration(
                              hintText: 'Filter languages...',
                              prefixIcon: Icon(Icons.search_rounded, size: 18),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (val) => setSheetState(() => filterQuery = val),
                          ),
                        ],
                        const Divider(height: AppSpacing.md),
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: visibleTracks.length,
                            itemBuilder: (_, index) {
                              final track = visibleTracks[index];
                              final checked = tempSelected.contains(track);
                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: checked,
                                title: Text(track.displayLabel),
                                subtitle: Text(
                                  track.isAutoGenerated ? 'Auto-generated captions' : 'Creator subtitles',
                                  style: theme.textTheme.bodySmall,
                                ),
                                onChanged: (val) {
                                  setSheetState(() {
                                    if (val == true) {
                                      if (!tempSelected.contains(track)) tempSelected.add(track);
                                    } else {
                                      tempSelected.remove(track);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _selectedSubtitles
                                ..clear()
                                ..addAll(tempSelected);
                            });
                            Navigator.pop(sheetContext);
                          },
                          child: Text(
                            tempSelected.isEmpty
                                ? 'Done (No Subtitles)'
                                : 'Apply (${tempSelected.length} selected)',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStreamOptionRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final enabled = onTap != null;

    return Material(
      color: colorScheme.surfaceContainerHigh.withAlpha(185),
      borderRadius: BorderRadius.circular(AppShapes.medium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppShapes.medium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: enabled ? colorScheme.primary : colorScheme.onSurface.withAlpha(90),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: enabled ? null : colorScheme.onSurface.withAlpha(110),
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled)
                Icon(
                  Icons.unfold_more_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadModeSelector(BuildContext context, MediaInfo media) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasFormats = media.formats.isNotEmpty;
    final subsAvailable = !hasFormats || media.hasAnySubtitles;
    final videoFormats = media.selectableVideoFormats;
    final audioFormats = media.selectableAudioFormats;
    final subTracks = media.availableSubtitleTracks;

    final showVideoRow = _downloadMode == DownloadMode.videoAudioSubtitles ||
        _downloadMode == DownloadMode.videoOnly;
    final showAudioRow = _downloadMode == DownloadMode.videoAudioSubtitles ||
        _downloadMode == DownloadMode.audioOnly;
    final showSubsRow = _downloadMode != DownloadMode.audioOnly;

    final videoValue = _selectedVideoFormat != null
        ? _selectedVideoFormat!.videoSelectionLabel
        : 'Best available';

    final String audioValue;
    final bool canPickAudio;
    if (_downloadMode == DownloadMode.videoAudioSubtitles &&
        _selectedVideoFormat?.streamType == StreamType.combined &&
        media.audioOnlyFormats.isEmpty) {
      audioValue = 'Included (${_selectedVideoFormat!.displayAudioCodec})';
      canPickAudio = false;
    } else if (_selectedAudioFormat != null) {
      audioValue = _selectedAudioFormat!.audioSelectionLabel;
      canPickAudio = audioFormats.isNotEmpty;
    } else {
      audioValue = 'Best available';
      canPickAudio = audioFormats.isNotEmpty;
    }

    final String subsValue;
    if (!subsAvailable) {
      subsValue = 'No subtitles available';
    } else if (subTracks.isEmpty) {
      subsValue = 'If available';
    } else if (_selectedSubtitles.isEmpty) {
      subsValue = 'None (${subTracks.length} available)';
    } else if (_selectedSubtitles.length == 1) {
      subsValue = _selectedSubtitles.first.displayLabel;
    } else {
      subsValue =
          '${_selectedSubtitles.length} selected (${_selectedSubtitles.map((s) => s.code).take(3).join(", ")}${_selectedSubtitles.length > 3 ? "…" : ""})';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Download Format',
          style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: DownloadMode.values.map((mode) {
            final isDisabled = mode == DownloadMode.subtitlesOnly && !subsAvailable;
            return ChoiceChip(
              label: Text(mode.label),
              selected: _downloadMode == mode,
              onSelected: isDisabled ? null : (_) => _onDownloadModeChanged(mode, media),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        if (showVideoRow) ...[
          _buildStreamOptionRow(
            context: context,
            icon: Icons.videocam_outlined,
            label: 'Video Resolution & Codec',
            value: videoValue,
            onTap: videoFormats.isNotEmpty ? () => _openVideoFormatSheet(media) : null,
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        if (showAudioRow) ...[
          _buildStreamOptionRow(
            context: context,
            icon: Icons.audiotrack_outlined,
            label: 'Audio Bitrate & Codec',
            value: audioValue,
            onTap: canPickAudio ? () => _openAudioFormatSheet(media) : null,
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        if (showSubsRow)
          _buildStreamOptionRow(
            context: context,
            icon: Icons.subtitles_outlined,
            label: 'Subtitles',
            value: subsValue,
            onTap: subTracks.isNotEmpty ? () => _openSubtitlePickerSheet(media) : null,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: LiquidGlassAppBar(
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
      body: LiquidGlassBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              MediaQuery.paddingOf(context).bottom + 96,
            ),
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
                        onChanged: (_) => setState(() {}),
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
                LiquidGlassContainer(
                  padding: AppSpacing.cardPadding,
                  borderRadius: AppShapes.large,
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
                LiquidGlassContainer(
                  padding: AppSpacing.cardPadding,
                  borderRadius: AppShapes.large,
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
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: DownloadMode.values.map((mode) {
                            return ChoiceChip(
                              label: Text(mode.label),
                              selected: _downloadMode == mode,
                              onSelected: (_) => setState(() => _downloadMode = mode),
                            );
                          }).toList(),
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
              ],

              // Extracted Media Surface
              if (_extractedMedia != null) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Extracted Media Stream',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                LiquidGlassContainer(
                  padding: AppSpacing.cardPadding,
                  borderRadius: AppShapes.large,
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

                        const SizedBox(height: AppSpacing.lg),

                        // Simple Download Options (Video+Audio+Subtitles / Video Only / Audio Only / Subtitles Only)
                        _buildDownloadModeSelector(context, _extractedMedia!),

                        const SizedBox(height: AppSpacing.md),

                        // Primary Download Button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _startDownload,
                            icon: const Icon(Icons.download_rounded),
                            label: Text('Download ${_downloadMode.label}'),
                          ),
                        ),
                    ],
                  ),
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
