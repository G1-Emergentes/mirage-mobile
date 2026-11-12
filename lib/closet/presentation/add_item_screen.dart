import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/theme/mirage_theme.dart';
import '../../shared/widgets/mirage_components.dart';
import '../application/closet_controller.dart';
import '../closet_module.dart';
import '../domain/closet_repository.dart';
import '../domain/garment.dart';
import 'closet_widgets.dart';

/// "Add New Item" (a photo plus a few details) and, with `editing`, "Edit Item".
class AddItemScreen extends StatefulWidget {
  const AddItemScreen({
    super.key,
    required this.module,
    this.editing,
    this.initialCategory,
  });
  final ClosetModule module;
  final Garment? editing;
  final String? initialCategory;
  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final name = TextEditingController();
  final form = GlobalKey<FormState>();
  String? category, subcategory, color, style;
  PickedPhoto? photo;
  String? error;
  bool busy = false, picking = false;

  bool get isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final garment = widget.editing;
    category = garment?.category ?? widget.initialCategory;
    if (garment != null) {
      name.text = garment.name;
      if (garment.category == 'ACCESSORY') subcategory = garment.subcategory;
      color = garment.colors.firstOrNull;
      style = garment.styles.firstOrNull;
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      picking = true;
      error = null;
    });
    try {
      final picked = await pickPhoto(source);
      if (picked != null && mounted) setState(() => photo = picked);
    } catch (e) {
      if (mounted) setState(() => error = photoProblem(e));
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  GarmentDraft _draft() {
    final colorLabel = color == null ? '' : '${humanize(color!)} ';
    final original = widget.editing;
    return GarmentDraft(
      name: name.text.trim(),
      category: category!,
      subcategory: category == 'ACCESSORY'
          ? subcategory
          : original?.category == category
          ? original?.subcategory
          : null,
      colors: color == null ? const [] : [color!],
      styles: style == null ? const [] : [style!],
      description: '$colorLabel${humanize(category!).toLowerCase()}'.trim(),
      available: original?.available ?? true,
    );
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    if (!isEdit && photo == null) {
      setState(() => error = 'Add a photo of your piece first.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (isEdit) {
        await widget.module.closet.save(
          widget.editing!.id,
          _draft(),
          photo: photo?.bytes,
          contentType: photo?.contentType,
        );
      } else {
        await widget.module.closet.add(
          _draft(),
          photo!.bytes,
          photo!.contentType,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ClosetException catch (e) {
      if (mounted) setState(() => error = ClosetController.describe(e));
    } catch (_) {
      if (mounted) setState(() => error = 'Could not save your piece.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _photoBox() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: MirageColors.blue,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: MirageColors.muted.withValues(alpha: 0.5)),
    ),
    child: Column(
      children: [
        if (photo != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 190,
              child: Image.memory(photo!.bytes, fit: BoxFit.contain),
            ),
          )
        else if (widget.editing case final garment? when garment.hasImage)
          SizedBox(
            height: 190,
            child: GarmentImage(garment: garment, closet: widget.module.closet),
          )
        else ...[
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Icon(Icons.add_photo_alternate_outlined, size: 28),
          ),
          const SizedBox(height: 12),
          const Text(
            'Give your piece a close-up.',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'A clear photo works best. No clutter needed.',
            style: TextStyle(fontSize: 12, color: MirageColors.muted),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('take-photo'),
                onPressed: picking || busy
                    ? null
                    : () => _pick(ImageSource.camera),
                style: FilledButton.styleFrom(
                  backgroundColor: MirageColors.ink,
                  minimumSize: const Size(0, 46),
                ),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Take Photo'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('upload-photo'),
                onPressed: picking || busy
                    ? null
                    : () => _pick(ImageSource.gallery),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: MirageColors.ink,
                  minimumSize: const Size(0, 46),
                ),
                icon: const Icon(Icons.upload_outlined, size: 18),
                label: const Text('Upload Photo'),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _dropdown({
    required String label,
    required String hint,
    required List<String> options,
    required String? value,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
    Key? fieldKey,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 7),
      DropdownButtonFormField<String>(
        key: fieldKey,
        initialValue: value,
        isExpanded: true,
        hint: Text(hint),
        validator: validator,
        onChanged: busy ? null : onChanged,
        items: [
          for (final option in options)
            DropdownMenuItem(value: option, child: Text(humanize(option))),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => MirageScreen(
    topPadding: 0,
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClosetTopBar(
            onBack: () => Navigator.of(context).pop(),
            trailing: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Close',
              icon: const Icon(Icons.close, size: 22),
            ),
          ),
          const SizedBox(height: 8),
          Text(isEdit ? 'Edit Item' : 'Add New Item', style: titleStyle),
          const SizedBox(height: 6),
          Text(
            isEdit
                ? 'Change what is not quite right.'
                : 'One photo. A whole new possibility.',
            style: const TextStyle(fontSize: 15, color: MirageColors.muted),
          ),
          const SizedBox(height: 16),
          if (!isEdit || category == 'ACCESSORY') ...[
            _photoBox(),
            const SizedBox(height: 18),
          ],
          MirageField(
            label: 'Name',
            controller: name,
            hint: 'e.g. White oversized shirt',
            enabled: !busy,
            validator: (v) {
              final text = (v ?? '').trim();
              return text.isEmpty || text.length > 120
                  ? 'Give it a name (up to 120 characters)'
                  : null;
            },
          ),
          const SizedBox(height: 14),
          _dropdown(
            fieldKey: const ValueKey('category'),
            label: 'Category',
            hint: 'Select category',
            options: closetCategories,
            value: category,
            onChanged: (v) => setState(() => category = v),
            validator: (v) => v == null ? 'Choose a category' : null,
          ),
          if (category == 'ACCESSORY') ...[
            const SizedBox(height: 14),
            _dropdown(
              fieldKey: const ValueKey('accessory-type'),
              label: 'Accessory type',
              hint: 'Choose glasses, hat or other',
              options: {
                'GLASSES',
                'SUNGLASSES',
                'CAP',
                'HAT',
                'OTHER',
                ?subcategory,
              }.toList(),
              value: subcategory,
              onChanged: (v) => setState(() => subcategory = v),
            ),
          ],
          const SizedBox(height: 14),
          _dropdown(
            fieldKey: const ValueKey('color'),
            label: 'Color',
            hint: 'Select color',
            options: closetColors,
            value: color,
            onChanged: (v) => setState(() => color = v),
          ),
          const SizedBox(height: 14),
          _dropdown(
            fieldKey: const ValueKey('style'),
            label: 'Style',
            hint: 'Select style',
            options: closetStyles,
            value: style,
            onChanged: (v) => setState(() => style = v),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: MirageColors.pink),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI recognition is coming soon. For now, fill in the details.',
                  style: TextStyle(fontSize: 12, color: MirageColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (error != null) ...[
            MirageNotice(error!, error: true),
            const SizedBox(height: 12),
          ],
          MirageButton(
            key: const ValueKey('save-item'),
            label: isEdit ? 'Save changes' : 'Save Item',
            busy: busy,
            onPressed: picking ? null : _save,
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Your photos stay private. Your closet stays yours.',
              style: TextStyle(fontSize: 11, color: MirageColors.muted),
            ),
          ),
        ],
      ),
    ),
  );
}
