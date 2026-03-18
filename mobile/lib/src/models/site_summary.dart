class SiteSummary {
  const SiteSummary({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
  });

  final String id;
  final String slug;
  final String name;
  final String? description;

  factory SiteSummary.fromJson(Map<String, dynamic> json) {
    return SiteSummary(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }
}
