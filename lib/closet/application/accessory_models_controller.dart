import 'dart:async';

import 'package:flutter/foundation.dart';

import '../infrastructure/accessory_model_api.dart';

/// 3D state of the closet's accessories, shared by the list, the detail and the 3D screens.
///
/// - [ensure] asks the 3D service for many accessories in ONE call
///   (`GET /garments/models?ids=…`) and caches each row: badge, status, thumbnail path.
/// - [thumbnail] and [model] download (once) the background-free PNG and the full GLB.
/// - [refresh] forgets one accessory after it was generated again, so badges and images
///   update on every screen that listens.
///
/// The 3D data is a bonus on top of the closet: failures are swallowed and the screens
/// keep the original photo. A failed id is not asked again for [retryAfter].
class AccessoryModelsController extends ChangeNotifier {
  AccessoryModelsController(
    this._api, {
    this.retryAfter = const Duration(seconds: 30),
  });

  final AccessoryModelApi _api;
  final Duration retryAfter;

  final _summaries = <String, AccessoryModelSummary>{};
  final _pending = <String>{};
  final _failedAt = <String, DateTime>{};
  final _thumbnails = <String, Future<Uint8List?>>{};
  final _models = <String, Future<Uint8List>>{};
  bool _closed = false;

  /// Cached row of an accessory, or null while unknown.
  AccessoryModelSummary? summary(String garmentId) => _summaries[garmentId];

  /// Loads the rows not cached yet, in a single request. Never notifies synchronously,
  /// so it is safe to call from `build`.
  Future<void> ensure(Iterable<String> garmentIds) async {
    final now = DateTime.now();
    final missing = [
      for (final id in garmentIds.toSet())
        if (!_summaries.containsKey(id) &&
            !_pending.contains(id) &&
            !(_failedAt[id]?.add(retryAfter).isAfter(now) ?? false))
          id,
    ];
    if (missing.isEmpty) return;
    _pending.addAll(missing);
    try {
      // After the current build: getting the token can notify IAM listeners.
      await Future<void>.microtask(() {});
      final rows = await _api.listModels(missing);
      for (final row in rows) {
        _summaries[row.garmentId] = row;
        _failedAt.remove(row.garmentId);
      }
    } catch (_) {
      for (final id in missing) {
        _failedAt[id] = DateTime.now();
      }
    } finally {
      _pending.removeAll(missing);
      _notify();
    }
  }

  /// Forgets an accessory (it was generated again) and reloads its row.
  Future<void> refresh(String garmentId) {
    _summaries.remove(garmentId);
    _failedAt.remove(garmentId);
    _thumbnails.remove(garmentId);
    _models.remove(garmentId);
    return ensure([garmentId]);
  }

  /// Background-free PNG of a ready model, or null (no thumbnail or it failed).
  Future<Uint8List?>? thumbnail(String garmentId) {
    final url = _summaries[garmentId]?.thumbnailUrl;
    if (url == null) return null;
    return _thumbnails[garmentId] ??= _api.thumbnail(url).then((png) {
      if (png == null) _thumbnails.remove(garmentId); // failed: retry next time
      return png;
    });
  }

  /// Full GLB of a ready model for the 3D viewer, downloaded once.
  Future<Uint8List> model(String garmentId) => _models[garmentId] ??= _api
      .download(garmentId)
      .catchError((Object error) {
        _models.remove(
          garmentId,
        ); // a failure is not cached: next time it retries
        throw error;
      });

  void _notify() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
