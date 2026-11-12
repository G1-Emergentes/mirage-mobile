import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../face_try_on/presentation/glasses_try_on_screen.dart';
import '../../shared/theme/mirage_theme.dart';
import '../../shared/widgets/mirage_components.dart';
import '../application/accessory_models_controller.dart';
import '../application/closet_controller.dart';
import '../application/outfit_tray.dart';
import '../closet_module.dart';
import '../domain/closet_repository.dart';
import '../domain/garment.dart';
import 'add_item_screen.dart';
import 'accessory_3d_screen.dart';
import 'closet_widgets.dart';

/// One piece: photo, details, "Add to Outfit", edit and delete.
///
/// Accessories with a ready 3D model show the interactive viewer and their badge in
/// the header; "View in 3D" creates the model when there is none.
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

  void _toggle(Garment garment, OutfitTray tray) {
    final wasIn = tray.contains(garment.id);
    if (!tray.toggle(garment)) {
      setState(
        () => error = !garment.available
            ? 'This piece is not available right now.'
            : !garment.hasImage
            ? 'Add a photo to this piece to use it in a look.'
            : 'Your outfit is full. Remove a piece first.',
      );
      return;
    }
    setState(() => error = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(wasIn ? 'Removed from outfit' : 'Added to outfit'),
        duration: const Duration(seconds: 1),
      ),
    );
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
    listenable: Listenable.merge([
      widget.module.closet,
      widget.module.tray,
      widget.module.models3d,
    ]),
    builder: (context, _) {
      final closet = widget.module.closet;
      final tray = widget.module.tray;
      final models = widget.module.models3d;
      final garment = closet.garments
          .where((g) => g.id == widget.garmentId)
          .firstOrNull;
      if (garment == null) {
        return const MirageScreen(
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (garment.model3dCategory != null) models.ensure([garment.id]);
      final model = models.summary(garment.id);
      final inTray = tray.contains(garment.id);
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
                  child: model != null && model.ready
                      ? _ModelHeader(
                          key: ValueKey('model-header-${garment.id}'),
                          garment: garment,
                          closet: closet,
                          models: models,
                        )
                      : GarmentImage(garment: garment, closet: closet),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  child: Tag(
                    garment.available ? 'IN YOUR CLOSET' : 'UNAVAILABLE',
                  ),
                ),
                if (model?.badgeLabel case final badge?)
                  Positioned(top: 14, right: 14, child: ModelBadgeTag(badge)),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              garment.name,
              style: const TextStyle(
                fontFamily: 'Lora',
                fontSize: 30,
                height: 1.15,
              ),
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
            _row(
              'Availability',
              garment.available ? 'Available' : 'Unavailable',
            ),
            const SizedBox(height: 18),
            if (error != null) ...[
              MirageNotice(error!, error: true),
              const SizedBox(height: 12),
            ],
            if (garment.model3dCategory != null) ...[
              MirageButton(
                label: 'View in 3D',
                arrow: false,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Accessory3dScreen(
                      garment: garment,
                      api: widget.module.accessoryModels,
                      models: models,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (garment.model3dCategory == 'glasses') ...[
              OutlinedButton.icon(
                key: const ValueKey('try-on-glasses'),
                icon: const Icon(Icons.face_retouching_natural),
                label: const Text('Try on (AR)'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => GlassesTryOnScreen.forCloset(
                      widget.module,
                      initialGarmentId: garment.id,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            inTray
                ? OutlinedButton(
                    key: const ValueKey('toggle-outfit'),
                    onPressed: () => _toggle(garment, tray),
                    child: const Text('Remove from Outfit'),
                  )
                : MirageButton(
                    key: const ValueKey('toggle-outfit'),
                    label: '+ Add to Outfit',
                    arrow: false,
                    onPressed: () => _toggle(garment, tray),
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

/// Header of an accessory with a ready 3D model: the interactive viewer (full model),
/// with the background-free thumbnail while the GLB downloads. If the download fails
/// the thumbnail (or the photo) stays.
class _ModelHeader extends StatefulWidget {
  const _ModelHeader({
    super.key,
    required this.garment,
    required this.closet,
    required this.models,
  });
  final Garment garment;
  final ClosetController closet;
  final AccessoryModelsController models;

  @override
  State<_ModelHeader> createState() => _ModelHeaderState();
}

class _ModelHeaderState extends State<_ModelHeader> {
  // The data URI of a ~1 MB model is built once, not on every rebuild.
  late final Future<String> _src = widget.models
      .model(widget.garment.id)
      .then(
        (bytes) =>
            Uri.dataFromBytes(bytes, mimeType: 'model/gltf-binary').toString(),
      );

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _src,
    builder: (context, snapshot) => snapshot.data == null
        ? GarmentImage(
            garment: widget.garment,
            closet: widget.closet,
            models: widget.models,
          )
        : ModelViewer(
            key: const ValueKey('detail-model-viewer'),
            src: snapshot.data!,
            alt: '3D model of ${widget.garment.name}',
            backgroundColor: MirageColors.blue,
            cameraControls: true,
            ar: false,
          ),
  );
}
