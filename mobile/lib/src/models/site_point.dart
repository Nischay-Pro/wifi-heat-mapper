class SitePoint {
  const SitePoint({
    required this.id,
    required this.floorMapId,
    required this.label,
    required this.x,
    required this.y,
    required this.isBaseStation,
  });

  final String id;
  final String floorMapId;
  final String? label;
  final int x;
  final int y;
  final bool isBaseStation;

  factory SitePoint.fromJson(Map<String, dynamic> json) {
    return SitePoint(
      id: json['id'] as String,
      floorMapId: json['floor_map_id'] as String,
      label: json['label'] as String?,
      x: json['x'] as int,
      y: json['y'] as int,
      isBaseStation: json['is_base_station'] as bool? ?? false,
    );
  }
}
