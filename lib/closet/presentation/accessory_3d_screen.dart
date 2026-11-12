import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../shared/theme/mirage_theme.dart';
import '../../shared/widgets/mirage_components.dart';
import '../application/accessory_models_controller.dart';
import '../domain/closet_repository.dart';
import '../domain/garment.dart';
import '../infrastructure/accessory_model_api.dart';
import 'closet_widgets.dart';

/// 3D viewer of an accessory (full model, with temples).
///
/// When the accessory has a photo but no model yet, the model is created on opening
/// ([autoGenerate]); it takes 2–3 minutes on the GPU. While the service reports
/// PROCESSING (another request is generating it) the status is polled every
/// [pollEvery]. After a generation, [models] is refreshed so badges, thumbnails and
/// the detail header update.
class Accessory3dScreen extends StatefulWidget {
  const Accessory3dScreen({
    super.key,
    required this.garment,
    required this.api,
    this.models,
    this.autoGenerate = true,
    this.pollEvery = const Duration(seconds: 5),
  });

  final Garment garment;
  final AccessoryModelApi api;
  final AccessoryModelsController? models;
  final bool autoGenerate;
  final Duration pollEvery;

  @override
  State<Accessory3dScreen> createState() => _Accessory3dScreenState();
}

class _Accessory3dScreenState extends State<Accessory3dScreen> {
  static const _localUpload =
      kDebugMode && bool.fromEnvironment('ACCESSORY_3D_LOCAL_UPLOAD');

  String? _modelUri;
  String? _status;
  String? _error;
  String? _working;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool generate = false}) async {
    if (_working != null) return;
    _poll?.cancel();
    var generateNext = false;
    setState(() {
      _working = generate
          ? 'Creating your 3D model… This takes 2–3 minutes.'
          : 'Checking for a 3D model…';
      _error = null;
    });
    try {
      if (generate) {
        PickedPhoto? photo;
        if (_localUpload) {
          photo = await pickPhoto(ImageSource.gallery);
          if (!mounted || photo == null) return;
        }
        await widget.api.generate(
          widget.garment,
          photo: photo?.bytes,
          contentType: photo?.contentType,
        );
        unawaited(widget.models?.refresh(widget.garment.id));
      }
      if (!mounted) return;
      final status = await widget.api.status(widget.garment.id);
      if (!mounted) return;
      // No model yet: create it right away instead of waiting for a tap.
      generateNext =
          !generate &&
          status == null &&
          widget.autoGenerate &&
          !_localUpload &&
          widget.garment.hasImage;
      final modelUri = status == 'READY'
          ? Uri.dataFromBytes(
              await widget.api.download(widget.garment.id),
              mimeType: 'model/gltf-binary',
            ).toString()
          : null;
      if (mounted) {
        setState(() {
          _status = status;
          _modelUri = modelUri;
        });
      }
    } on ClosetException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'GENERATION_IN_PROGRESS') _status = 'PROCESSING';
        _error = switch (e.code) {
          'NETWORK' =>
            'Could not reach the 3D service. Check its connection and refresh.',
          'UNAUTHENTICATED' => 'Your session ended. Sign in again.',
          'GARMENT_WITHOUT_PHOTO' => 'Add a photo to this accessory first.',
          'INVALID_PHOTO' => 'Choose a JPEG, PNG or WebP image up to 8 MB.',
          'INVALID_MODEL' => 'The service returned an invalid 3D file.',
          'INSUFFICIENT_GPU_MEMORY' => 'The 3D service ran out of GPU memory.',
          'MODEL_STORAGE_UNAVAILABLE' =>
            'Could not reach model storage. Try again.',
          'GENERATION_IN_PROGRESS' => null,
          _ => 'Could not open the 3D model. Try again.',
        };
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the 3D model. Try again.');
      }
    } finally {
      if (mounted) setState(() => _working = null);
    }
    if (!mounted) return;
    if (generateNext) {
      await _load(generate: true);
    } else if (_status == 'PROCESSING' && _modelUri == null) {
      _poll = Timer(widget.pollEvery, () {
        if (mounted) _load();
      });
    } else if (_status == 'READY' && !generate) {
      // Opened on a model generated elsewhere: make sure the cache knows it.
      unawaited(widget.models?.ensure([widget.garment.id]));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MirageColors.blue,
    appBar: AppBar(
      title: const Text('Mirage'),
      backgroundColor: MirageColors.blue,
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.garment.name,
              style: const TextStyle(fontFamily: 'Lora', fontSize: 25),
            ),
            Expanded(
              child: _modelUri != null
                  ? ModelViewer(
                      key: ValueKey(_modelUri),
                      src: _modelUri!,
                      alt: '3D model of ${widget.garment.name}',
                      backgroundColor: MirageColors.blue,
                      cameraControls: true,
                      ar: false,
                    )
                  : Center(
                      child: _working != null
                          ? const CircularProgressIndicator()
                          : const Icon(Icons.view_in_ar_outlined, size: 64),
                    ),
            ),
            if (_modelUri != null)
              const Text(
                'Drag to rotate · Pinch to zoom',
                textAlign: TextAlign.center,
              ),
            if (_working case final message?)
              Text(message, textAlign: TextAlign.center),
            if (_error case final message?) MirageNotice(message, error: true),
            if (_working == null && _modelUri == null) ...[
              if (_status == 'PROCESSING')
                const Text('The 3D service is still creating your model.'),
              if (_status == 'STALE')
                const Text(
                  'The accessory photo changed. Create an updated model.',
                ),
              if (_status == 'FAILED')
                const Text('The last generation failed. Try again.'),
              if (!_localUpload && !widget.garment.hasImage)
                const Text('Add a photo to this accessory first.'),
              const SizedBox(height: 12),
              if (_localUpload || widget.garment.hasImage)
                MirageButton(
                  label: _localUpload
                      ? 'Choose photo and create'
                      : _status == 'PROCESSING'
                      ? 'Retry generation'
                      : 'Create 3D model',
                  arrow: false,
                  onPressed: () => _load(generate: true),
                ),
              if (_error != null || _status == 'PROCESSING')
                TextButton(onPressed: _load, child: const Text('Refresh')),
            ],
          ],
        ),
      ),
    ),
  );
}
