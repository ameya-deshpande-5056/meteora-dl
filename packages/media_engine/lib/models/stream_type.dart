enum StreamType {
  videoOnly,
  audioOnly,
  combined;

  bool get hasVideo => this == StreamType.videoOnly || this == StreamType.combined;
  bool get hasAudio => this == StreamType.audioOnly || this == StreamType.combined;
}
