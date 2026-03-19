import 'package:mobile/src/models/floor_map.dart';
import 'package:mobile/src/models/site_point.dart';
import 'package:mobile/src/models/site_summary.dart';

class SiteDetail extends SiteSummary {
  const SiteDetail({
    required super.id,
    required super.slug,
    required super.name,
    required super.description,
    required this.floorMaps,
    required this.points,
  });

  final List<FloorMap> floorMaps;
  final List<SitePoint> points;

  factory SiteDetail.fromJson(Map<String, dynamic> json) {
    final floorMapsJson = json['floor_maps'] as List<dynamic>? ?? const [];
    final pointsJson = json['points'] as List<dynamic>? ?? const [];

    return SiteDetail(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      floorMaps: floorMapsJson
          .map((value) => FloorMap.fromJson(value as Map<String, dynamic>))
          .toList(growable: false),
      points: pointsJson
          .map((value) => SitePoint.fromJson(value as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
