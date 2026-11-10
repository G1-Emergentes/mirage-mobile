import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../shared/theme/mirage_theme.dart';
import '../../shared/widgets/mirage_components.dart';

class MeasurementsScreen extends StatefulWidget {
  const MeasurementsScreen({
    super.key,
    required this.initial,
    required this.fit,
    required this.onContinue,
  });
  final Map<String, double?> initial;
  final String fit;
  final Future<bool> Function(Map<String, double?>, String) onContinue;
  @override
  State<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends State<MeasurementsScreen> {
  static const labels = {
    'height': 'Height',
    'chest': 'Chest / Bust',
    'waist': 'Waist',
    'hip': 'Hips',
    'shoulderWidth': 'Shoulder width — Optional',
  };
  static const limits = {
    'height': [130, 220],
    'chest': [40, 200],
    'waist': [35, 200],
    'hip': [40, 220],
    'shoulderWidth': [20, 80],
  };
  late final fields = {
    for (final name in labels.keys)
      name: TextEditingController(
        text: widget.initial[name]?.toStringAsFixed(1) ?? '',
      ),
  };
  late String fit = widget.fit;
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> apply() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    final values = {
      for (final e in fields.entries)
        e.key: double.tryParse(e.value.text.replaceAll(',', '.')),
    };
    final success = await widget.onContinue(values, fit);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() {
        busy = false;
        error = 'Could not update your preview. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: MirageScreen(
      topPadding: 0,
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: busy ? null : () => Navigator.pop(context),
                  icon: SvgPicture.asset(
                    'assets/avatar/back.svg',
                    width: 22,
                    height: 22,
                  ),
                ),
                const MirageWordmark(size: 17),
                IconButton(
                  tooltip: 'Close',
                  onPressed: busy ? null : () => Navigator.pop(context),
                  icon: SvgPicture.asset(
                    'assets/avatar/close.svg',
                    width: 22,
                    height: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Your Measurements',
              style: TextStyle(fontFamily: 'Lora', fontSize: 36, height: 1.08),
            ),
            const SizedBox(height: 12),
            const Text(
              '02 / 03 · Review and make it yours',
              style: TextStyle(fontSize: 14, color: MirageColors.muted),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MirageColors.blue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Photo estimates are approximate. Correct them with a tape measure. Only height is required.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            for (final e in labels.entries) ...[
              Text(
                e.value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              TextFormField(
                key: ValueKey(e.key),
                controller: fields[e.key],
                enabled: !busy,
                style: const TextStyle(fontSize: 14),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  hintText: 'Add measurement',
                  suffixText: 'cm',
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(17),
                    child: SvgPicture.asset(
                      'assets/avatar/pencil.svg',
                      width: 13.33,
                      height: 13.33,
                    ),
                  ),
                ),
                validator: (text) {
                  if ((text ?? '').trim().isEmpty) {
                    return e.key == 'height' ? 'Height is required' : null;
                  }
                  final number = double.tryParse(text!.replaceAll(',', '.')),
                      range = limits[e.key]!;
                  return number == null ||
                          !number.isFinite ||
                          number < range[0] ||
                          number > range[1]
                      ? '${range[0]}–${range[1]} cm'
                      : null;
                },
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'Fit Preference',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final value in ['Fitted', 'Regular', 'Oversized'])
                  ChoiceChip(
                    label: Text(
                      value,
                      style: TextStyle(
                        fontSize: 11,
                        color: fit == value ? Colors.white : MirageColors.muted,
                      ),
                    ),
                    selected: fit == value,
                    showCheckmark: false,
                    selectedColor: MirageColors.ink,
                    onSelected: busy
                        ? null
                        : (_) => setState(() => fit = value),
                    shape: const StadiumBorder(),
                  ),
              ],
            ),
            if (error != null) MirageNotice(error!, error: true),
            const SizedBox(height: 16),
            MirageButton(
              label: 'Continue',
              busy: busy,
              arrow: false,
              onPressed: apply,
            ),
            const SizedBox(height: 12),
            const Text(
              'Edits adjust the preview approximately; they do not prove clothing fit.',
              style: TextStyle(fontSize: 10, color: MirageColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}
