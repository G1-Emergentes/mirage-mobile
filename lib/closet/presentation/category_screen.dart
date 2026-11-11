import 'package:flutter/material.dart';
import '../../shared/theme/mirage_theme.dart';
import '../../shared/widgets/mirage_components.dart';
import '../closet_module.dart';
import '../domain/garment.dart';
import 'add_item_screen.dart';
import 'closet_widgets.dart';
import 'item_detail_screen.dart';

enum _Sort { name, color }

/// One group of the closet as a two-column grid, with search, colour filter and sort.
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key, required this.module, required this.group});
  final ClosetModule module;
  final ClosetGroup group;
  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  String query = '';
  String? color;
  _Sort sort = _Sort.name;

  List<Garment> _visible(List<Garment> all) {
    final needle = query.trim().toLowerCase();
    final list = all.where((garment) {
      final matchesText =
          needle.isEmpty ||
          garment.name.toLowerCase().contains(needle) ||
          garment.subtitle.toLowerCase().contains(needle);
      final matchesColor = color == null || garment.colors.contains(color);
      return matchesText && matchesColor;
    }).toList();
    list.sort(
      (a, b) => sort == _Sort.name
          ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
          : a.colorLabel.compareTo(b.colorLabel),
    );
    return list;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.module.closet,
    builder: (context, _) {
      final closet = widget.module.closet;
      final inGroup = closet.inGroup(widget.group);
      final shown = _visible(inGroup);
      final colors = {for (final g in inGroup) ...g.colors}.toList()..sort();
      final label = widget.group.label.toLowerCase();
      return MirageScreen(
        topPadding: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClosetTopBar(
              onBack: () => Navigator.of(context).pop(),
              trailing: IconButton(
                key: const ValueKey('add-to-group'),
                tooltip: 'Add item',
                icon: const Icon(Icons.add, size: 24),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddItemScreen(
                      module: widget.module,
                      initialCategory: widget.group.categories.first,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(widget.group.label, style: titleStyle),
            const SizedBox(height: 6),
            Text(
              '${inGroup.length} pieces in your closet',
              style: const TextStyle(fontSize: 15, color: MirageColors.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('search'),
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                hintText: 'Search your $label',
                prefixIcon: const Icon(Icons.search, size: 22),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'All $label · ${shown.length}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: MirageColors.muted,
                    ),
                  ),
                ),
                PopupMenuButton<String?>(
                  tooltip: 'Filter by colour',
                  onSelected: (value) =>
                      setState(() => color = value == '' ? null : value),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: '', child: Text('All colours')),
                    for (final c in colors)
                      PopupMenuItem(value: c, child: Text(humanize(c))),
                  ],
                  child: _pill(
                    Icons.tune,
                    color == null ? 'Filter' : humanize(color!),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<_Sort>(
                  tooltip: 'Sort',
                  onSelected: (value) => setState(() => sort = value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: _Sort.name, child: Text('Name')),
                    PopupMenuItem(value: _Sort.color, child: Text('Colour')),
                  ],
                  child: _pill(Icons.swap_vert, 'Sort'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (closet.loading && !closet.loaded)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!closet.loaded && closet.error != null) ...[
              MirageNotice(closet.error!, error: true),
              TextButton(
                onPressed: closet.load,
                child: const Text('Try again'),
              ),
            ] else if (shown.isEmpty)
              MirageNotice(
                inGroup.isEmpty
                    ? 'No $label yet. Tap + to add one.'
                    : 'Nothing matches your search.',
              )
            else
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 14,
                childAspectRatio: 0.7,
                children: [
                  for (var i = 0; i < shown.length; i++)
                    GarmentTile(
                      key: ValueKey('tile-${shown[i].id}'),
                      garment: shown[i],
                      closet: closet,
                      tray: widget.module.tray,
                      tint: tintFor(i),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ItemDetailScreen(
                            module: widget.module,
                            garmentId: shown[i].id,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      );
    },
  );

  Widget _pill(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: MirageColors.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}
