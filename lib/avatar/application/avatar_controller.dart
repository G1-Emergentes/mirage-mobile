import 'package:flutter/foundation.dart';
import '../domain/avatar_repository.dart';

class AvatarController extends ChangeNotifier {
  AvatarController(this.repository);
  final AvatarRepository repository;
  bool busy = false, _closed = false;
  String? error, _id;
  Uri? model;
  Map<String, double?> measurements = {};
  String fitPreference = 'Regular';
  bool saved = false;
  bool restoringSaved = false, restoreFailed = false;
  Future<void> waitForModel() async {
    final deadline = DateTime.now().add(const Duration(minutes: 4));
    while (!_closed && DateTime.now().isBefore(deadline)) {
      final state = await repository.status(_id!);
      if (state == 'succeeded') {
        final result = await repository.body(_id!);
        fitPreference = (result['fitPreference'] as String?) ?? 'Regular';
        measurements = {
          for (final e in ((result['measurements'] ?? {}) as Map).entries)
            e.key as String: (e.value as num?)?.toDouble(),
        };
        model = repository.viewer(_id!);
        return;
      }
      if (state == 'failed') throw StateError('Reconstruction failed');
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    if (!_closed) throw StateError('Reconstruction timed out');
  }

  Future<void> restore() async {
    restoringSaved = true;
    restoreFailed = false;
    error = null;
    busy = true;
    notifyListeners();
    try {
      if (_id != null) await repository.discard(_id!);
      _id = null;
      _id = await repository.openSaved();
      if (_id != null) {
        await waitForModel();
        saved = true;
      }
    } catch (_) {
      restoreFailed = true;
      error =
          'Could not load your saved avatar. Check your session and the local server.';
    } finally {
      restoringSaved = false;
      busy = false;
      if (!_closed) notifyListeners();
    }
  }

  Future<bool> refine(Map<String, double?> values, String fit) async {
    if (busy || _id == null) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final previous = _id!;
      _id = await repository.adjust(previous, values, fit);
      await repository.discard(previous);
      await waitForModel();
      fitPreference = fit;
      saved = false;
      return true;
    } catch (_) {
      error =
          'Could not adjust the avatar. Try again before the preview expires.';
      return false;
    } finally {
      busy = false;
      if (!_closed) notifyListeners();
    }
  }

  Future<void> save() async {
    if (busy || _id == null) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await repository.save(_id!, measurements, fitPreference);
      saved = true;
    } catch (_) {
      error =
          'Could not save. Check your session and connection, then try again.';
    } finally {
      busy = false;
      if (!_closed) notifyListeners();
    }
  }

  Future<void> generate(AvatarInput input) async {
    if (busy) return;
    busy = true;
    error = null;
    model = null;
    notifyListeners();
    try {
      if (_id != null) await repository.discard(_id!);
      _id = await repository.submit(input);
      final deadline = DateTime.now().add(const Duration(minutes: 4));
      while (!_closed && DateTime.now().isBefore(deadline)) {
        final state = await repository.status(_id!);
        if (state == 'succeeded') {
          final result = await repository.body(_id!);
          measurements = {
            for (final e in ((result['measurements'] ?? {}) as Map).entries)
              e.key as String: (e.value as num?)?.toDouble(),
          };
          saved = false;
          model = repository.viewer(_id!);
          return;
        }
        if (state == 'failed') throw StateError('Reconstruction failed');
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      if (!_closed) {
        error = 'This took too long. Try again with a clear full-body photo.';
      }
    } catch (_) {
      error =
          'Could not create your avatar. Check the local SAM server and try a clear full-body photo.';
    } finally {
      busy = false;
      if (!_closed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _closed = true;
    if (_id != null) {
      repository
          .discard(_id!)
          .catchError((_) {})
          .whenComplete(repository.close);
    } else {
      repository.close();
    }
    super.dispose();
  }
}
