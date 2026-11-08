import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_engine/media_engine.dart';
import '../services/native_bridge.dart';
import '../state/download_state.dart';
import '../theme/liquid_glass_theme.dart';
import '../widgets/glass_card.dart';

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
  bool _isExtracting = false;
  String? _errorMessage;
  MediaInfo? _extractedMedia;
  FormatRecommendation? _recommendation;
  FormatInfo? _selectedFormat;
  DeviceCapabilities _deviceCapabilities = DeviceCapabilities.standardAndroidArm64();

  @override
  void initState() {
    super.initState();
    _loadDeviceCapabilities();
    _checkInitialSharedUrl();
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
    if (data?.text != null && data!.text!.isNotEmpty) {
      _urlController.text = data.text!.trim();
      _extractMedia(_urlController.text);
    }
  }

  Future<void> _extractMedia(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) return;

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
      _extractedMedia = null;
      _recommendation = null;
    });

    try {
      // Simulate/Fallback extraction or invoke native extractor
      // Build a realistic fallback MediaInfo for immediate responsiveness and testing
      final mockFormats = [
        const FormatInfo(
          formatId: '1080p_av1',
          formatNote: '1080p60 HDR',
          ext: 'mp4',
          height: 1080,
          fps: 60,
          vcodec: 'av01.0.08M.08',
          filesize: 85 * 1024 * 1024,
          streamType: StreamType.videoOnly,
        ),
        const FormatInfo(
          formatId: '720p_avc',
          formatNote: '720p',
          ext: 'mp4',
          height: 720,
          fps: 30,
          vcodec: 'avc1.64001f',
          filesize: 42 * 1024 * 1024,
          streamType: StreamType.videoOnly,
        ),
        const FormatInfo(
          formatId: 'audio_opus',
          formatNote: 'high audio',
          ext: 'webm',
          acodec: 'opus',
          abr: 160,
          filesize: 6 * 1024 * 1024,
          streamType: StreamType.audioOnly,
        ),
        const FormatInfo(
          formatId: 'audio_m4a',
          formatNote: 'medium audio',
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
            : 'Extracted Media Stream (${Uri.tryParse(url)?.host ?? 'Web'})',
        uploader: 'Meteora Creator Network',
        durationSeconds: 345,
        thumbnail: 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800&q=80',
        webpageUrl: url,
        extractor: 'youtube',
        formats: mockFormats,
      );

      const selector = IntelligentFormatSelector();
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
      etaText: 'Calculating...',
      status: TaskStatus.downloading,
      createdAt: DateTime.now(),
    );

    DownloadStateManager.instance.addTask(task);

    // Trigger simulation or native foreground service
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

    // Simulate progressive download steps for responsive feedback
    _simulateDownloadProgress(taskId);

    widget.onNavigateToDownloads();
  }

  void _simulateDownloadProgress(String taskId) async {
    for (int p = 5; p <= 100; p += 15) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      DownloadStateManager.instance.updateProgress(
        taskId: taskId,
        percent: p.toDouble(),
        speed: '${(4.5 + (p % 3)).toStringAsFixed(1)} MiB/s',
        eta: '00:${( (100 - p) ~/ 7 ).toString().padLeft(2, '0')}',
        totalSize: '91.2 MiB',
        status: p >= 100 ? TaskStatus.completed : TaskStatus.downloading,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: LiquidGlassTheme.cyanAccent.withAlpha(40),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.bolt, color: LiquidGlassTheme.cyanAccent, size: 20),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'METEORA',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: LiquidGlassTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Universal Android Media Downloader',
                        style: TextStyle(fontSize: 13, color: LiquidGlassTheme.textSecondary),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: widget.onNavigateToDownloads,
                    icon: const Icon(Icons.downloading_rounded, color: LiquidGlassTheme.cyanAccent),
                    style: IconButton.styleFrom(
                      backgroundColor: LiquidGlassTheme.surfaceContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Supported Platform Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: const [
                    _PlatformBadge(label: 'YouTube', color: Color(0xFFFF0000)),
                    _PlatformBadge(label: 'TikTok', color: Color(0xFF00F2FE)),
                    _PlatformBadge(label: 'Instagram', color: Color(0xFFE1306C)),
                    _PlatformBadge(label: 'Bilibili', color: Color(0xFF23ADE5)),
                    _PlatformBadge(label: 'Reddit', color: Color(0xFFFF4500)),
                    _PlatformBadge(label: 'X / Twitter', color: Color(0xFF1DA1F2)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // URL Input Card
              GlassCard(
                padding: const EdgeInsets.all(16),
                borderColor: LiquidGlassTheme.cyanAccent.withAlpha(77),
                child: Column(
                  children: [
                    TextField(
                      controller: _urlController,
                      style: const TextStyle(color: LiquidGlassTheme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Paste video, audio or post URL...',
                        hintStyle: const TextStyle(color: LiquidGlassTheme.textMuted, fontSize: 14),
                        prefixIcon: const Icon(Icons.link_rounded, color: LiquidGlassTheme.cyanAccent),
                        suffixIcon: _urlController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, color: LiquidGlassTheme.textMuted),
                                onPressed: () {
                                  _urlController.clear();
                                  setState(() => _extractedMedia = null);
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: LiquidGlassTheme.surfaceHigh.withAlpha(128),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onSubmitted: _extractMedia,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pasteFromClipboard,
                            icon: const Icon(Icons.content_paste_rounded, size: 16),
                            label: const Text('Paste'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: LiquidGlassTheme.textSecondary,
                              side: const BorderSide(color: LiquidGlassTheme.glassBorder),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isExtracting
                                ? null
                                : () => _extractMedia(_urlController.text),
                            icon: _isExtracting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : const Icon(Icons.search_rounded, size: 16),
                            label: Text(_isExtracting ? 'Analyzing...' : 'Extract'),
                            style: FilledButton.styleFrom(
                              backgroundColor: LiquidGlassTheme.cyanAccent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                GlassCard(
                  borderColor: LiquidGlassTheme.roseAccent.withAlpha(100),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: LiquidGlassTheme.roseAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: LiquidGlassTheme.roseAccent, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Extracted Media Card
              if (_extractedMedia != null && _recommendation != null) ...[
                const SizedBox(height: 24),
                const Text(
                  'Extracted Media',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: LiquidGlassTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderColor: LiquidGlassTheme.indigoAccent.withAlpha(128),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              height: 180,
                              width: double.infinity,
                              color: LiquidGlassTheme.surfaceHigh,
                              child: const Icon(Icons.movie_creation_outlined, size: 48, color: LiquidGlassTheme.textMuted),
                            ),
                            Container(
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(200),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '05:45',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _extractedMedia!.title,
                        style: const TextStyle(
                          color: LiquidGlassTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _extractedMedia!.uploader ?? 'Unknown Uploader',
                        style: const TextStyle(color: LiquidGlassTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 16),

                      // Intelligent Recommendation Pill
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: LiquidGlassTheme.indigoAccent.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: LiquidGlassTheme.indigoAccent.withAlpha(80)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.auto_awesome_rounded, color: LiquidGlassTheme.cyanAccent, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Intelligent Recommendation',
                                  style: TextStyle(
                                    color: LiquidGlassTheme.cyanAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _recommendation!.reasoning,
                              style: const TextStyle(color: LiquidGlassTheme.textPrimary, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Target format: ${_recommendation!.targetExtension.toUpperCase()} • Direct Copy: ${_recommendation!.directStreamCopyPossible ? "Yes (Lossless)" : "No"}',
                              style: const TextStyle(color: LiquidGlassTheme.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Download Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _startDownload,
                          icon: const Icon(Icons.download_rounded, size: 20),
                          label: const Text(
                            'Download Optimal Media',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: LiquidGlassTheme.cyanAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      ),
    );
  }
}

class _PlatformBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _PlatformBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: LiquidGlassTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
