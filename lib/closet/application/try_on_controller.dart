import 'package:flutter/foundation.dart';
import '../domain/closet_repository.dart';
import '../domain/garment.dart';

enum TryOnPhase { idle, running, ready, failed }

class TryOnController extends ChangeNotifier {
  TryOnController(
    this.repository, {
    this.pollEvery = const Duration(seconds: 2),
    this.timeout = const Duration(minutes: 5),
  });
  final TryOnRepository repository;
  final Duration pollEvery, timeout;
  TryOnPhase phase = TryOnPhase.idle;
  TryOnState state = TryOnState.pending;
  Uint8List? result;
  String? error;
  bool _closed = false;

  /// 0..1 for the progress bar: the worker reports states, not percentages.
  double get progress => switch (phase) {
    TryOnPhase.ready => 1,
    TryOnPhase.running => state == TryOnState.processing ? 0.65 : 0.25,
    _ => 0,
  };

  Future<void> start(List<Garment> garments, Uint8List? personPhoto) async {
    if (phase == TryOnPhase.running) return;
    phase = TryOnPhase.running;
    state = TryOnState.pending;
    error = null;
    result = null;
    notifyListeners();
    try {
      var job = await repository.start([
        for (final garment in garments) garment.id,
      ], personPhoto);
      final deadline = DateTime.now().add(timeout);
      while (!_closed && DateTime.now().isBefore(deadline)) {
        state = job.state;
        notifyListeners();
        if (job.state == TryOnState.ready) {
          result = await repository.image(job.id);
          phase = TryOnPhase.ready;
          return;
        }
        if (job.state == TryOnState.failed) {
          throw ClosetException(job.error ?? 'PROVIDER_FAILED');
        }
        await Future<void>.delayed(pollEvery);
        job = await repository.status(job.id);
      }
      if (!_closed) throw const ClosetException('TIMEOUT');
    } on ClosetException catch (e) {
      phase = TryOnPhase.failed;
      error = describe(e);
    } catch (_) {
      phase = TryOnPhase.failed;
      error = 'Could not create your look. Try again.';
    } finally {
      if (!_closed) notifyListeners();
    }
  }

  static String describe(ClosetException e) => switch (e.code) {
    'PERSON_PHOTO_NOT_FOUND' =>
      'We need a full-body photo of you. Add one first, then try again.',
    'GARMENT_WITHOUT_IMAGE' => 'One of the pieces has no photo.',
    'GARMENT_UNAVAILABLE' => 'One of the pieces is not available right now.',
    'GARMENT_NOT_FOUND' => 'One of the pieces no longer exists.',
    'UNAUTHENTICATED' => 'Your session ended. Sign in again.',
    'NETWORK' =>
      'Could not reach the preview server. Check that it is running.',
    'TIMEOUT' => 'This took too long. Try again.',
    'PROVIDER_FAILED' => 'The image service could not create your look.',
    'CONTENT_FLAGGED' =>
      'The image service flagged this photo or piece, often because of a printed face or logo. Try another piece or photo.',
    'PROVIDER_NOT_CONFIGURED' =>
      'The image service is not set up on the server.',
    'INVALID_ARGUMENT' => 'That photo or selection is not valid.',
    _ => 'Could not create your look. Try again.',
  };

  void reset() {
    phase = TryOnPhase.idle;
    result = null;
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    repository.close();
    super.dispose();
  }
}
