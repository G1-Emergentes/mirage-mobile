import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../closet/closet_module.dart';
import '../../shared/theme/mirage_theme.dart';
import '../application/glasses_try_on_controller.dart';
import '../application/ports.dart';
import '../domain/glasses.dart';
import '../infrastructure/android_face_try_on_engine.dart';
import '../infrastructure/closet_glasses_catalog.dart';

/// Virtual try-on of glasses: front camera, the glasses follow the head in real time,
/// switch models and take a photo. Everything runs on the device.
class GlassesTryOnScreen extends StatefulWidget {
  const GlassesTryOnScreen({
    super.key,
    required this.engine,
    required this.catalog,
    this.initialGarmentId,
  });

  /// Production wiring: the closet's accessories and the Android engine.
  factory GlassesTryOnScreen.forCloset(
    ClosetModule module, {
    String? initialGarmentId,
    FaceTryOnEngine? engine,
  }) => GlassesTryOnScreen(
    engine: engine ?? AndroidFaceTryOnEngine(),
    catalog: ClosetGlassesCatalog(
      closet: module.closet,
      models: module.accessoryModels,
    ),
    initialGarmentId: initialGarmentId,
  );

  final FaceTryOnEngine engine;
  final GlassesCatalog catalog;
  final String? initialGarmentId;

  @override
  State<GlassesTryOnScreen> createState() => _GlassesTryOnScreenState();
}

class _GlassesTryOnScreenState extends State<GlassesTryOnScreen>
    with WidgetsBindingObserver {
  late final controller = GlassesTryOnController(
    engine: widget.engine,
    catalog: widget.catalog,
    initialGarmentId: widget.initialGarmentId,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the system settings: the user may have granted the camera.
    if (state == AppLifecycleState.resumed && !controller.ready) {
      controller.checkPermission();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        if (!widget.engine.isSupported) {
          return _Message(
            icon: Icons.phone_android,
            text: 'The virtual try-on is available on Android.',
          );
        }
        if (c.permission == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!c.ready) return _PermissionMessage(controller: c);
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.engine.buildView(onCreated: c.attach),
            _Overlay(controller: c),
            if (c.photo case final photo?)
              _PhotoPreview(controller: c, photo: photo),
          ],
        );
      },
    ),
  );
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.controller});
  final GlassesTryOnController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final status = c.loadingCatalog || c.loadingModel
        ? 'Loading glasses…'
        : c.selected == null
        ? null
        : !c.faceVisible
        ? 'Look at the camera'
        : null;
    final message = c.error ?? c.notice;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              children: [
                _RoundButton(
                  icon: Icons.close,
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const Expanded(
                  child: Text(
                    'Try on glasses',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Lora',
                      fontSize: 22,
                    ),
                  ),
                ),
                if (kDebugMode)
                  _RoundButton(
                    icon: Icons.tune,
                    tooltip: 'Calibrate',
                    selected: c.debug,
                    onPressed: c.toggleDebug,
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),
          if (status != null) ...[const SizedBox(height: 10), _Pill(status)],
          if (kDebugMode && c.debug) _CalibrationPanel(controller: c),
          const Spacer(),
          if (message != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _Banner(
                message,
                error: c.error != null,
                onClose: c.dismissNotice,
              ),
            ),
          if (c.options.isEmpty && !c.loadingCatalog && c.error == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: _Pill(
                'No AR-ready glasses yet. Create a 3D model from an accessory.',
              ),
            ),
          _Carousel(controller: c),
          const SizedBox(height: 14),
          _ShutterButton(
            busy: c.capturing,
            onPressed: c.selected == null || c.loadingModel ? null : c.capture,
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _Carousel extends StatelessWidget {
  const _Carousel({required this.controller});
  final GlassesTryOnController controller;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 92,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: controller.options.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, i) {
        final option = controller.options[i];
        final selected = option.id == controller.selected?.id;
        return Semantics(
          button: true,
          selected: selected,
          label: option.name,
          child: GestureDetector(
            key: ValueKey('glasses-${option.id}'),
            onTap: () => controller.select(option),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 86,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? MirageColors.pink : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    option.isSample
                        ? Icons.visibility_outlined
                        : Icons.remove_red_eye,
                    color: selected ? MirageColors.ink : Colors.white,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? MirageColors.ink : Colors.white,
                    ),
                  ),
                  if (option.isSample)
                    Text(
                      'DEMO',
                      style: TextStyle(
                        fontSize: 8,
                        letterSpacing: 1,
                        color: selected ? MirageColors.muted : Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.busy, required this.onPressed});
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Take photo',
    child: GestureDetector(
      key: const ValueKey('try-on-shutter'),
      onTap: busy ? null : onPressed,
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        padding: const EdgeInsets.all(5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onPressed == null ? Colors.white38 : Colors.white,
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              : null,
        ),
      ),
    ),
  );
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.controller, required this.photo});
  final GlassesTryOnController controller;
  final Uint8List photo;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.memory(photo, fit: BoxFit.contain),
              ),
            ),
          ),
          if (controller.error case final error?)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Banner(
                error,
                error: true,
                onClose: controller.dismissNotice,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: controller.discardPhoto,
                    child: const Text('Retake'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: MirageColors.pink,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: controller.saving || controller.saved
                        ? null
                        : controller.savePhoto,
                    icon: Icon(
                      controller.saved ? Icons.check : Icons.download_outlined,
                    ),
                    label: Text(
                      controller.saved
                          ? 'Saved to Pictures/Mirage'
                          : controller.saving
                          ? 'Saving…'
                          : 'Save photo',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Debug-only sliders to calibrate how a model sits on the face; the values are the
/// `ar_fit` the 3D service will send for each model.
class _CalibrationPanel extends StatelessWidget {
  const _CalibrationPanel({required this.controller});
  final GlassesTryOnController controller;

  @override
  Widget build(BuildContext context) {
    final fit = controller.fit ?? const GlassesFit();
    Widget slider(
      String label,
      double value,
      double min,
      double max,
      GlassesFit Function(double) update,
      String Function(double) format,
    ) => Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(label, style: const TextStyle(color: Colors.white)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: (v) => controller.adjustFit(update(v)),
          ),
        ),
        SizedBox(
          width: 64,
          child: Text(
            format(value),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
    String mm(double v) => '${(v * 1000).toStringAsFixed(1)} mm';
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Calibration · ${controller.fps.toStringAsFixed(0)} fps',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          slider(
            'Up',
            fit.offsetY,
            -0.015,
            0.015,
            (v) => fit.copyWith(offsetY: v),
            mm,
          ),
          slider(
            'Forward',
            fit.offsetZ,
            -0.01,
            0.025,
            (v) => fit.copyWith(offsetZ: v),
            mm,
          ),
          slider(
            'Scale',
            fit.scale,
            0.8,
            1.2,
            (v) => fit.copyWith(scale: v),
            (v) => v.toStringAsFixed(2),
          ),
          slider(
            'Tilt',
            fit.pitchDeg,
            -15,
            15,
            (v) => fit.copyWith(pitchDeg: v),
            (v) => '${v.toStringAsFixed(1)}°',
          ),
          if (controller.canSaveFit)
            TextButton.icon(
              key: const ValueKey('save-ar-fit'),
              style: TextButton.styleFrom(foregroundColor: MirageColors.lime),
              onPressed: controller.savingFit || controller.fitSaved
                  ? null
                  : controller.saveFit,
              icon: Icon(
                controller.fitSaved ? Icons.check : Icons.save_outlined,
              ),
              label: Text(
                controller.fitSaved
                    ? 'Fit saved for this model'
                    : controller.savingFit
                    ? 'Saving…'
                    : 'Save fit for this model',
              ),
            )
          else
            const Text(
              'Demo models are not saved: calibrate one of your accessories.',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _PermissionMessage extends StatelessWidget {
  const _PermissionMessage({required this.controller});
  final GlassesTryOnController controller;

  @override
  Widget build(BuildContext context) {
    final blocked = controller.permission == CameraPermission.permanentlyDenied;
    return _Message(
      icon: Icons.no_photography_outlined,
      text: blocked
          ? 'Camera access is turned off for Mirage. Enable it in Settings to try on glasses.'
          : 'Mirage needs the front camera to place the glasses on your face. '
                'Images stay on your phone.',
      action: blocked ? 'Open Settings' : 'Allow camera',
      onAction: blocked
          ? controller.openSettings
          : () => controller.checkPermission(request: true),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Stack(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _RoundButton(
              icon: Icons.close,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 56),
                const SizedBox(height: 16),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                if (action != null) ...[
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: MirageColors.pink,
                    ),
                    onPressed: onAction,
                    child: Text(action!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: selected ? MirageColors.lime : Colors.black38,
      foregroundColor: selected ? MirageColors.ink : Colors.white,
    ),
    icon: Icon(icon),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white),
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner(this.text, {required this.error, required this.onClose});
  final String text;
  final bool error;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
    color: error ? const Color(0xFFFCE4EC) : Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.only(left: 14),
      child: Row(
        children: [
          Expanded(child: Text(text)),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    ),
  );
}
