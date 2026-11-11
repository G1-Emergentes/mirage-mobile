import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../shared/theme/mirage_theme.dart';
import '../../shared/widgets/mirage_components.dart';
import '../application/outfits_controller.dart';
import '../closet_module.dart';
import '../domain/closet_repository.dart';
import '../domain/garment.dart';
import '../domain/outfit.dart';
import 'closet_widgets.dart';
import 'try_on_screens.dart';

/// Route name of the outfit detail: leaving a try-on comes back here, not to the closet root.
const outfitDetailRoute = 'outfit-detail';
bool isOutfitOrRoot(Route<dynamic> route) =>
    route.isFirst || route.settings.name == outfitDetailRoute;

/// "Style · Occasion" of an outfit, or null when it has neither.
String? outfitSubtitle(SavedOutfit outfit) {
  final parts = [
    if (outfit.style != null) humanize(outfit.style!),
    if (outfit.occasion != null) outfit.occasion!,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

String _plural(int n) => '$n ${n == 1 ? 'piece' : 'pieces'}';

/// Name, style and occasion of an outfit. Returns null when dismissed.
Future<OutfitDetails?> showOutfitForm(
  BuildContext context, {
  SavedOutfit? editing,
}) => showModalBottomSheet<OutfitDetails>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _OutfitForm(editing: editing),
);

class _OutfitForm extends StatefulWidget {
  const _OutfitForm({this.editing});
  final SavedOutfit? editing;
  @override
  State<_OutfitForm> createState() => _OutfitFormState();
}

class _OutfitFormState extends State<_OutfitForm> {
  late final name = TextEditingController(text: widget.editing?.name);
  late final occasion = TextEditingController(text: widget.editing?.occasion);
  late String? style = widget.editing?.style;
  String? problem;

  @override
  void dispose() {
    name.dispose();
    occasion.dispose();
    super.dispose();
  }

  void _submit() {
    final title = name.text.trim();
    final where = occasion.text.trim();
    if (title.isEmpty) {
      setState(() => problem = 'Give your outfit a name.');
      return;
    }
    if (title.length > 120 || where.length > 50) {
      setState(() => problem = 'The name takes up to 120 characters and the occasion 50.');
      return;
    }
    Navigator.of(context).pop(
      OutfitDetails(
        name: title,
        occasion: where.isEmpty ? null : where,
        style: style,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      20 + MediaQuery.of(context).viewInsets.bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.editing == null ? 'Nuevo outfit' : 'Edit outfit',
            style: const TextStyle(fontFamily: 'Lora', fontSize: 26),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('outfit-name'),
            controller: name,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 6),
          const Text('Style', style: TextStyle(fontSize: 13, color: MirageColors.muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in closetStyles)
                ChoiceChip(
                  key: ValueKey('style-$option'),
                  label: Text(humanize(option)),
                  selected: style == option,
                  // Tapping the chosen style again clears it.
                  onSelected: (on) => setState(() => style = on ? option : null),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('outfit-occasion'),
            controller: occasion,
            maxLength: 50,
            decoration: const InputDecoration(
              labelText: 'Occasion (optional)',
              hintText: 'Work, party, everyday…',
            ),
          ),
          if (problem != null) ...[
            const SizedBox(height: 6),
            MirageNotice(problem!, error: true),
          ],
          const SizedBox(height: 14),
          MirageButton(
            key: const ValueKey('outfit-form-save'),
            label: widget.editing == null ? 'Crear outfit' : 'Save',
            arrow: false,
            onPressed: _submit,
          ),
        ],
      ),
    ),
  );
}

/// "Armar": pick one of your outfits to put this piece in, or create a new one.
Future<void> showArmarSheet(
  BuildContext context,
  ClosetModule module,
  Garment garment,
) {
  module.outfits.load();
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.8,
      child: _ArmarSheet(module: module, garment: garment, messenger: messenger),
    ),
  );
}

class _ArmarSheet extends StatefulWidget {
  const _ArmarSheet({
    required this.module,
    required this.garment,
    required this.messenger,
  });
  final ClosetModule module;
  final Garment garment;
  final ScaffoldMessengerState messenger;
  @override
  State<_ArmarSheet> createState() => _ArmarSheetState();
}

class _ArmarSheetState extends State<_ArmarSheet> {
  bool busy = false;
  String? error;

  Future<void> _run(Future<String> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final done = await action();
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.messenger.showSnackBar(SnackBar(content: Text(done)));
    } on ClosetException catch (e) {
      if (mounted) setState(() => error = OutfitsController.describe(e));
    } catch (_) {
      if (mounted) setState(() => error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _add(SavedOutfit outfit) => _run(() async {
    await widget.module.outfits.addGarment(outfit, widget.garment.id);
    return 'Added to ${outfit.name ?? 'your outfit'}';
  });

  Future<void> _createNew() async {
    final details = await showOutfitForm(context);
    if (details == null || !mounted) return;
    await _run(() async {
      await widget.module.outfits.create(details, [widget.garment.id]);
      return '${details.name} created';
    });
  }

  Widget _row(SavedOutfit outfit) {
    final has = outfit.garmentIds.contains(widget.garment.id);
    final full = outfit.garmentIds.length >= OutfitsController.maxPieces;
    final blocked = has || full || !widget.garment.available;
    final subtitle = outfitSubtitle(outfit);
    return Opacity(
      opacity: blocked ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          key: ValueKey('armar-${outfit.id}'),
          borderRadius: BorderRadius.circular(20),
          onTap: blocked || busy ? null : () => _add(outfit),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MirageColors.blue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        outfit.name ?? 'Outfit',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: MirageColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  has
                      ? 'Already in it'
                      : full
                      ? 'Full · 3/3'
                      : '${outfit.garmentIds.length}/3',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.module.outfits,
    builder: (context, _) {
      final outfits = widget.module.outfits;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Armar',
              style: const TextStyle(fontFamily: 'Lora', fontSize: 26),
            ),
            Text(
              'Add "${widget.garment.name}" to one of your outfits.',
              style: const TextStyle(fontSize: 13, color: MirageColors.muted),
            ),
            const SizedBox(height: 12),
            if (!widget.garment.available)
              const MirageNotice('This piece is not available right now.', error: true)
            else if (error != null)
              MirageNotice(error!, error: true),
            Expanded(
              child: outfits.loading && !outfits.loaded
                  ? const Center(child: CircularProgressIndicator())
                  : outfits.error != null && !outfits.loaded
                  ? Center(child: MirageNotice(outfits.error!, error: true))
                  : outfits.outfits.isEmpty
                  ? const Center(
                      child: Text(
                        'You have no outfits yet. Create the first one below.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: MirageColors.muted),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(top: 8),
                      children: [for (final o in outfits.outfits) _row(o)],
                    ),
            ),
            // Always visible, under the list.
            MirageButton(
              key: const ValueKey('crear-outfit'),
              label: 'Crear nuevo outfit',
              arrow: false,
              busy: busy,
              onPressed: widget.garment.available ? _createNew : null,
            ),
          ],
        ),
      );
    },
  );
}

/// On "Your AI Look": keeps the generated picture in the outfit the try-on came from.
class SaveLookButton extends StatefulWidget {
  const SaveLookButton({super.key, required this.module});
  final ClosetModule module;
  @override
  State<SaveLookButton> createState() => _SaveLookButtonState();
}

class _SaveLookButtonState extends State<SaveLookButton> {
  bool busy = false, failed = false;
  String? message;

  Future<void> _save(String outfitId, List<int> image) async {
    setState(() {
      busy = true;
      failed = false;
      message = null;
    });
    try {
      final saved = await widget.module.outfits.saveLook(
        outfitId,
        Uint8List.fromList(image),
      );
      message = 'Look saved in ${saved.name ?? 'your outfit'}.';
    } on ClosetException catch (e) {
      failed = true;
      message = OutfitsController.describe(e);
    } catch (_) {
      failed = true;
      message = 'Could not save the look. Try again.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.module.activeOutfitId;
    final image = widget.module.tryOn.result;
    if (id == null || image == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          key: const ValueKey('save-look'),
          onPressed: busy ? null : () => _save(id, image),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          child: Text(busy ? 'Saving…' : 'Save Look to Outfit'),
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          MirageNotice(message!, error: failed),
        ],
        const SizedBox(height: 10),
      ],
    );
  }
}

/// "Saved Outfits": what the user chose to keep. Tap one to open it.
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
    final subtitle = outfitSubtitle(outfit);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        key: ValueKey('outfit-${outfit.id}'),
        borderRadius: BorderRadius.circular(26),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: outfitDetailRoute),
            builder: (_) => OutfitDetailScreen(module: module, outfitId: outfit.id),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MirageColors.blue,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outfit.name ?? 'Outfit',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: MirageColors.muted,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      outfit.complete
                          ? _plural(outfit.garmentIds.length)
                          : 'Some pieces were removed.',
                      style: const TextStyle(fontSize: 12, color: MirageColors.muted),
                    ),
                    if (outfit.hasImage)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Tag('LOOK SAVED', color: MirageColors.lime),
                      ),
                  ],
                ),
              ),
              for (final garment in pieces.take(3))
                SizedBox(
                  width: 56,
                  height: 72,
                  child: GarmentImage(garment: garment, closet: module.closet),
                ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.module.outfits, widget.module.closet]),
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
                'No outfits yet. Open a piece and tap Armar to create your first one.',
              )
            else
              for (final outfit in outfits.outfits) _card(outfit),
          ],
        ),
      );
    },
  );
}

/// One outfit: its look, its pieces (change them), try it on, edit or delete it.
class OutfitDetailScreen extends StatefulWidget {
  const OutfitDetailScreen({
    super.key,
    required this.module,
    required this.outfitId,
  });
  final ClosetModule module;
  final String outfitId;
  @override
  State<OutfitDetailScreen> createState() => _OutfitDetailScreenState();
}

class _OutfitDetailScreenState extends State<OutfitDetailScreen> {
  bool busy = false;
  String? error;

  Future<void> _guard(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } on ClosetException catch (e) {
      if (mounted) setState(() => error = OutfitsController.describe(e));
    } catch (_) {
      if (mounted) setState(() => error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _edit(SavedOutfit outfit) async {
    final details = await showOutfitForm(context, editing: outfit);
    if (details == null || !mounted) return;
    await _guard(() => widget.module.outfits.update(outfit, details: details));
  }

  Future<void> _delete(SavedOutfit outfit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this outfit?'),
        content: Text('"${outfit.name ?? 'Outfit'}" will be removed. Your pieces stay in your closet.'),
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
    await _guard(() async {
      await widget.module.outfits.remove(outfit.id);
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _tryOn(SavedOutfit outfit, List<Garment> pieces) async {
    final module = widget.module;
    module.tray.clear();
    for (final garment in pieces) {
      module.tray.toggle(garment); // skips pieces without photo or unavailable
    }
    if (module.tray.isEmpty) {
      setState(
        () => error = 'To try it on, the pieces need a photo and must be available.',
      );
      return;
    }
    module.activeOutfitId = outfit.id;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ReadyToTryScreen(module: module)),
    );
    module.tray.clear();
    module.activeOutfitId = null;
  }

  Widget _pieceRow(SavedOutfit outfit, String id, Garment? garment) {
    final module = widget.module;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: garment == null
                  ? const Icon(Icons.help_outline)
                  : GarmentImage(garment: garment, closet: module.closet),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                garment?.name ?? 'This piece is no longer in your closet',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              key: ValueKey('drop-$id'),
              tooltip: 'Remove from outfit',
              icon: const Icon(Icons.close, size: 20),
              // An outfit keeps at least one piece; delete the outfit to remove it all.
              onPressed: busy || outfit.garmentIds.length < 2
                  ? null
                  : () => _guard(() => module.outfits.removeGarment(outfit, id)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.module.outfits, widget.module.closet]),
    builder: (context, _) {
      final module = widget.module;
      final outfit = module.outfits.byId(widget.outfitId);
      if (outfit == null) {
        return const MirageScreen(child: Center(child: Text('This outfit is gone.')));
      }
      final pieces = <Garment>[
        for (final id in outfit.garmentIds)
          ...module.closet.garments.where((garment) => garment.id == id),
      ];
      final subtitle = outfitSubtitle(outfit);
      return MirageScreen(
        topPadding: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClosetTopBar(onBack: () => Navigator.of(context).pop()),
            const SizedBox(height: 8),
            Text(outfit.name ?? 'Outfit', style: titleStyle),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 15, color: MirageColors.muted),
              ),
            ],
            const SizedBox(height: 16),
            if (outfit.hasImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: _OutfitImage(
                    key: ValueKey('look-${outfit.id}-${outfit.imageVersion}'),
                    outfits: module.outfits,
                    id: outfit.id,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              _plural(outfit.garmentIds.length),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final id in outfit.garmentIds)
              _pieceRow(
                outfit,
                id,
                pieces.where((garment) => garment.id == id).firstOrNull,
              ),
            const SizedBox(height: 6),
            if (error != null) ...[
              MirageNotice(error!, error: true),
              const SizedBox(height: 12),
            ],
            MirageButton(
              key: const ValueKey('outfit-try-on'),
              label: 'Try on',
              arrow: false,
              busy: busy,
              onPressed: () => _tryOn(outfit, pieces),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              key: const ValueKey('outfit-edit'),
              onPressed: busy ? null : () => _edit(outfit),
              child: const Text('Edit details'),
            ),
            Center(
              child: TextButton(
                key: const ValueKey('outfit-delete'),
                onPressed: busy ? null : () => _delete(outfit),
                child: const Text('Delete outfit'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// The saved look, fetched through a short-lived signed URL.
class _OutfitImage extends StatefulWidget {
  const _OutfitImage({super.key, required this.outfits, required this.id});
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
