import 'dart:math';
import '../models/device_capabilities.dart';
import '../models/format_info.dart';
import '../models/format_recommendation.dart';
import '../models/media_info.dart';

enum QualityPreference {
  auto,
  maximumQuality,
  dataSaver,
  audioOnly,
}

class IntelligentFormatSelector {
  final QualityPreference preference;

  const IntelligentFormatSelector({
    this.preference = QualityPreference.auto,
  });

  FormatRecommendation recommendFormat({
    required MediaInfo media,
    required DeviceCapabilities device,
  }) {
    if (media.formats.isEmpty) {
      return const FormatRecommendation(
        requiresMuxing: false,
        directStreamCopyPossible: false,
        estimatedSizeBytes: 0,
        reasoning: 'No formats available in media manifest',
        qualityScore: 0.0,
      );
    }

    if (preference == QualityPreference.audioOnly) {
      return _selectBestAudioOnly(media, device);
    }

    final combinedFormats = media.combinedFormats;
    final videoFormats = media.videoOnlyFormats;
    final audioFormats = media.audioOnlyFormats;

    // If only combined formats are available (common on Instagram, TikTok, Reddit)
    if (videoFormats.isEmpty && audioFormats.isEmpty && combinedFormats.isNotEmpty) {
      return _selectBestCombined(combinedFormats, device);
    }

    // Standard YouTube / complex extractor: pair video + audio streams
    return _pairOptimalVideoAndAudio(
      videoFormats: videoFormats.isNotEmpty ? videoFormats : combinedFormats,
      audioFormats: audioFormats,
      combinedFormats: combinedFormats,
      device: device,
    );
  }

  FormatRecommendation _selectBestAudioOnly(
    MediaInfo media,
    DeviceCapabilities device,
  ) {
    final audios = media.audioOnlyFormats;
    if (audios.isEmpty) {
      // Fallback to best combined if audio-only stream not split
      final combined = media.combinedFormats;
      if (combined.isNotEmpty) {
        combined.sort((a, b) => (b.abr ?? 0).compareTo(a.abr ?? 0));
        final best = combined.first;
        return FormatRecommendation(
          combinedFormat: best,
          requiresMuxing: false,
          directStreamCopyPossible: true,
          estimatedSizeBytes: best.estimatedSizeBytes ?? 0,
          reasoning: 'Extracted audio from combined stream',
          qualityScore: 80.0,
        );
      }
      return const FormatRecommendation(
        requiresMuxing: false,
        directStreamCopyPossible: false,
        estimatedSizeBytes: 0,
        reasoning: 'No audio streams found',
        qualityScore: 0.0,
      );
    }

    // Filter by supported audio codecs
    final compatibleAudios = audios.where((a) => device.supportsAudioCodec(a.acodec)).toList();
    final candidates = compatibleAudios.isNotEmpty ? compatibleAudios : audios;

    // Prefer Opus ~160kbps or AAC ~128-256kbps
    candidates.sort((a, b) {
      final aBitrate = a.abr ?? 0;
      final bBitrate = b.abr ?? 0;
      return bBitrate.compareTo(aBitrate);
    });

    final selected = candidates.first;
    return FormatRecommendation(
      audioFormat: selected,
      requiresMuxing: false,
      directStreamCopyPossible: true,
      estimatedSizeBytes: selected.estimatedSizeBytes ?? 0,
      reasoning: 'High-fidelity audio stream (${selected.acodec ?? selected.ext}, ${selected.abr?.round() ?? 128} kbps)',
      qualityScore: 90.0,
    );
  }

  FormatRecommendation _selectBestCombined(
    List<FormatInfo> formats,
    DeviceCapabilities device,
  ) {
    final compatible = formats.where((f) {
      final vOk = device.supportsVideoCodec(f.vcodec);
      final aOk = device.supportsAudioCodec(f.acodec);
      return vOk && aOk;
    }).toList();

    final candidates = compatible.isNotEmpty ? compatible : formats;

    candidates.sort((a, b) {
      final aHeight = a.height ?? 0;
      final bHeight = b.height ?? 0;
      if (aHeight != bHeight) return bHeight.compareTo(aHeight);
      return (b.tbr ?? 0).compareTo(a.tbr ?? 0);
    });

    final best = candidates.first;
    return FormatRecommendation(
      combinedFormat: best,
      requiresMuxing: false,
      directStreamCopyPossible: true,
      estimatedSizeBytes: best.estimatedSizeBytes ?? 0,
      reasoning: 'Pre-muxed standalone stream (${best.resolutionLabel}, ${best.vcodec}/${best.acodec})',
      qualityScore: 85.0,
    );
  }

  FormatRecommendation _pairOptimalVideoAndAudio({
    required List<FormatInfo> videoFormats,
    required List<FormatInfo> audioFormats,
    required List<FormatInfo> combinedFormats,
    required DeviceCapabilities device,
  }) {
    // 1. Determine target resolution constraint
    final maxAllowedHeight = _calculateMaxTargetHeight(device);

    // 2. Score candidate video formats
    FormatInfo? bestVideo;
    double bestVideoScore = -1.0;

    for (final video in videoFormats) {
      final score = _scoreVideoFormat(video, device, maxAllowedHeight);
      if (score > bestVideoScore) {
        bestVideoScore = score;
        bestVideo = video;
      }
    }

    if (bestVideo == null && combinedFormats.isNotEmpty) {
      return _selectBestCombined(combinedFormats, device);
    }

    // 3. Select matching audio format that allows direct stream copy (-c copy)
    FormatInfo? bestAudio;
    double bestAudioScore = -1.0;

    for (final audio in audioFormats) {
      final score = _scoreAudioFormat(audio, bestVideo, device);
      if (score > bestAudioScore) {
        bestAudioScore = score;
        bestAudio = audio;
      }
    }

    final estimatedSize = (bestVideo?.estimatedSizeBytes ?? 0) + (bestAudio?.estimatedSizeBytes ?? 0);
    final isDirectCopy = _isDirectCopyViable(bestVideo, bestAudio);

    final reason = StringBuffer();
    if (bestVideo != null) {
      reason.write('Video: ${bestVideo.resolutionLabel} (${bestVideo.vcodec ?? bestVideo.ext})');
    }
    if (bestAudio != null) {
      reason.write(', Audio: ${bestAudio.acodec ?? bestAudio.ext} (${bestAudio.abr?.round() ?? 128} kbps)');
    }
    if (isDirectCopy) {
      reason.write(' [Lossless Stream Copy]');
    }

    return FormatRecommendation(
      videoFormat: bestVideo,
      audioFormat: bestAudio,
      requiresMuxing: bestVideo != null && bestAudio != null,
      directStreamCopyPossible: isDirectCopy,
      estimatedSizeBytes: estimatedSize,
      reasoning: reason.toString(),
      qualityScore: max(bestVideoScore, 0.0),
    );
  }

  int _calculateMaxTargetHeight(DeviceCapabilities device) {
    if (preference == QualityPreference.dataSaver) {
      return 720;
    }
    if (device.isMeteredNetwork) {
      return 1080;
    }
    // High-resolution display
    final screenMinDimension = min(device.displayWidth, device.displayHeight);
    if (screenMinDimension >= 1440) {
      return 2160; // 4K allowed on QHD+ displays on Wi-Fi
    }
    return 1440; // 2K/1440p sweet spot for standard 1080p-1440p panels
  }

  double _scoreVideoFormat(
    FormatInfo video,
    DeviceCapabilities device,
    int maxTargetHeight,
  ) {
    double score = 100.0;
    final height = video.height ?? 720;

    // Penalty if exceeds target resolution (wasted bandwidth on mobile)
    if (height > maxTargetHeight) {
      final excess = height - maxTargetHeight;
      score -= (excess / 100.0) * 15.0;
    } else {
      // Reward higher resolution up to target
      score += (height / 1080.0) * 40.0;
    }

    // Framerate: reward 60fps if device supports high refresh rate
    final fps = video.fps ?? 30.0;
    if (fps >= 50.0 && device.displayRefreshRate >= 60.0) {
      score += 15.0;
    }

    // Codec hardware decoding scoring
    final vcodec = video.vcodec?.toLowerCase() ?? '';
    final isSupported = device.supportsVideoCodec(vcodec);
    if (!isSupported) {
      score -= 60.0; // Heavy penalty for software decoding fallback
    } else {
      if (vcodec.contains('av01') || vcodec.contains('av1')) {
        score += 25.0; // Next-gen efficient compression
      } else if (vcodec.contains('vp9') || vcodec.contains('vp09')) {
        score += 20.0; // Excellent quality/bandwidth on Android
      } else if (vcodec.contains('hevc') || vcodec.contains('h265')) {
        score += 18.0;
      } else if (vcodec.contains('avc') || vcodec.contains('h264')) {
        score += 15.0; // Maximum universal hardware playback
      }
    }

    // Storage constraint check (requires 2.2x headroom for download + temporary merge)
    final estimatedSize = video.estimatedSizeBytes ?? (height * 1024 * 300);
    final requiredHeadroom = (estimatedSize * 2.2).round();
    if (requiredHeadroom > device.freeStorageBytes) {
      score -= 80.0; // Storage hazard
    }

    // Battery conservation penalty
    if (device.batteryLevelPercent < 20 && !device.isCharging && height > 1080) {
      score -= 30.0;
    }

    return score;
  }

  double _scoreAudioFormat(
    FormatInfo audio,
    FormatInfo? video,
    DeviceCapabilities device,
  ) {
    double score = 50.0;
    final acodec = audio.acodec?.toLowerCase() ?? '';

    if (!device.supportsAudioCodec(acodec)) {
      score -= 40.0;
    }

    // Bitrate evaluation (~128-160kbps sweet spot)
    final abr = audio.abr ?? 128.0;
    if (abr >= 120.0 && abr <= 256.0) {
      score += 25.0;
    } else if (abr > 256.0) {
      score += 15.0; // Diminishing returns
    }

    // Container compatibility for direct copy
    if (video != null) {
      if (_isDirectCopyViable(video, audio)) {
        score += 30.0; // Bonus for lossless direct mux
      }
    }

    return score;
  }

  bool _isDirectCopyViable(FormatInfo? video, FormatInfo? audio) {
    if (video == null || audio == null) return true;
    final vExt = video.ext.toLowerCase();
    final aExt = audio.ext.toLowerCase();
    final vCodec = video.vcodec?.toLowerCase() ?? '';
    final aCodec = audio.acodec?.toLowerCase() ?? '';

    // MP4 container compatibility: AVC/HEVC/AV1 with AAC/M4A
    if (vExt == 'mp4' && (aExt == 'm4a' || aCodec.contains('mp4a') || aCodec.contains('aac'))) {
      return true;
    }

    // WebM container compatibility: VP9/AV1 with Opus/Vorbis
    if ((vExt == 'webm' || vCodec.contains('vp9') || vCodec.contains('av01')) &&
        (aExt == 'webm' || aCodec.contains('opus') || aCodec.contains('vorbis'))) {
      return true;
    }

    // MKV can multiplex any elementary streams losslessly
    return true;
  }
}
