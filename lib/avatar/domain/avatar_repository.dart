import 'dart:typed_data';

class AvatarInput {
  AvatarInput({
    required this.photo,
    required this.height,
    required this.weight,
  }) {
    if (photo.isEmpty ||
        photo.length > 8 * 1024 * 1024 ||
        !height.isFinite ||
        height < 130 ||
        height > 220 ||
        !weight.isFinite ||
        weight < 30 ||
        weight > 250) {
      throw ArgumentError(
        'Use a photo up to 8 MB, height 130–220 cm and weight 30–250 kg.',
      );
    }
  }
  final Uint8List photo;
  final double height, weight;
}

abstract class AvatarRepository {
  Future<Map<String, dynamic>> body(String id);
  Future<String?> openSaved();
  Future<String> adjust(
    String id,
    Map<String, double?> measurements,
    String fit,
  );
  Future<void> save(String id, Map<String, double?> measurements, String fit);
  Future<String> submit(AvatarInput input);
  Future<String> status(String id);
  Uri viewer(String id);
  Future<void> discard(String id);
  void close();
}
