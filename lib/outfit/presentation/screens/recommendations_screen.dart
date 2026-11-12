import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../shared/theme/mirage_theme.dart';
import '../../../shared/widgets/mirage_feature_components.dart';

class OutfitRecommendation {
  const OutfitRecommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.badge,
    required this.photos,
  });
  final String id, title, description, badge;
  final List<Uint8List> photos;
}

class RecommendationsScreen extends StatelessWidget {
  const RecommendationsScreen({
    super.key,
    this.items = const [],
    this.onFeedback,
  });
  final List<OutfitRecommendation> items;
  final void Function(OutfitRecommendation, bool)? onFeedback;

  @override
  Widget build(BuildContext context) => MirageFeaturePage(
    title: 'For You',
    subtitle: 'Based on your closet and preferences.',
    onBack: () => Navigator.pop(context),
    children: [
      if (items.isEmpty)
        const MirageNotice('Recommendations are not available yet.'),
      for (final item in items) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MirageColors.blue,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MirageBadge(item.badge),
              SizedBox(
                height: 156,
                child: Row(
                  children: [
                    for (final photo in item.photos.take(4))
                      Expanded(child: MiragePhoto(photo)),
                  ],
                ),
              ),
              Text(item.title, style: Theme.of(context).textTheme.titleLarge),
              Text(item.description),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: onFeedback == null
                        ? null
                        : () => onFeedback!(item, true),
                    child: const Text('Like'),
                  ),
                  TextButton(
                    onPressed: onFeedback == null
                        ? null
                        : () => onFeedback!(item, false),
                    child: const Text('Not for Me'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
      const SizedBox(height: 14),
      const Text('✦ The more you like, the more it feels like you.'),
    ],
  );
}
