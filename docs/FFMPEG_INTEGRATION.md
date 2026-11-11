# FFmpeg & FFprobe Integration Guide

## 1. Overview
FFmpeg and FFprobe provide critical media processing and inspection capabilities for Meteora:
1. **FFmpeg**: Lossless container muxing of separate video-only (e.g. 1080p/4K AVC/VP9/AV1) and audio-only (e.g. Opus/AAC) streams downloaded by `yt-dlp`.
2. **FFprobe**: Fast, accurate extraction of codec tags, bitrates, dimensions, color space, and duration for downloaded media files before library indexing.

---

## 2. Lossless Stream Muxing (`-c copy`)

Re-encoding 1080p or 4K video on a mobile device is computationally expensive, drains the battery rapidly, degrades visual quality, and generates excessive heat.

Meteora mandates direct stream copying whenever the container supports the audio and video elementary streams:

```bash
ffmpeg -y \
  -i "video_stream.mp4" \
  -i "audio_stream.m4a" \
  -c copy \
  -movflags +faststart \
  "output.mp4"
```

- `-c copy`: Copies packet data directly from input demuxers to output muxers without decoding or encoding. A 1GB 4K file muxes in under 1.5 seconds.
- `-movflags +faststart`: Relocates the `moov` atom to the beginning of the MP4 file, allowing immediate playback in external media players (such as VLC or mpv) without waiting for the full file to buffer.

---

## 3. Metadata Extraction with FFprobe

To index media in the offline library, Meteora queries files using `ffprobe`:

```bash
ffprobe -v quiet -print_format json -show_format -show_streams "media_file.mp4"
```

### Extracted Properties:
- Video stream: `codec_name` (e.g., `av01`, `vp9`, `h264`, `hevc`), `width`, `height`, `r_frame_rate`, `bit_rate`, `pix_fmt`.
- Audio stream: `codec_name` (e.g., `opus`, `aac`, `mp3`), `sample_rate`, `channels`, `bit_rate`.
- Format metadata: `duration`, `size`, `tags` (title, artist, album, date).

---

## 4. Thumbnail Generation
To generate high-speed thumbnails without loading the entire video into RAM:
```bash
ffmpeg -ss 00:00:01 -i "input.mp4" -vframes 1 -q:v 2 "thumbnail.jpg"
```
The resulting JPEG is cached locally in `cache/thumbnails/<media_id>.jpg` and served through Flutter's image caching layer.
