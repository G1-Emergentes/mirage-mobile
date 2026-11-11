import 'dart:typed_data';
import 'garment.dart';

/// `code` is the Digital Closet error code (e.g. GARMENT_NOT_FOUND) or NETWORK when the
/// server could not be reached.
class ClosetException implements Exception {
  const ClosetException(this.code, [this.message = '']);
  final String code, message;
  @override
  String toString() => 'ClosetException($code)';
}

abstract class ClosetRepository {
  Future<List<Garment>> list();
  Future<Garment> create(GarmentDraft draft);
  Future<Garment> update(String id, GarmentDraft draft);
  Future<void> remove(String id);

  /// Uploads the photo through a signed URL and registers it on the garment.
  Future<Garment> attachImage(String id, Uint8List bytes, String contentType);

  /// Temporary signed URL of the garment photo, or null when it has none.
  Future<String?> imageUrl(String id);
  void close();
}

enum TryOnState { pending, processing, ready, failed }

class TryOnJob {
  const TryOnJob(this.id, this.state, [this.error]);
  final String id;
  final TryOnState state;
  final String? error;
}

abstract class TryOnRepository {
  /// `personPhoto` is optional: without it the worker uses the saved avatar photo.
  Future<TryOnJob> start(List<String> garmentIds, Uint8List? personPhoto);
  Future<TryOnJob> status(String id);
  Future<Uint8List> image(String id);
  void close();
}
