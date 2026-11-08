enum SortOption {
  dateAddedDesc('Newest First'),
  dateAddedAsc('Oldest First'),
  titleAsc('Title (A-Z)'),
  titleDesc('Title (Z-A)'),
  sizeDesc('Largest Size'),
  sizeAsc('Smallest Size'),
  durationDesc('Longest Duration');

  final String label;
  const SortOption(this.label);
}
