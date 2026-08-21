import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExploreData {
  final int segmentIndex;
  final List<RouteData> routes;
  final List<SegmentData> segments;
  final List<LeaderboardRowData> leaderboards;

  const ExploreData({
    required this.segmentIndex,
    required this.routes,
    required this.segments,
    required this.leaderboards,
  });

  ExploreData copyWith({
    int? segmentIndex,
    List<RouteData>? routes,
    List<SegmentData>? segments,
    List<LeaderboardRowData>? leaderboards,
  }) {
    return ExploreData(
      segmentIndex: segmentIndex ?? this.segmentIndex,
      routes: routes ?? this.routes,
      segments: segments ?? this.segments,
      leaderboards: leaderboards ?? this.leaderboards,
    );
  }
}

@immutable
class RouteData {
  final String slug;
  final String name;
  final String description;
  final double distance;
  final int elevationGain;
  final int estimatedTime;

  const RouteData({
    required this.slug,
    required this.name,
    required this.description,
    required this.distance,
    required this.elevationGain,
    required this.estimatedTime,
  });
}

@immutable
class SegmentData {
  final String name;
  final String description;
  final double distance;
  final int elevationGain;
  final int estimatedTime;

  const SegmentData({
    required this.name,
    required this.description,
    required this.distance,
    required this.elevationGain,
    required this.estimatedTime,
  });
}

@immutable
class LeaderboardRowData {
  final int rank;
  final String name;
  final String value;
  final String? badge;

  const LeaderboardRowData({
    required this.rank,
    required this.name,
    required this.value,
    this.badge,
  });
}

class ExploreNotifier extends Notifier<ExploreData> {
  void setSegmentByIndex(int index) {
    state = state.copyWith(segmentIndex: index);
  }

  @override
  ExploreData build() {
    return ExploreData(
      segmentIndex: 0,
      routes: _sampleRoutes,
      segments: _sampleSegments,
      leaderboards: _sampleLeaderboards,
    );
  }
}

final exploreProvider = NotifierProvider<ExploreNotifier, ExploreData>(ExploreNotifier.new);

// F-6/U-8: this tab currently has no backend to source real routes,
// segments, or leaderboards from -- there is no such endpoint anywhere in
// backend/internal. Building that (route storage, geometry, a real
// leaderboard) is a real backend feature, not a copy fix, so it's out of
// scope here. What IS in scope: not presenting fabricated data as if it
// were real. explore_page.dart now shows an explicit "Preview" banner
// above this content in both locales (AUDIT_2.md F-6).
final _sampleRoutes = [
  RouteData(
    slug: 'marathon-kenya-standard',
    name: 'Marathon Standard',
    description: 'A full marathon course modeled on a standard Kenyan road race',
    distance: 42195,
    elevationGain: 2800,
    estimatedTime: 150,
  ),
  RouteData(
    slug: 'half-marathon-nairobi',
    name: 'Half Marathon Nairobi',
    description: 'A half marathon route through Nairobi CBD landmarks',
    distance: 21097,
    elevationGain: 1500,
    estimatedTime: 85,
  ),
  RouteData(
    slug: '10k-eldoret',
    name: '10K Eldoret',
    description: 'Start from Rift Valley edge, finish at main stadium',
    distance: 10000,
    elevationGain: 800,
    estimatedTime: 45,
  ),
];

final _sampleSegments = [
  SegmentData(
    name: 'Upslope Run',
    description: 'Standard warmup segment, elevation gain overlay',
    distance: 3000,
    elevationGain: 300,
    estimatedTime: 30,
  ),
  SegmentData(
    name: 'Kenyan Flag Red',
    description: 'Red - high elevation gain segment',
    distance: 5000,
    elevationGain: 800,
    estimatedTime: 50,
  ),
  SegmentData(
    name: 'Terrain Switch',
    description: 'Mix of flat and rolling segments',
    distance: 4000,
    elevationGain: 600,
    estimatedTime: 40,
  ),
];

final _sampleLeaderboards = [
  LeaderboardRowData(rank: 1, name: 'Eliud Kipchoge', value: '2:01:39', badge: 'goat'),
  LeaderboardRowData(rank: 2, name: 'Margaret Mutai', value: '2:16:45', badge: 'goat'),
  LeaderboardRowData(rank: 3, name: 'Joseph Kiptoo', value: '2:05:12', badge: null),
  LeaderboardRowData(rank: 4, name: 'Jane Wanjiru', value: '2:20:33', badge: null),
  LeaderboardRowData(rank: 5, name: 'Samuel Kimani', value: '2:03:41', badge: 'goat'),
  LeaderboardRowData(rank: 6, name: 'Faith Njoki', value: '2:18:55', badge: null),
];