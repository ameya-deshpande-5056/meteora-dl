enum UpdateChannel {
  stable,
  nightly,
  manual;

  String get label {
    switch (this) {
      case UpdateChannel.stable:
        return 'Stable';
      case UpdateChannel.nightly:
        return 'Nightly';
      case UpdateChannel.manual:
        return 'Manual';
    }
  }
}
