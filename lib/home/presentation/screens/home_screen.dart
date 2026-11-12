import 'package:flutter/material.dart';

import '../../../closet/application/closet_controller.dart';
import '../../../closet/domain/garment.dart';
import '../../../closet/presentation/closet_widgets.dart';
import '../../../shared/theme/mirage_theme.dart';
import '../../../shared/widgets/mirage_feature_components.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.navigation,
    required this.closet,
    required this.onCloset,
    required this.onCategory,
    required this.onExplore,
    this.displayName,
    this.onRecommendations,
    this.onTryOnGlasses,
  });

  final Widget navigation;
  final ClosetController closet;
  final String? displayName;
  final VoidCallback onCloset, onExplore;
  final VoidCallback? onRecommendations;

  /// Opens the virtual try-on of glasses (AR on the face).
  final VoidCallback? onTryOnGlasses;
  final ValueChanged<ClosetGroup> onCategory;

  @override
  Widget build(BuildContext context) => MirageFeaturePage(
    navigation: navigation,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              displayName == null
                  ? 'Welcome to Mirage ✦'
                  : 'Hello, $displayName ✦',
            ),
          ),
          const MirageDesignIcon('bell', size: 20),
        ],
      ),
      const SizedBox(height: 14),
      const MirageFeatureTitle('What should we\nwear today?', size: 33),
      const SizedBox(height: 14),
      Material(
        color: MirageColors.blue,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onRecommendations,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MirageBadge('MADE FOR YOU'),
                const SizedBox(height: 12),
                if (closet.garments.isNotEmpty)
                  SizedBox(
                    height: 82,
                    child: Row(
                      children: [
                        for (final item in closet.garments.reversed.take(4))
                          Expanded(
                            child: GarmentImage(garment: item, closet: closet),
                          ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Personalized Recommendations',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const MirageDesignIcon('arrow-up-right', size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      _section(context, 'Your Closet', 'View all', onCloset),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final category in ClosetGroup.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () => onCategory(category),
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      Container(
                        height: 46,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: mirageNeutral,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _categoryPhoto(category),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        category.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        'Try Something New ✦',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      if (onTryOnGlasses case final open?)
        Material(
          color: MirageColors.lavender,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('home-try-on-glasses'),
            onTap: open,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.face_retouching_natural, size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const MirageBadge('AR TRY-ON'),
                        const SizedBox(height: 6),
                        Text(
                          'Try on glasses',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Text(
                          'See them on your face with the front camera.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const MirageDesignIcon('arrow-up-right', size: 20),
                ],
              ),
            ),
          ),
        )
      else
        const MirageNotice(
          'No AR-ready pieces available yet.',
          color: mirageNeutral,
        ),
      const SizedBox(height: 10),
      _section(context, 'Discover for You', 'Explore', onExplore),
      const MirageNotice('Explore new finds and more ways to wear.'),
    ],
  );

  Widget _categoryPhoto(ClosetGroup category) {
    final garment = closet.inGroup(category).firstOrNull;
    return garment == null
        ? const Center(child: Icon(Icons.checkroom_outlined, size: 20))
        : GarmentImage(garment: garment, closet: closet);
  }

  Widget _section(
    BuildContext context,
    String title,
    String action,
    VoidCallback callback,
  ) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      TextButton(onPressed: callback, child: Text(action)),
    ],
  );
}
