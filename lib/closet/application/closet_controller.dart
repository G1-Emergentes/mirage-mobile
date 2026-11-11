import 'package:flutter/foundation.dart';
import '../domain/closet_repository.dart';
import '../domain/garment.dart';

class ClosetController extends ChangeNotifier {
  ClosetController(this.repository, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;
  final ClosetRepository repository;
  final DateTime Function() _now;
  List<Garment> garments = const [];
  bool loading = false, loaded = false, _closed = false;
  String? error;

  // Signed photo links last five minutes; reuse one for four so a screen that rebuilds
  // does not ask again, and ask for a fresh one afterwards.
  static const _linkLife = Duration(minutes: 4);
  final _links = <String, ({Future<String?> url, DateTime at})>{};

  List<Garment> inGroup(ClosetGroup group) =>
      garments.where((garment) => garment.group == group).toList();
  int count(ClosetGroup group) => inGroup(group).length;

  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      garments = await repository.list();
      loaded = true;
      _links.clear();
    } on ClosetException catch (e) {
      error = describe(e);
    } catch (_) {
      error = 'Could not load your closet.';
    } finally {
      loading = false;
      if (!_closed) notifyListeners();
    }
  }

  Future<String?> imageUrl(Garment garment) {
    if (!garment.hasImage) return Future.value(null);
    final cached = _links[garment.id];
    if (cached != null && _now().difference(cached.at) < _linkLife) {
      return cached.url;
    }
    final url = repository.imageUrl(garment.id).catchError((_) => null);
    _links[garment.id] = (url: url, at: _now());
    return url;
  }

  /// Creates the garment and uploads its photo. If the photo fails the garment is removed
  /// again, so a failed save never leaves a piece without a picture.
  Future<Garment> add(
    GarmentDraft draft,
    Uint8List photo,
    String contentType,
  ) async {
    final created = await repository.create(draft);
    try {
      final withImage = await repository.attachImage(
        created.id,
        photo,
        contentType,
      );
      garments = [...garments, withImage];
      notifyListeners();
      return withImage;
    } catch (_) {
      await repository.remove(created.id).catchError((_) {});
      rethrow;
    }
  }

  Future<Garment> save(String id, GarmentDraft draft) async {
    final updated = await repository.update(id, draft);
    garments = [for (final g in garments) g.id == id ? updated : g];
    _links.remove(id);
    notifyListeners();
    return updated;
  }

  Future<void> remove(String id) async {
    await repository.remove(id);
    garments = garments.where((garment) => garment.id != id).toList();
    _links.remove(id);
    notifyListeners();
  }

  static String describe(ClosetException e) => switch (e.code) {
    'NETWORK' => 'Could not reach the closet server. Check that it is running.',
    'UNAUTHENTICATED' => 'Your session ended. Sign in again.',
    'GARMENT_NOT_FOUND' => 'This piece no longer exists.',
    'INVALID_ARGUMENT' => 'Some of the details are not valid.',
    'SERVICE_UNAVAILABLE' => 'The closet is temporarily unavailable.',
    _ => 'Something went wrong. Try again.',
  };

  @override
  void dispose() {
    _closed = true;
    repository.close();
    super.dispose();
  }
}
