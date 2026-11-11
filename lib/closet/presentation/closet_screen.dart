import 'package:flutter/material.dart';
import '../../shared/theme/mirage_theme.dart';
import '../../shared/widgets/mirage_components.dart';
import '../closet_module.dart';
import '../domain/garment.dart';
import 'add_item_screen.dart';
import 'category_screen.dart';
import 'closet_widgets.dart';
import 'try_on_screens.dart';

/// "My Closet": the four groups with their counts. Root of the Closet tab.
class ClosetScreen extends StatefulWidget {
  const ClosetScreen({
    super.key,
    required this.module,
    this.bottomNavigationBar,
  });
  final ClosetModule module;
  final Widget? bottomNavigationBar;
  @override
  State<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends State<ClosetScreen> {
  ClosetGroup? filter;
  static const _cardColors = {
    ClosetGroup.tops: MirageColors.lavender,
    ClosetGroup.bottoms: MirageColors.blue,
    ClosetGroup.shoes: Color(0xFFEEEBE4),
    ClosetGroup.accessories: MirageColors.lime,
  };

  @override
  void initState() {
    super.initState();
    if (!widget.module.closet.loaded) widget.module.closet.load();
  }

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  Widget _groupCard(ClosetGroup group) {
    final closet = widget.module.closet;
    final samples = closet
        .inGroup(group)
        .where((garment) => garment.hasImage)
        .take(2)
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        key: ValueKey('group-${group.name}'),
        onTap: () => _open(CategoryScreen(module: widget.module, group: group)),
        borderRadius: BorderRadius.circular(26),
        child: Container(
          height: 118,
          padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
          decoration: BoxDecoration(
            color: _cardColors[group],
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      group.label,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${closet.count(group)} pieces',
                      style: const TextStyle(
                        fontSize: 12,
                        color: MirageColors.muted,
                      ),
                    ),
                    const Icon(Icons.north_east, size: 16),
                  ],
                ),
              ),
              for (final garment in samples)
                SizedBox(
                  width: 76,
                  child: GarmentImage(garment: garment, closet: closet),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trayBar() => ListenableBuilder(
    listenable: widget.module.tray,
    builder: (context, _) {
      final tray = widget.module.tray;
      if (tray.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 6, 8, 6),
          decoration: BoxDecoration(
            color: MirageColors.lime,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Outfit · ${tray.items.length} ${tray.items.length == 1 ? 'piece' : 'pieces'} (max ${tray.items.length > 3 ? tray.items.length : 3})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('try-on'),
                onPressed: () => _open(ReadyToTryScreen(module: widget.module)),
                style: TextButton.styleFrom(foregroundColor: MirageColors.ink),
                child: const Text('Try on →'),
              ),
            ],
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.module.closet,
    builder: (context, _) {
      final closet = widget.module.closet;
      final groups = filter == null ? ClosetGroup.values : [filter!];
      return MirageScreen(
        topPadding: 0,
        bottomNavigationBar: widget.bottomNavigationBar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ClosetTopBar(),
            const SizedBox(height: 8),
            const Text('My Closet', style: titleStyle),
            const SizedBox(height: 6),
            Text(
              '${closet.garments.length} pieces. Endless possibilities.',
              style: const TextStyle(fontSize: 15, color: MirageColors.muted),
            ),
            const SizedBox(height: 16),
            ClosetChips(
              labels: ['All', for (final g in ClosetGroup.values) g.label],
              selected: filter == null ? 0 : filter!.index + 1,
              onSelected: (i) => setState(
                () => filter = i == 0 ? null : ClosetGroup.values[i - 1],
              ),
            ),
            const SizedBox(height: 16),
            if (closet.loading && !closet.loaded)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (closet.error != null && !closet.loaded) ...[
              MirageNotice(closet.error!, error: true),
              const SizedBox(height: 12),
              MirageButton(
                label: 'Try again',
                arrow: false,
                onPressed: closet.load,
              ),
              const SizedBox(height: 12),
            ] else ...[
              if (closet.loaded && closet.garments.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: MirageNotice(
                    'Your closet is empty. Add your first piece with a photo.',
                  ),
                ),
              for (final group in groups) _groupCard(group),
            ],
            _trayBar(),
            MirageButton(
              key: const ValueKey('add-item'),
              label: '+ Add New Item',
              onPressed: () => _open(AddItemScreen(module: widget.module)),
            ),
          ],
        ),
      );
    },
  );
}
