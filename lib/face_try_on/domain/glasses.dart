/// Where a glasses model sits on the face.
///
/// The GLB contract of virtual-try-on-service already puts the origin on the nose
/// bridge (front plane, metres, 14 cm wide). This is the per-model nudge on top of it,
/// relative to MediaPipe landmark 168: metres along the face's own axes
/// (x right, y up, z out of the face), a uniform scale and a tilt.
class GlassesFit {
  const GlassesFit({
    this.offsetX = 0,
    this.offsetY = 0.003,
    this.offsetZ = 0.006,
    this.scale = 1,
    this.pitchDeg = 0,
  });

  /// Reads the service's `ar_fit`; anything missing or invalid keeps the default.
  factory GlassesFit.fromJson(Map<String, dynamic>? json) {
    const defaults = GlassesFit();
    if (json == null) return defaults;
    double? number(Object? value) =>
        value is num && value.isFinite ? value.toDouble() : null;
    final offset = json['offset_m'];
    final values = offset is List && offset.length == 3
        ? offset.map(number).toList()
        : const <double?>[null, null, null];
    final scale = number(json['scale']);
    return GlassesFit(
      offsetX: values[0] ?? defaults.offsetX,
      offsetY: values[1] ?? defaults.offsetY,
      offsetZ: values[2] ?? defaults.offsetZ,
      scale: scale != null && scale > 0.5 && scale < 2 ? scale : defaults.scale,
      pitchDeg: number(json['pitch_deg']) ?? defaults.pitchDeg,
    );
  }

  final double offsetX, offsetY, offsetZ, scale, pitchDeg;

  GlassesFit copyWith({
    double? offsetX,
    double? offsetY,
    double? offsetZ,
    double? scale,
    double? pitchDeg,
  }) => GlassesFit(
    offsetX: offsetX ?? this.offsetX,
    offsetY: offsetY ?? this.offsetY,
    offsetZ: offsetZ ?? this.offsetZ,
    scale: scale ?? this.scale,
    pitchDeg: pitchDeg ?? this.pitchDeg,
  );

  Map<String, Object> toJson() => {
    'anchor': 'nose_bridge',
    'offset_m': [offsetX, offsetY, offsetZ],
    'scale': scale,
    'pitch_deg': pitchDeg,
  };

  @override
  bool operator ==(Object other) =>
      other is GlassesFit &&
      other.offsetX == offsetX &&
      other.offsetY == offsetY &&
      other.offsetZ == offsetZ &&
      other.scale == scale &&
      other.pitchDeg == pitchDeg;

  @override
  int get hashCode => Object.hash(offsetX, offsetY, offsetZ, scale, pitchDeg);
}

/// A pair of glasses the user can try on.
///
/// Either one of the bundled test models ([sampleAsset]) or an accessory of the user's
/// closet whose 3D model is AR-ready ([garmentId]).
class GlassesOption {
  const GlassesOption.sample({
    required this.id,
    required this.name,
    required String asset,
    this.fit = const GlassesFit(),
  }) : sampleAsset = asset,
       garmentId = null;

  const GlassesOption.garment({
    required String this.garmentId,
    required this.name,
    this.fit = const GlassesFit(),
  }) : id = garmentId,
       sampleAsset = null;

  final String id, name;
  final String? sampleAsset, garmentId;
  final GlassesFit fit;

  bool get isSample => sampleAsset != null;

  GlassesOption withFit(GlassesFit fit) => isSample
      ? GlassesOption.sample(id: id, name: name, asset: sampleAsset!, fit: fit)
      : GlassesOption.garment(garmentId: garmentId!, name: name, fit: fit);
}
