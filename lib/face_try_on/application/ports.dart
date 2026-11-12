import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../domain/glasses.dart';

enum CameraPermission { granted, denied, permanentlyDenied }

/// What the on-device tracker reports: a face is visible, frames per second, or an
/// error code from the native side (camera or tracker unavailable).
class TrackingUpdate {
  const TrackingUpdate({this.face = false, this.fps = 0, this.error});
  final bool face;
  final double fps;
  final String? error;
}

/// One live camera + tracking + rendering surface.
abstract interface class FaceTryOnSession {
  Stream<TrackingUpdate> get updates;
  Future<void> loadModel(Uint8List glb, GlassesFit fit);
  Future<void> updateFit(GlassesFit fit);
  Future<void> setDebug(bool enabled);

  /// JPEG of what the user sees: mirrored camera frame with the glasses.
  Future<Uint8List> capture();
}

/// Camera, face tracking and 3D rendering on the device (Android: CameraX, MediaPipe
/// Face Landmarker and Filament behind a platform view).
abstract interface class FaceTryOnEngine {
  bool get isSupported;
  Future<CameraPermission> cameraPermission({bool request = false});
  Future<void> openSettings();
  Future<void> saveToGallery(Uint8List jpeg);

  /// The camera view. [onCreated] runs once the native surface is ready.
  Widget buildView({required ValueChanged<FaceTryOnSession> onCreated});
}

/// Glasses the user can try on and their 3D models.
abstract interface class GlassesCatalog {
  Future<List<GlassesOption>> options();
  Future<Uint8List> model(GlassesOption option);

  /// Stores a calibrated fit for an accessory of the closet (not for test models) and
  /// returns the fit the service will serve from now on.
  Future<GlassesFit> saveFit(GlassesOption option, GlassesFit fit);
}

/// Error with a stable code, so the screen chooses the message.
class FaceTryOnException implements Exception {
  const FaceTryOnException(this.code);
  final String code;
  @override
  String toString() => 'FaceTryOnException($code)';
}
