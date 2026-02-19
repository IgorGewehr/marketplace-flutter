import 'dart:ui';

/// Promo banner model for marketplace banners
class PromoBanner {
  final String id;
  final String title;
  final String subtitle;
  final Color color;
  final String? imageUrl;
  final String? actionUrl;

  const PromoBanner({
    this.id = '',
    required this.title,
    required this.subtitle,
    required this.color,
    this.imageUrl,
    this.actionUrl,
  });

  factory PromoBanner.fromJson(Map<String, dynamic> json) {
    return PromoBanner(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      color: Color(int.parse(
        (json['color'] as String? ?? 'FF007BFF').replaceFirst('#', ''),
        radix: 16,
      )),
      imageUrl: json['imageUrl'] as String?,
      actionUrl: json['actionUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'color': '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}',
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (actionUrl != null) 'actionUrl': actionUrl,
    };
  }
}
