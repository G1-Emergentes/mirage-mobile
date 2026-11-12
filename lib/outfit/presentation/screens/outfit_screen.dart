import 'package:flutter/material.dart';

import '../../../closet/application/closet_controller.dart';
import '../../../closet/application/outfit_tray.dart';
import '../../../closet/domain/garment.dart';
import '../../../closet/presentation/closet_widgets.dart';
import '../../../shared/theme/mirage_theme.dart';
import '../../../shared/widgets/mirage_components.dart';
import '../../../shared/widgets/mirage_feature_components.dart';

class OutfitScreen extends StatelessWidget {
  const OutfitScreen({
    super.key,
    required this.navigation,
    required this.pieces,
    required this.closet,
    required this.onSelect,
    required this.onReset,
    required this.onHome,
    required this.onAdd,
    required this.onTryOn,
    this.onGenerate,
  });

  final List<Garment> pieces;
  final ClosetController closet;
  final Widget navigation;
  final ValueChanged<ClosetGroup> onSelect;
  final VoidCallback onReset, onHome, onAdd, onTryOn;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) => MirageFeaturePage(
    title: 'Create Outfit',
    subtitle: 'Your pieces. Your rules.',
    onBack: onHome,
    action: 'reset',
    actionLabel: 'Reset outfit',
    onAction: pieces.isEmpty ? null : onReset,
    navigation: navigation,
    children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MirageColors.blue,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _slot(ClosetGroup.tops, 164),
                  const SizedBox(height: 6),
                  _slot(ClosetGroup.shoes, 112),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: [
                  _slot(ClosetGroup.bottoms, 220),
                  const SizedBox(height: 6),
                  _slot(ClosetGroup.accessories, 92),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerRight,
        child: Text(
          '${pieces.length} / ${OutfitTray.maxPieces} pieces',
          style: const TextStyle(color: MirageColors.pink),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onAdd,
              child: const Text('+ Add Item'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: onGenerate,
              child: const Text('Generate Ideas'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      MirageButton(
        label: 'Try on Me',
        arrow: false,
        onPressed: pieces.isEmpty ? null : onTryOn,
      ),
      const SizedBox(height: 12),
      const Text(
        'Outfit first. Your personal AI preview is optional.',
        textAlign: TextAlign.center,
      ),
    ],
  );

  Widget _slotContents(ClosetGroup category) {
    final garments = pieces.where((garment) => garment.group == category);
    if (garments.isEmpty) {
      return const Center(child: MirageDesignIcon('plus', size: 22));
    }
    return Row(
      children: [
        for (final garment in garments)
          Expanded(
            child: GarmentImage(garment: garment, closet: closet),
          ),
      ],
    );
  }

  Widget _slot(ClosetGroup category, double height) => Material(
    color: Colors.white.withValues(alpha: 0.32),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Colors.white),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => onSelect(category),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Column(
          children: [
            const SizedBox(height: 4),
            Text(
              category.label.toUpperCase(),
              style: const TextStyle(
                fontSize: 9,
                color: MirageColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _slotContents(category),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
