import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../shared/theme/mirage_theme.dart';
import '../../shared/widgets/mirage_components.dart';
import '../application/avatar_controller.dart';
import '../application/person_photo.dart';
import '../domain/avatar_repository.dart';
import '../infrastructure/dio_avatar_repository.dart';
import 'measurements_screen.dart';

class AvatarScreen extends StatefulWidget {
  const AvatarScreen({super.key, this.controller, this.accessToken});
  final AvatarController? controller;
  final Future<String> Function()? accessToken;
  @override
  State<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends State<AvatarScreen> {
  late final AvatarController controller;
  final photos = <Uint8List?>[null, null, null];
  final height = TextEditingController(), weight = TextEditingController();
  final form = GlobalKey<FormState>();
  String? photoError;
  bool consent = false, picking = false;
  // Fallback when the saved avatar cannot be opened: a body photo for outfit previews.
  bool previewConsent = false, photoKept = false;
  @override
  void initState() {
    super.initState();
    controller =
        widget.controller ??
        AvatarController(DioAvatarRepository(accessToken: widget.accessToken));
    if (widget.controller == null) controller.restore();
    _recoverPhoto().catchError((_) {
      if (mounted) {
        setState(
          () => photoError =
              'Photo recovery is unavailable. Please select your photos again.',
        );
      }
    });
  }

  Future<void> _recoverPhoto() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final response = await ImagePicker().retrieveLostData();
    if (mounted && !response.isEmpty) {
      setState(
        () => photoError =
            'A photo selection was interrupted. Please select it again.',
      );
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    height.dispose();
    weight.dispose();
    super.dispose();
  }

  Widget asset(String name, double size) =>
      SvgPicture.asset('assets/avatar/$name.svg', width: size, height: size);
  Future<void> pick(int slot) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!kIsWeb &&
                [
                  TargetPlatform.android,
                  TargetPlatform.iOS,
                ].contains(defaultTargetPlatform))
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() {
      picking = true;
      photoError = null;
    });
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2560,
        maxHeight: 2560,
        imageQuality: 90,
      );
      if (file == null) return;
      if (await file.length() > 8 * 1024 * 1024) {
        throw StateError('Photo too large');
      }
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() {
          photos[slot] = bytes;
          if (slot == 1) photoKept = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => photoError =
              'Could not open this photo. Allow camera/photos access and choose a JPEG, PNG or WebP up to 8 MB.',
        );
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> generate() async {
    if ((form.currentState != null && !form.currentState!.validate()) ||
        photos[1] == null ||
        !consent) {
      return;
    }
    await controller.generate(
      AvatarInput(
        photo: photos[1]!,
        height: double.parse(height.text.replaceAll(',', '.')),
        weight: double.parse(weight.text.replaceAll(',', '.')),
      ),
    );
  }

  Widget photoCard(int index, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 137,
              width: double.infinity,
              child: photos[index] == null
                  ? Center(
                      child: index == 0
                          ? const Icon(Icons.face_outlined, size: 56)
                          : asset('person', 64),
                    )
                  : Image.memory(photos[index]!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: OutlinedButton(
              onPressed: picking || controller.busy ? null : () => pick(index),
              child: Text(
                photos[index] == null ? '+ Upload Photo' : 'Replace Photo',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  Widget notice(String text) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFEEEBE4),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        asset('info', 17),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11, color: MirageColors.muted),
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MirageScreen(
      topPadding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                tooltip: 'Back',
                icon: asset('back', 22),
              ),
              const MirageWordmark(size: 17),
              IconButton(
                onPressed: () => Navigator.pop(context),
                tooltip: 'Close',
                icon: asset('close', 22),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (controller.restoringSaved) ...[
            const SizedBox(height: 60),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 24),
            const Center(child: Text('Opening your saved avatar…')),
          ] else if (controller.restoreFailed) ...[
            const SizedBox(height: 24),
            MirageNotice(
              controller.error ?? 'Could not open your saved avatar.',
              error: true,
            ),
            const SizedBox(height: 16),
            MirageButton(
              label: 'Try again',
              onPressed: controller.restore,
              arrow: false,
            ),
            const SizedBox(height: 28),
            const Text(
              'Or use a photo of your body',
              style: TextStyle(fontFamily: 'Lora', fontSize: 24, height: 1.1),
            ),
            const SizedBox(height: 8),
            const Text(
              'No avatar yet? You can still preview outfits on yourself with a clear full-body photo: standing, one person in frame.',
              style: TextStyle(fontSize: 13, color: MirageColors.muted),
            ),
            if (photos[1] != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                // contain, not cover: cover cut the head off a full-body photo.
                child: ColoredBox(
                  color: Colors.white,
                  child: SizedBox(
                    height: 320,
                    width: double.infinity,
                    child: Image.memory(photos[1]!, fit: BoxFit.contain),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: picking ? null : () => pick(1),
              child: Text(
                photos[1] == null ? 'Use a body photo instead' : 'Replace photo',
              ),
            ),
            if (photoError case final String message) ...[
              const SizedBox(height: 8),
              MirageNotice(message, error: true),
            ],
            if (photos[1] != null) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: previewConsent,
                onChanged: (v) => setState(() => previewConsent = v!),
                title: const Text(
                  'I agree to send this photo to an image-generation service to preview outfits. It is not stored on a server.',
                  style: TextStyle(fontSize: 11),
                ),
              ),
              MirageButton(
                label: 'Use this photo',
                arrow: false,
                onPressed: previewConsent
                    ? () {
                        PersonPhoto.bytes = photos[1];
                        setState(() => photoKept = true);
                      }
                    : null,
              ),
              if (photoKept) ...[
                const SizedBox(height: 12),
                notice('Photo saved. Next: pick up to 3 pieces in your closet and tap Try on.'),
                const SizedBox(height: 12),
                MirageButton(
                  key: const ValueKey('go-closet'),
                  label: 'Go to my closet',
                  onPressed: () => Navigator.of(context).pop('closet'),
                ),
              ],
            ],
          ] else if (controller.model != null) ...[
            const Text(
              'Your Digital Avatar',
              style: TextStyle(fontFamily: 'Lora', fontSize: 36, height: 1.08),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                height: 354,
                child: AvatarViewer(
                  key: ValueKey(controller.model),
                  uri: controller.model!,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Drag to rotate · Pinch to zoom',
                style: TextStyle(fontSize: 11, color: MirageColors.muted),
              ),
            ),
            const SizedBox(height: 14),
            notice(
              'Height-scaled body · Photo-based chest, waist and hip estimates. Review them before saving.',
            ),
            const SizedBox(height: 14),
            notice(
              'Save keeps your body photo privately for future styling previews, plus a compact body recipe. Visual approximation, not a fit guarantee.',
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: controller.busy
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MeasurementsScreen(
                          initial: controller.measurements,
                          fit: controller.fitPreference,
                          onContinue: controller.refine,
                        ),
                      ),
                    ),
              child: const Text('Refine Body Profile'),
            ),
            const SizedBox(height: 12),
            MirageButton(
              label: controller.saved ? 'Continue to Home' : 'Save & continue',
              busy: controller.busy,
              onPressed: () async {
                if (!controller.saved) await controller.save();
                if (context.mounted && controller.saved) {
                  Navigator.of(context).pop(true);
                }
              },
            ),
            if (controller.error != null)
              MirageNotice(controller.error!, error: true),
            TextButton(
              onPressed: controller.busy
                  ? null
                  : (photos[1] == null
                        ? () => setState(() => controller.model = null)
                        : generate),
              child: Text(
                photos[1] == null ? 'Use another photo' : 'Regenerate',
              ),
            ),
          ] else ...[
            const Text(
              'Create your digital avatar',
              style: TextStyle(fontFamily: 'Lora', fontSize: 36, height: 1.08),
            ),
            const SizedBox(height: 12),
            const Text(
              'Use clear lighting, fitted clothing and one person standing fully in frame.',
              style: TextStyle(fontSize: 14, color: MirageColors.muted),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: MirageColors.lime,
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text(
                'FULL BODY REQUIRED · SELFIE OPTIONAL',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                photoCard(0, 'Selfie / Face Photo', MirageColors.blue),
                const SizedBox(width: 12),
                photoCard(1, 'Full Body Photo', MirageColors.lavender),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEEEBE4),
                borderRadius: BorderRadius.circular(18),
              ),
              child: ListTile(
                leading: photos[2] == null
                    ? asset('person', 28)
                    : Image.memory(
                        photos[2]!,
                        width: 28,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                title: const Text(
                  'Side Photo · Optional',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Local reference only for now.',
                  style: TextStyle(fontSize: 10),
                ),
                trailing: const Icon(Icons.add, color: MirageColors.pink),
                onTap: picking || controller.busy ? null : () => pick(2),
              ),
            ),
            const SizedBox(height: 14),
            Form(
              key: form,
              child: Row(
                children: [
                  Expanded(
                    child: MirageField(
                      label: 'Height · cm',
                      controller: height,
                      enabled: !controller.busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) => validateNumber(v, 130, 220),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MirageField(
                      label: 'Weight · kg',
                      controller: weight,
                      enabled: !controller.busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) => validateNumber(v, 30, 250),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            notice(
              'Only your full-body photo is processed. Selfie and side photos stay on this screen. Your photo is stored privately only when you choose Save.',
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: consent,
              onChanged: controller.busy
                  ? null
                  : (v) => setState(() => consent = v!),
              title: const Text(
                'I agree to process my full-body photo locally. The result expires after 10 minutes.',
                style: TextStyle(fontSize: 11),
              ),
            ),
            if (photoError ?? controller.error case final String message)
              MirageNotice(message, error: true),
            if (controller.busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Creating your avatar… The first model load may take a minute.',
                ),
              ),
            const SizedBox(height: 14),
            MirageButton(
              label: 'Create avatar',
              busy: controller.busy,
              onPressed: photos[1] == null || !consent || picking
                  ? null
                  : generate,
            ),
          ],
        ],
      ),
    ),
  );
  String? validateNumber(String? value, double min, double max) {
    final number = double.tryParse((value ?? '').replaceAll(',', '.'));
    return number == null || !number.isFinite || number < min || number > max
        ? '$min–$max'
        : null;
  }
}

class AvatarViewer extends StatefulWidget {
  const AvatarViewer({super.key, required this.uri});
  final Uri uri;
  @override
  State<AvatarViewer> createState() => _AvatarViewerState();
}

class _AvatarViewerState extends State<AvatarViewer> {
  WebViewController? controller;
  @override
  void initState() {
    super.initState();
    if (!kIsWeb &&
        [
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) =>
                Uri.parse(request.url).origin == widget.uri.origin
                ? NavigationDecision.navigate
                : NavigationDecision.prevent,
          ),
        )
        ..loadRequest(widget.uri);
    }
  }

  @override
  Widget build(BuildContext context) => controller == null
      ? const Center(child: Text('3D preview is available on Android and iOS.'))
      : WebViewWidget(
          controller: controller!,
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
        );
}
