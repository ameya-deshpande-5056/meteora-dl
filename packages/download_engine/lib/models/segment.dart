import 'package:meta/meta.dart';

/// A byte-range segment of a downloadable resource.
@immutable
class Segment {
  final int index;
  final int start; // inclusive
  final int end; // inclusive
  final int downloaded;
  final bool completed;

  const Segment({
    required this.index,
    required this.start,
    required this.end,
    this.downloaded = 0,
    this.completed = false,
  });

  int get total => end - start + 1;

  double get progress => total <= 0 ? 1.0 : downloaded / total;

  Segment copyWith({int? downloaded, bool? completed}) {
    return Segment(
      index: index,
      start: start,
      end: end,
      downloaded: downloaded ?? this.downloaded,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'start': start,
        'end': end,
        'downloaded': downloaded,
        'completed': completed,
      };

  factory Segment.fromJson(Map<String, dynamic> json) => Segment(
        index: json['index'] as int,
        start: json['start'] as int,
        end: json['end'] as int,
        downloaded: (json['downloaded'] as num?)?.toInt() ?? 0,
        completed: json['completed'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is Segment &&
      other.index == index &&
      other.start == start &&
      other.end == end &&
      other.downloaded == downloaded &&
      other.completed == completed;

  @override
  int get hashCode => Object.hash(index, start, end, downloaded, completed);
}