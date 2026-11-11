import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/mirage_theme.dart';
import 'mirage_components.dart';
export 'mirage_components.dart' show MirageNotice;

const mirageNeutral = Color(0xFFEEEBe4);

class MirageDesignIcon extends StatelessWidget {
  const MirageDesignIcon(this.name, {super.key, this.size = 22});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: SvgPicture.asset('assets/design/$name.svg', fit: BoxFit.contain),
  );
}

class MirageFeaturePage extends StatelessWidget {
  const MirageFeaturePage({
    super.key,
    required this.children,
    this.title,
    this.subtitle,
    this.onBack,
    this.action,
    this.actionLabel,
    this.onAction,
    this.navigation,
  });

  final List<Widget> children;
  final String? title, subtitle, action, actionLabel;
  final VoidCallback? onBack, onAction;
  final Widget? navigation;

  @override
  Widget build(BuildContext context) => MirageScreen(
    topPadding: title == null ? 8 : 5,
    bottomNavigationBar: navigation,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (onBack != null)
                IconButton(
                  tooltip: 'Back',
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  onPressed: onBack,
                  icon: const MirageDesignIcon('back'),
                )
              else
                const SizedBox(width: 48),
              const MirageWordmark(size: 17),
              if (action != null)
                IconButton(
                  tooltip: actionLabel,
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerRight,
                  onPressed: onAction,
                  icon: MirageDesignIcon(action!),
                )
              else
                const SizedBox(width: 48),
            ],
          ),
          MirageFeatureTitle(title!),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyLarge),
          ],
          const SizedBox(height: 16),
        ],
        ...children,
      ],
    ),
  );
}

class MirageFeatureTitle extends StatelessWidget {
  const MirageFeatureTitle(this.text, {super.key, this.size = 36});
  final String text;
  final double size;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: size),
  );
}

class MirageChoices<T> extends StatelessWidget {
  const MirageChoices({
    super.key,
    required this.options,
    required this.selected,
    required this.label,
    required this.onSelected,
  });
  final Iterable<T> options;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 4,
    children: [
      for (final option in options)
        ChoiceChip(
          label: Text(label(option)),
          selected: option == selected,
          onSelected: (_) => onSelected(option),
          showCheckmark: false,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          backgroundColor: mirageNeutral,
          selectedColor: MirageColors.ink,
          labelStyle: TextStyle(
            fontSize: 11,
            color: option == selected ? Colors.white : MirageColors.muted,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2),
        ),
    ],
  );
}

class MirageBadge extends StatelessWidget {
  const MirageBadge(this.label, {super.key, this.color = Colors.white});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(color: color, shape: const StadiumBorder()),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: Text(
        label,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class MiragePhoto extends StatelessWidget {
  const MiragePhoto(this.bytes, {super.key, this.fit = BoxFit.contain});
  final Uint8List? bytes;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => bytes == null
      ? const Center(
          child: Icon(Icons.image_outlined, color: MirageColors.muted),
        )
      : Image.memory(bytes!, fit: fit);
}

/// Dashed outline used by the photo upload cards in the mockups.
class MirageUploadSurface extends StatelessWidget {
  const MirageUploadSurface({
    super.key,
    required this.color,
    required this.padding,
    required this.child,
  });

  final Color color;
  final EdgeInsetsGeometry padding;
  final Widget child;

  static const radius = 22.0;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: const _UploadOutline(),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class _UploadOutline extends CustomPainter {
  const _UploadOutline();

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.5),
          const Radius.circular(MirageUploadSurface.radius),
        ),
      );
    final paint = Paint()
      ..color = MirageColors.muted
      ..style = PaintingStyle.stroke;
    for (final contour in outline.computeMetrics()) {
      for (var distance = 0.0; distance < contour.length; distance += 9) {
        final end = (distance + 5).clamp(0.0, contour.length);
        canvas.drawPath(contour.extractPath(distance, end), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_UploadOutline oldDelegate) => false;
}
