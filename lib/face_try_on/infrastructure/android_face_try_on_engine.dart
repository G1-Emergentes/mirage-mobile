import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../application/ports.dart';
import '../domain/glasses.dart';

/// Bridge to the native try-on in `android/app/src/main/kotlin/.../facetryon/`.
class AndroidFaceTryOnEngine implements FaceTryOnEngine {
  AndroidFaceTryOnEngine({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('mirage/face_try_on');

  static const viewType = 'mirage/face_try_on_view';
  final MethodChannel _channel;

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<CameraPermission> cameraPermission({bool request = false}) async {
    final status = await _channel.invokeMethod<String>('cameraPermission', {
      'request': request,
    });
    return switch (status) {
      'granted' => CameraPermission.granted,
      'permanentlyDenied' => CameraPermission.permanentlyDenied,
      _ => CameraPermission.denied,
    };
  }

  @override
  Future<void> openSettings() => _channel.invokeMethod<void>('openSettings');

  @override
  Future<void> saveToGallery(Uint8List jpeg) async {
    try {
      await _channel.invokeMethod<String>('saveToGallery', {'bytes': jpeg});
    } on PlatformException catch (e) {
      throw FaceTryOnException(e.code);
    }
  }

  @override
  Widget buildView({
    required ValueChanged<FaceTryOnSession> onCreated,
  }) => PlatformViewLink(
    viewType: viewType,
    surfaceFactory: (context, controller) => AndroidViewSurface(
      controller: controller as AndroidViewController,
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
      hitTestBehavior: PlatformViewHitTestBehavior.transparent,
    ),
    onCreatePlatformView: (params) {
      // Hybrid composition: the camera and Filament TextureViews stay real Android
      // views, which keeps the preview smooth and makes the capture reliable.
      final controller = PlatformViewsService.initExpensiveAndroidView(
        id: params.id,
        viewType: viewType,
        layoutDirection: TextDirection.ltr,
        creationParamsCodec: const StandardMessageCodec(),
        onFocus: () => params.onFocusChanged(true),
      );
      controller
        ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
        ..addOnPlatformViewCreatedListener(
          (id) => onCreated(_AndroidSession(id)),
        )
        ..create();
      return controller;
    },
  );
}

class _AndroidSession implements FaceTryOnSession {
  _AndroidSession(int id)
    : _methods = MethodChannel('mirage/face_try_on/view_$id'),
      _events = EventChannel('mirage/face_try_on/events_$id');

  final MethodChannel _methods;
  final EventChannel _events;

  @override
  late final Stream<TrackingUpdate> updates = _events
      .receiveBroadcastStream()
      .where((event) => event is Map)
      .map((event) {
        final map = event as Map;
        return map['type'] == 'error'
            ? TrackingUpdate(error: '${map['code']}')
            : TrackingUpdate(
                face: map['face'] == true,
                fps: (map['fps'] as num?)?.toDouble() ?? 0,
              );
      });

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _methods.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw FaceTryOnException(e.code);
    }
  }

  @override
  Future<void> loadModel(Uint8List glb, GlassesFit fit) =>
      _call<void>('loadModel', {'bytes': glb, 'fit': fit.toJson()});

  @override
  Future<void> updateFit(GlassesFit fit) =>
      _call<void>('updateFit', {'fit': fit.toJson()});

  @override
  Future<void> setDebug(bool enabled) =>
      _call<void>('setDebug', {'enabled': enabled});

  @override
  Future<Uint8List> capture() async {
    final bytes = await _call<Uint8List>('capture');
    if (bytes == null || bytes.isEmpty) {
      throw const FaceTryOnException('CAPTURE_FAILED');
    }
    return bytes;
  }
}
