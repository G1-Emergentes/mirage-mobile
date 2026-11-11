import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../avatar/application/person_photo.dart';
import '../../shared/theme/mirage_theme.dart';
import '../../shared/widgets/mirage_components.dart';
import '../application/try_on_controller.dart';
import '../closet_module.dart';
import '../domain/closet_repository.dart';
import 'closet_widgets.dart';

/// The picked pieces laid out on a tinted board.
Widget outfitBoard(ClosetModule module, {double height = 230}) =>
    ListenableBuilder(
      listenable: module.tray,
      builder: (context, _) => Container(
        width: double.infinity,
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MirageColors.blue,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final garment in module.tray.items)
              SizedBox(
                width: module.tray.items.length == 1 ? 180 : 112,
                height: module.tray.items.length == 1 ? height - 32 : 100,
                child: GarmentImage(garment: garment, closet: module.closet),
              ),
          ],
        ),
      ),
    );

/// "Ready to Try": the pieces, the photo to use and the consent, before generating.
class ReadyToTryScreen extends StatefulWidget {
  const ReadyToTryScreen({super.key, required this.module});
  final ClosetModule module;
  @override
  State<ReadyToTryScreen> createState() => _ReadyToTryScreenState();
}

class _ReadyToTryScreenState extends State<ReadyToTryScreen> {
  bool consent = false, picking = false;
  String? error;

  Future<void> _pick(ImageSource source) async {
    setState(() {
      picking = true;
      error = null;
    });
    try {
      final picked = await pickPhoto(source);
      if (picked != null) PersonPhoto.bytes = picked.bytes;
    } catch (e) {
      error = photoProblem(e);
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.module.tray,
    builder: (context, _) {
      final pieces = widget.module.tray.items.length;
      final photo = PersonPhoto.bytes;
      return MirageScreen(
        topPadding: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClosetTopBar(
              onBack: () => Navigator.of(context).pop(),
              trailing: IconButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                tooltip: 'Close',
                icon: const Icon(Icons.close, size: 22),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Ready to Try', style: titleStyle),
            const SizedBox(height: 6),
            const Text(
              'Your preview, your way',
              style: TextStyle(fontSize: 15, color: MirageColors.muted),
            ),
            const SizedBox(height: 16),
            if (pieces == 0)
              const MirageNotice(
                'Pick up to 3 pieces from your closet first: open a piece and tap Add to Outfit.',
              )
            else
              outfitBoard(widget.module),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: photo == null
                              ? const ColoredBox(
                                  color: MirageColors.lavender,
                                  child: Icon(Icons.person_outline),
                                )
                              : Image.memory(photo, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Made for you',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '$pieces ${pieces == 1 ? 'piece' : 'pieces'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: MirageColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Photo',
                        style: TextStyle(color: MirageColors.muted),
                      ),
                      Flexible(
                        child: Text(
                          photo == null
                              ? 'Saved avatar photo'
                              : 'Body photo added ✓',
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('photo-camera'),
                    onPressed: picking ? null : () => _pick(ImageSource.camera),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                    child: const Text('Take photo'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('photo-gallery'),
                    onPressed: picking
                        ? null
                        : () => _pick(ImageSource.gallery),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                    child: Text(
                      photo == null ? 'Upload body photo' : 'Replace photo',
                    ),
                  ),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              MirageNotice(error!, error: true),
            ],
            const SizedBox(height: 12),
            const MirageNotice(
              'AI previews are visual approximations and may differ from real garment fit, proportions or fabric behavior.',
            ),
            CheckboxListTile(
              key: const ValueKey('consent'),
              contentPadding: EdgeInsets.zero,
              value: consent,
              onChanged: (v) => setState(() => consent = v!),
              title: const Text(
                'I agree to send my photo and these pieces to an image-generation service to create this preview. Nothing is stored on a server.',
                style: TextStyle(fontSize: 11),
              ),
            ),
            MirageButton(
              key: const ValueKey('generate'),
              label: 'Generate My Look',
              arrow: false,
              onPressed: pieces == 0 || !consent || picking
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CreatingLookScreen(module: widget.module),
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'Your photos stay private. Your style stays yours.',
                style: TextStyle(fontSize: 11, color: MirageColors.muted),
              ),
            ),
          ],
        ),
      );
    },
  );
}

enum _Step { done, running, next }

/// "Creating your look": follows the job and moves on when the image is ready.
class CreatingLookScreen extends StatefulWidget {
  const CreatingLookScreen({super.key, required this.module});
  final ClosetModule module;
  @override
  State<CreatingLookScreen> createState() => _CreatingLookScreenState();
}

class _CreatingLookScreenState extends State<CreatingLookScreen> {
  bool _moved = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    final module = widget.module;
    module.tryOn.start(module.tray.items, PersonPhoto.bytes);
  }

  List<_Step> _steps(TryOnController tryOn) => switch (tryOn.phase) {
    TryOnPhase.ready => [_Step.done, _Step.done, _Step.done],
    _ =>
      tryOn.state == TryOnState.processing
          ? [_Step.done, _Step.running, _Step.next]
          : [_Step.running, _Step.next, _Step.next],
  };

  Widget _stepRow(String label, _Step step) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Icon(
          step == _Step.done
              ? Icons.check
              : step == _Step.running
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          size: 18,
          color: step == _Step.running ? MirageColors.pink : MirageColors.ink,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: step == _Step.running
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          ),
        ),
        Text(
          switch (step) {
            _Step.done => 'Done',
            _Step.running => 'In progress',
            _Step.next => 'Up next',
          },
          style: const TextStyle(fontSize: 12, color: MirageColors.muted),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.module.tryOn,
    builder: (context, _) {
      final module = widget.module;
      final tryOn = module.tryOn;
      if (tryOn.phase == TryOnPhase.ready && !_moved) {
        _moved = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => AiLookScreen(module: module)),
          );
        });
      }
      final failed = tryOn.phase == TryOnPhase.failed;
      final steps = _steps(tryOn);
      return MirageScreen(
        topPadding: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClosetTopBar(
              onBack: () => Navigator.of(context).pop(),
              trailing: IconButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                tooltip: 'Close',
                icon: const Icon(Icons.close, size: 22),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: MirageColors.lavender,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (module.tray.items.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(36),
                      child: GarmentImage(
                        garment: module.tray.items.first,
                        closet: module.closet,
                      ),
                    ),
                  const Positioned(
                    top: 22,
                    right: 26,
                    child: Icon(Icons.auto_awesome, color: MirageColors.pink),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text('Creating your look ✦', style: titleStyle),
            const SizedBox(height: 8),
            const Text(
              'A fresh perspective on your favorite pieces.',
              style: TextStyle(fontSize: 15, color: MirageColors.muted),
            ),
            const SizedBox(height: 18),
            if (failed) ...[
              MirageNotice(tryOn.error ?? 'Could not create your look.', error: true),
              const SizedBox(height: 14),
              MirageButton(
                key: const ValueKey('retry'),
                label: 'Try again',
                arrow: false,
                onPressed: _start,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back'),
              ),
            ] else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: tryOn.progress,
                  minHeight: 6,
                  color: MirageColors.pink,
                  backgroundColor: MirageColors.border,
                ),
              ),
              const SizedBox(height: 10),
              _stepRow('Analyzing outfit', steps[0]),
              _stepRow('Adjusting proportions', steps[1]),
              _stepRow('Creating preview', steps[2]),
            ],
          ],
        ),
      );
    },
  );
}

/// "Your AI Look": the generated image.
class AiLookScreen extends StatelessWidget {
  const AiLookScreen({super.key, required this.module});
  final ClosetModule module;

  @override
  Widget build(BuildContext context) {
    final image = module.tryOn.result;
    return MirageScreen(
      topPadding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClosetTopBar(onBack: () => Navigator.of(context).pop()),
          const SizedBox(height: 8),
          const Text('Your AI Look', style: titleStyle),
          const SizedBox(height: 14),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: image == null
                      ? const ColoredBox(color: MirageColors.lavender)
                      : Image.memory(
                          image,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                ),
              ),
              const Positioned(
                top: 14,
                left: 14,
                child: Tag('AI Preview', color: MirageColors.lime),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'AI visual preview. Actual fit may vary.',
              style: TextStyle(fontSize: 12, color: MirageColors.muted),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('regenerate'),
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => CreatingLookScreen(module: module),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: const Text('Regenerate'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('compare'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CompareLookScreen(module: module),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: const Text('Compare'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          MirageButton(
            key: const ValueKey('edit-outfit'),
            label: 'Edit Outfit',
            arrow: false,
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Saving and sharing looks are coming soon.',
              style: TextStyle(fontSize: 11, color: MirageColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Compare Look": the styling board next to the preview on you.
class CompareLookScreen extends StatelessWidget {
  const CompareLookScreen({super.key, required this.module});
  final ClosetModule module;

  @override
  Widget build(BuildContext context) {
    final image = module.tryOn.result;
    return MirageScreen(
      topPadding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClosetTopBar(
            onBack: () => Navigator.of(context).pop(),
            trailing: IconButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              tooltip: 'Close',
              icon: const Icon(Icons.close, size: 22),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Compare Look', style: titleStyle),
          const SizedBox(height: 6),
          const Text(
            'From your styling board to you.',
            style: TextStyle(fontSize: 15, color: MirageColors.muted),
          ),
          const SizedBox(height: 16),
          const Text(
            'Original Outfit',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          outfitBoard(module, height: 190),
          const SizedBox(height: 16),
          const Text(
            'AI Preview on You',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: image == null
                  ? const ColoredBox(color: MirageColors.lavender)
                  : Image.memory(image, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Same pieces. A personalized visual approximation.',
              style: TextStyle(fontSize: 11, color: MirageColors.muted),
            ),
          ),
          const SizedBox(height: 16),
          MirageButton(
            label: 'Edit Outfit',
            arrow: false,
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
    );
  }
}
