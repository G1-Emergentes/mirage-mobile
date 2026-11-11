import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/theme/mirage_theme.dart';
import '../../shared/widgets/mirage_components.dart';
import '../application/closet_controller.dart';
import '../application/outfit_tray.dart';
import '../domain/closet_repository.dart';
import '../domain/garment.dart';

const _tints = [MirageColors.blue, MirageColors.lavender, Color(0xFFEEEBE4)];
Color tintFor(int index) => _tints[index % _tints.length];

const titleStyle = TextStyle(fontFamily: 'Lora', fontSize: 40, height: 1.08);

/// Back arrow, wordmark and an optional action, like the closet screens of the design.
class ClosetTopBar extends StatelessWidget {
  const ClosetTopBar({super.key, this.onBack, this.trailing});
  final VoidCallback? onBack;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Row(
      children: [
        SizedBox(
          width: 48,
          child: onBack == null
              ? null
              : IconButton(
                  onPressed: onBack,
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back, size: 22),
                ),
        ),
        const Expanded(child: Center(child: MirageWordmark(size: 17))),
        SizedBox(width: 48, child: trailing),
      ],
    ),
  );
}

class ClosetChips extends StatelessWidget {
  const ClosetChips({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(labels[i]),
              selected: selected == i,
              showCheckmark: false,
              onSelected: (_) => onSelected(i),
              selectedColor: MirageColors.ink,
              backgroundColor: const Color(0xFFEEEBE4),
              side: BorderSide.none,
              shape: const StadiumBorder(),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected == i ? Colors.white : MirageColors.ink,
              ),
            ),
          ),
      ],
    ),
  );
}

/// The garment photo, fetched through a short-lived signed link.
class GarmentImage extends StatelessWidget {
  const GarmentImage({
    super.key,
    required this.garment,
    required this.closet,
    this.fit = BoxFit.contain,
  });
  final Garment garment;
  final ClosetController closet;
  final BoxFit fit;

  Widget get _placeholder => const Center(
    child: Icon(Icons.checkroom_outlined, color: MirageColors.muted, size: 32),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: closet.imageUrl(garment),
    builder: (context, snapshot) {
      final url = snapshot.data;
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      if (url == null) return _placeholder;
      return Image.network(
        url,
        fit: fit,
        errorBuilder: (_, _, _) => _placeholder,
      );
    },
  );
}

/// A garment card of the category grid. Tapping the check selects it for the outfit.
class GarmentTile extends StatelessWidget {
  const GarmentTile({
    super.key,
    required this.garment,
    required this.closet,
    required this.tray,
    required this.tint,
    required this.onTap,
  });
  final Garment garment;
  final ClosetController closet;
  final OutfitTray tray;
  final Color tint;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: tray,
    builder: (context, _) {
      final picked = tray.contains(garment.id);
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(20),
                      border: picked
                          ? Border.all(color: MirageColors.pink, width: 2)
                          : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: GarmentImage(garment: garment, closet: closet),
                    ),
                  ),
                  if (picked)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: MirageColors.pink,
                        child: Icon(Icons.check, size: 15, color: Colors.white),
                      ),
                    ),
                  if (!garment.available)
                    const Positioned(top: 8, left: 8, child: Tag('Unavailable')),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              garment.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            Text(
              garment.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: MirageColors.muted),
            ),
          ],
        ),
      );
    },
  );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = Colors.white});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
    ),
  );
}

class PickedPhoto {
  const PickedPhoto(this.bytes, this.contentType);
  final Uint8List bytes;
  final String contentType;
}

/// The real type of a photo from its first bytes; null when it is not JPEG, PNG or WebP.
/// The file name is not trusted: the picker may re-encode the image.
String? sniffContentType(Uint8List bytes) {
  if (bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
    return 'image/jpeg';
  }
  if (bytes.length > 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length > 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}

/// Camera or gallery. Throws ClosetException('INVALID_PHOTO') for a file that is not a
/// JPEG, PNG or WebP up to 8 MB.
Future<PickedPhoto?> pickPhoto(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 2560,
    maxHeight: 2560,
    imageQuality: 90,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final type = sniffContentType(bytes);
  if (type == null || bytes.length > 8 * 1024 * 1024) {
    throw const ClosetException('INVALID_PHOTO');
  }
  return PickedPhoto(bytes, type);
}

String photoProblem(Object error) =>
    error is ClosetException && error.code == 'INVALID_PHOTO'
    ? 'Use a JPEG, PNG or WebP photo up to 8 MB.'
    : 'Could not open this photo. Allow camera/photos access and try again.';
