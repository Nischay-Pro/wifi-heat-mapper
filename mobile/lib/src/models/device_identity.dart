class DeviceIdentity {
  const DeviceIdentity({
    required this.slug,
    required this.name,
    required this.platform,
    this.model,
  });

  final String slug;
  final String name;
  final String platform;
  final String? model;

  Map<String, Object?> toJson() {
    return {
      'slug': slug,
      'name': name,
      'platform': platform,
      'model': model,
    }..removeWhere((_, value) => value == null);
  }
}
