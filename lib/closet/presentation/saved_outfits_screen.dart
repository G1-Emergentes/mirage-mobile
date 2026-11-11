import 'package:flutter/material.dart';
import '../../shared/theme/mirage_theme.dart';
import '../../shared/widgets/mirage_components.dart';
import '../application/outfits_controller.dart';
import '../application/try_on_controller.dart';
import '../closet_module.dart';
import '../domain/closet_repository.dart';
import '../domain/outfit.dart';
import 'closet_widgets.dart';

/// Saves the pieces in the tray as an outfit. If a look was already generated for exactly
/// these pieces, its picture is saved with the outfit.
class SaveOutfitButton extends StatefulWidget {
  const SaveOutfitButton({super.key, required this.module});
  final ClosetModule module;
  @override
  State<SaveOutfitButton> createState() => _SaveOutfitButtonState();
}

class _SaveOutfitButtonState extends State<SaveOutfitButton> {
  bool busy = false, failed = false;
  String? message;

  Future<void> _save() async {
    final module = widget.module;
    final ids = [for (final garment in module.tray.items) garment.id];
    if (ids.isEmpty) return;
    final tryOn = module.tryOn;
    final sameLook =
        tryOn.phase == TryOnPhase.ready &&
        tryOn.generatedFor.length == ids.length &&
        tryOn.generatedFor.toSet().containsAll(ids);
    final image = sameLook ? tryOn.result : null;
    setState(() {
      busy = true;
      failed = false;
      message = null;
    });
    try {
      final saved = await module.outfits.save(ids, image: image);
      message = image == null
          ? 'Outfit saved.'
          : saved.hasImage
          ? 'Outfit saved with your look.'
          : 'Outfit saved, but the look picture could not be saved.';
    } on ClosetException catch (e) {
      failed = true;
      message = OutfitsController.describe(e);
    } catch (_) {
      failed = true;
      message = 'Could not save the outfit. Try again.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton(
        key: const ValueKey('save-outfit'),
        onPressed: busy ? null : _save,
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
        child: Text(busy ? 'Saving…' : 'Save Outfit'),
      ),
      if (message != null) ...[
        const SizedBox(height: 8),
        MirageNotice(message!, error: failed),
      ],
    ],
  );
}

/// "Saved Outfits": what the user chose to keep.
class SavedOutfitsScreen extends StatefulWidget {
  const SavedOutfitsScreen({super.key, required this.module});
  final ClosetModule module;
  @override
  State<SavedOutfitsScreen> createState() => _SavedOutfitsScreenState();
}

class _SavedOutfitsScreenState extends State<SavedOutfitsScreen> {
  @override
  void initState() {
    super.initState();
    widget.module.outfits.load();
  }

  Widget _card(SavedOutfit outfit) {
    final module = widget.module;
    final pieces = [
      for (final id in outfit.garmentIds)
        ...module.closet.garments.where((garment) => garment.id == id),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MirageColors.blue,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  outfit.name ?? 'Outfit',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('remove-outfit-${outfit.id}'),
                tooltip: 'Remove outfit',
                icon: const Icon(Icons.delete_outline, size: 22),
                onPressed: () => module.outfits.remove(outfit.id).catchError((
                  _,
                ) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not remove the outfit.'),
                      ),
                    );
                  }
                }),
              ),
            ],
          ),
          if (outfit.hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: _OutfitImage(outfits: module.outfits, id: outfit.id),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                for (final garment in pieces)
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: GarmentImage(garment: garment, closet: module.closet),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            outfit.complete
                ? '${outfit.garmentIds.length} ${outfit.garmentIds.length == 1 ? 'piece' : 'pieces'}'
                : 'Some pieces were removed from your closet.',
            style: const TextStyle(fontSize: 12, color: MirageColors.muted),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.module.outfits,
    builder: (context, _) {
      final outfits = widget.module.outfits;
      return MirageScreen(
        topPadding: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClosetTopBar(onBack: () => Navigator.of(context).pop()),
            const SizedBox(height: 8),
            const Text('Saved Outfits', style: titleStyle),
            const SizedBox(height: 16),
            if (outfits.loading && !outfits.loaded)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (outfits.error != null && !outfits.loaded) ...[
              MirageNotice(outfits.error!, error: true),
              const SizedBox(height: 12),
              MirageButton(
                label: 'Try again',
                arrow: false,
                onPressed: outfits.load,
              ),
            ] else if (outfits.outfits.isEmpty)
              const MirageNotice(
                'No saved outfits yet. Pick pieces, tap Try on and then Save Outfit.',
              )
            else
              for (final outfit in outfits.outfits) _card(outfit),
          ],
        ),
      );
    },
  );
}

/// The saved look, fetched through a short-lived signed URL.
class _OutfitImage extends StatefulWidget {
  const _OutfitImage({required this.outfits, required this.id});
  final OutfitsController outfits;
  final String id;
  @override
  State<_OutfitImage> createState() => _OutfitImageState();
}

class _OutfitImageState extends State<_OutfitImage> {
  late final Future<String?> url = widget.outfits.imageUrl(widget.id);

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: url,
    builder: (context, snapshot) {
      final link = snapshot.data;
      if (link == null) {
        return const ColoredBox(
          color: MirageColors.lavender,
          child: Center(child: Icon(Icons.image_outlined)),
        );
      }
      return Image.network(link, fit: BoxFit.cover, gaplessPlayback: true);
    },
  );
}
