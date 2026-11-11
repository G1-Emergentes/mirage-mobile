import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../closet/domain/closet_repository.dart';
import '../domain/glasses.dart';
import 'ports.dart';

/// State of the glasses try-on screen: permission, catalog, the model on the face,
/// tracking and the captured photo.
class GlassesTryOnController extends ChangeNotifier {
  GlassesTryOnController({
    required this.engine,
    required this.catalog,
    this.initialGarmentId,
  });

  final FaceTryOnEngine engine;
  final GlassesCatalog catalog;

  /// Accessory opened from its detail screen: selected first when it is AR-ready.
  final String? initialGarmentId;

  CameraPermission? permission;
  List<GlassesOption> options = const [];
  GlassesOption? selected;
  GlassesFit? fit;
  bool loadingCatalog = false, loadingModel = false, faceVisible = false;
  bool capturing = false, saving = false, saved = false, debug = false;
  double fps = 0;
  String? error, notice;
  Uint8List? photo;

  FaceTryOnSession? _session;
  StreamSubscription<TrackingUpdate>? _updates;
  int _loadTicket = 0;
  bool _closed = false;

  bool get ready => permission == CameraPermission.granted;

  Future<void> start() async {
    if (!engine.isSupported) return;
    await Future.wait([checkPermission(request: true), _loadCatalog()]);
  }

  Future<void> checkPermission({bool request = false}) async {
    try {
      permission = await engine.cameraPermission(request: request);
    } catch (_) {
      permission = CameraPermission.denied;
    }
    _notify();
  }

  Future<void> openSettings() => engine.openSettings();

  Future<void> _loadCatalog() async {
    loadingCatalog = true;
    _notify();
    try {
      options = await catalog.options();
      final initial = initialGarmentId;
      final match = initial == null
          ? null
          : options.where((o) => o.garmentId == initial).firstOrNull;
      if (initial != null && match == null) {
        notice = options.isEmpty
            ? 'This accessory has no AR-ready 3D model yet.'
            : 'This accessory has no AR-ready 3D model yet. '
                  'Try one of the available glasses.';
      }
      selected = match ?? options.firstOrNull;
      fit = selected?.fit;
    } on ClosetException catch (e) {
      error = _describe(e.code);
    } catch (_) {
      error = 'Could not load the glasses.';
    } finally {
      loadingCatalog = false;
      _notify();
    }
    await _applySelected();
  }

  /// Called by the screen when the native camera view is ready.
  void attach(FaceTryOnSession session) {
    _updates?.cancel();
    _session = session;
    _updates = session.updates.listen((update) {
      if (update.error != null) {
        error = _describe(update.error!);
      } else {
        faceVisible = update.face;
        fps = update.fps;
      }
      _notify();
    });
    if (debug) unawaited(session.setDebug(true));
    unawaited(_applySelected());
  }

  Future<void> select(GlassesOption option) async {
    if (option.id == selected?.id && !loadingModel) return;
    selected = option;
    fit = option.fit;
    fitSaved = false;
    error = null;
    _notify();
    await _applySelected();
  }

  /// Downloads (or reuses) the selected model and puts it on the face. Only the most
  /// recent selection is applied when the user switches quickly.
  Future<void> _applySelected() async {
    final option = selected;
    final session = _session;
    if (option == null || session == null) return;
    final ticket = ++_loadTicket;
    loadingModel = true;
    _notify();
    try {
      final bytes = await catalog.model(option);
      if (ticket != _loadTicket || _closed) return;
      // A successful load does not clear errors: a camera or tracker error reported
      // meanwhile must stay visible. select() and dismissNotice() clear them.
      await session.loadModel(bytes, fit ?? option.fit);
    } on ClosetException catch (e) {
      if (ticket == _loadTicket) error = _describe(e.code);
    } on FaceTryOnException catch (e) {
      if (ticket == _loadTicket) error = _describe(e.code);
    } catch (_) {
      if (ticket == _loadTicket) error = 'Could not load these glasses.';
    } finally {
      if (ticket == _loadTicket) {
        loadingModel = false;
        _notify();
      }
    }
  }

  Future<void> capture() async {
    final session = _session;
    if (session == null || capturing) return;
    capturing = true;
    saved = false;
    _notify();
    try {
      photo = await session.capture();
    } catch (_) {
      error = 'Could not take the photo. Try again.';
    } finally {
      capturing = false;
      _notify();
    }
  }

  Future<void> savePhoto() async {
    final bytes = photo;
    if (bytes == null || saving) return;
    saving = true;
    _notify();
    try {
      await engine.saveToGallery(bytes);
      saved = true;
    } on FaceTryOnException catch (e) {
      error = _describe(e.code);
    } catch (_) {
      error = 'Could not save the photo.';
    } finally {
      saving = false;
      _notify();
    }
  }

  void discardPhoto() {
    photo = null;
    saved = false;
    _notify();
  }

  void dismissNotice() {
    notice = null;
    error = null;
    _notify();
  }

  // --- Developer calibration (debug builds) -------------------------------------------

  Future<void> toggleDebug() async {
    debug = !debug;
    _notify();
    await _session?.setDebug(debug);
  }

  Future<void> adjustFit(GlassesFit value) async {
    fit = value;
    fitSaved = false;
    _notify();
    await _session?.updateFit(value);
  }

  bool savingFit = false, fitSaved = false;

  /// Accessories of the closet keep their calibration on the 3D service.
  bool get canSaveFit => selected != null && !selected!.isSample;

  Future<void> saveFit() async {
    final option = selected;
    final value = fit;
    if (option == null || value == null || option.isSample || savingFit) return;
    savingFit = true;
    _notify();
    try {
      final saved = await catalog.saveFit(option, value);
      final updated = option.withFit(saved);
      options = [for (final o in options) o.id == option.id ? updated : o];
      if (selected?.id == option.id) {
        selected = updated;
        fit = saved;
      }
      fitSaved = true;
    } on ClosetException catch (e) {
      error = _describe(e.code);
    } catch (_) {
      error = 'Could not save the fit.';
    } finally {
      savingFit = false;
      _notify();
    }
  }

  static String _describe(String code) => switch (code) {
    'NETWORK' => 'Could not reach the 3D service. Check its connection.',
    'UNAUTHENTICATED' => 'Your session ended. Sign in again.',
    'MODEL_NOT_FOUND' || 'MODEL_NOT_READY' => 'This 3D model is not ready yet.',
    'INVALID_MODEL' => 'The 3D model of these glasses is not valid.',
    'INVALID_AR_FIT' => 'That fit is out of range. Adjust it and try again.',
    'UNSUPPORTED_ACCESSORY' => 'These glasses cannot be tried on in AR yet.',
    'CAMERA_UNAVAILABLE' => 'The camera is busy or unavailable.',
    'NO_FRONT_CAMERA' => 'This device has no front camera.',
    'FACE_TRACKER_UNAVAILABLE' =>
      'Face tracking is not available on this device.',
    'STORAGE_DENIED' => 'Allow storage access to save the photo.',
    'SAVE_FAILED' => 'Could not save the photo.',
    _ => 'Something went wrong. Try again.',
  };

  void _notify() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _updates?.cancel();
    super.dispose();
  }
}
