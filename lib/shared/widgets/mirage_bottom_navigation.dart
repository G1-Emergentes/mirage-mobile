import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/mirage_theme.dart';

class MirageBottomNavigation extends StatelessWidget {
  const MirageBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  static const labels = ['Home', 'Closet', 'Create', 'Explore', 'Profile'];
  static const assets = ['home', 'closet', 'create', 'explore', 'profile'];
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: MirageColors.paper,
      border: Border(top: BorderSide(color: MirageColors.border)),
    ),
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 26),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 9, 20, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var index = 0; index < labels.length; index++)
              Flexible(child: SizedBox(width: 56, child: _item(index))),
          ],
        ),
      ),
    ),
  );
  Widget _item(int index) {
    final selected = selectedIndex == index;
    final color = selected ? MirageColors.pink : MirageColors.muted;
    return Semantics(
      label: labels[index],
      button: true,
      selected: selected,
      enabled: true,
      child: ExcludeSemantics(
        child: Tooltip(
          message: labels[index],
          child: InkWell(
            key: ValueKey('navigation-$index'),
            onTap: () => onSelected(index),
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 57),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: index == 2 ? 48 : 30,
                    height: index == 2 ? 40 : 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: index == 2
                          ? MirageColors.pink
                          : MirageColors.paper,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SvgPicture.asset(
                      'assets/navigation/${assets[index]}.svg',
                      width: 22,
                      height: 22,
                      colorFilter: ColorFilter.mode(
                        index == 2 ? Colors.white : color,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      height: 1.4,
                      color: color,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
