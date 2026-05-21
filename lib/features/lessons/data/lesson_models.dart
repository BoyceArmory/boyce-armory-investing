import 'package:equatable/equatable.dart';

/// Visual accent groups - the UI maps these to colors and icons.
enum LearnTrack { foundations, options, technicals, risk, execution }

class LearnSection extends Equatable {
  const LearnSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.track,
    required this.lessons,
  });

  final String id;
  final String title;
  final String subtitle;
  final LearnTrack track;
  final List<LearnLesson> lessons;

  int get featuredCount => lessons.where((LearnLesson l) => l.featured).length;

  LearnLesson? lessonById(String id) {
    for (final LearnLesson l in lessons) {
      if (l.id == id) return l;
    }
    return null;
  }

  @override
  List<Object?> get props => <Object?>[id, title, subtitle, track, lessons];
}

class LearnLesson extends Equatable {
  const LearnLesson({
    required this.id,
    required this.title,
    required this.summary,
    required this.bullets,
    this.body,
    this.featured = false,
    this.imageAssetPath,
    this.imageTitle,
  });

  final String id;
  final String title;
  final String summary;
  final List<String> bullets;
  final String? body;
  final bool featured;
  final String? imageAssetPath;
  final String? imageTitle;

  @override
  List<Object?> get props => <Object?>[
        id,
        title,
        summary,
        bullets,
        body,
        featured,
        imageAssetPath,
        imageTitle,
      ];
}
