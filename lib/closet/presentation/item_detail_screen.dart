import 'package:flutter/material.dart';
import '../../shared/theme/mirage_theme.dart';
import '../../shared/widgets/mirage_components.dart';
import '../application/closet_controller.dart';
import '../closet_module.dart';
import '../domain/closet_repository.dart';
import '../domain/garment.dart';
import 'add_item_screen.dart';
import 'closet_widgets.dart';
import 'saved_outfits_screen.dart';

/// One piece: photo, details, "Armar" (put it in an outfit), edit and delete.
class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({
    super.key,
    required this.module,
    required this.garmentId,
  });
  final ClosetModule module;
  final String garmentId;
  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  String? error;
  bool busy = false;

  Future<void> _delete(Garment garment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this piece?'),
        content: Text('"${garment.name}" will leave your closet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      widget.module.tray.items
          .where((item) => item.id == garment.id)
          .forEach(widget.module.tray.toggle);
      await widget.module.closet.remove(garment.id);
      if (mounted) Navigator.of(context).pop();
    } on ClosetException catch (e) {
      if (mounted) setState(() => error = ClosetController.describe(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: MirageColors.muted),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.module.closet,
    builder: (context, _) {
      final closet = widget.module.closet;
      final garment = closet.garments
          .where((g) => g.id == widget.garmentId)
          .firstOrNull;
      if (garment == null) {
        return const MirageScreen(
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return MirageScreen(
        topPadding: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back, size: 22),
                ),
                Expanded(
                  child: Text(
                    'MY CLOSET / ${garment.group.label.toUpperCase()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 10),
            Stack(
              children: [
                Container(
                  height: 340,
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: MirageColors.blue,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: GarmentImage(garment: garment, closet: closet),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  child: Tag(garment.available ? 'IN YOUR CLOSET' : 'UNAVAILABLE'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              garment.name,
              style: const TextStyle(fontFamily: 'Lora', fontSize: 30, height: 1.15),
            ),
            const SizedBox(height: 10),
            _row('Category', garment.kind),
            _row(
              'Color',
              garment.colors.isEmpty
                  ? '—'
                  : garment.colors.map(humanize).join(', '),
            ),
            _row(
              'Style',
              garment.styles.isEmpty
                  ? '—'
                  : garment.styles.map(humanize).join(' / '),
            ),
            _row('Availability', garment.available ? 'Available' : 'Unavailable'),
            const SizedBox(height: 18),
            if (error != null) ...[
              MirageNotice(error!, error: true),
              const SizedBox(height: 12),
            ],
            MirageButton(
              key: const ValueKey('armar'),
              label: 'Armar',
              arrow: false,
              onPressed: () => showArmarSheet(context, widget.module, garment),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              key: const ValueKey('edit-item'),
              onPressed: busy
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AddItemScreen(
                          module: widget.module,
                          editing: garment,
                        ),
                      ),
                    ),
              child: const Text('Edit Item'),
            ),
            Center(
              child: TextButton(
                key: const ValueKey('delete-item'),
                onPressed: busy ? null : () => _delete(garment),
                child: const Text('Delete item'),
              ),
            ),
          ],
        ),
      );
    },
  );
}
