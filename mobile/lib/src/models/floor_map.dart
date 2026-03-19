class FloorMap {
  const FloorMap({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.imageWidth,
    required this.imageHeight,
  });

  final String id;
  final String name;
  final String? imagePath;
  final int? imageWidth;
  final int? imageHeight;

  factory FloorMap.fromJson(Map<String, dynamic> json) {
    return FloorMap(
      id: json['id'] as String,
      name: json['name'] as String,
      imagePath: json['image_path'] as String?,
      imageWidth: json['image_width'] as int?,
      imageHeight: json['image_height'] as int?,
    );
  }
}
