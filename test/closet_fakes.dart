import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:miragemobile/closet/domain/closet_repository.dart';
import 'package:miragemobile/closet/domain/garment.dart';

/// A valid 1x1 PNG, so `Image.memory` can decode it in widget tests.
final tinyPng = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  ),
);

Garment piece(
  String id, {
  String? name,
  String category = 'TOP',
  String? subcategory,
  List<String> colors = const ['BLACK'],
  bool available = true,
  bool hasImage = true,
}) => Garment(
  id: id,
  name: name ?? 'Piece $id',
  category: category,
  subcategory: subcategory,
  colors: colors,
  description: 'A piece',
  available: available,
  hasImage: hasImage,
  revision: 1,
);

class FakeCloset implements ClosetRepository {
  List<Garment> items = [];
  int urlCalls = 0;
  bool failAttach = false;
  // Widget tests keep this off so photos stay placeholders and no network is touched.
  bool serveUrls = true;
  final removed = <String>[];
  Object? listError;
  GarmentDraft? created;
  @override
  Future<List<Garment>> list() async {
    if (listError != null) throw listError!;
    return items;
  }

  @override
  Future<Garment> create(GarmentDraft draft) async {
    created = draft;
    return Garment(
      id: 'new-1',
      name: draft.name,
      category: draft.category,
      description: draft.description,
      available: true,
      hasImage: false,
      revision: 1,
    );
  }

  @override
  Future<Garment> update(String id, GarmentDraft draft) async => Garment(
    id: id,
    name: draft.name,
    category: draft.category,
    description: draft.description,
    available: draft.available,
    hasImage: true,
    revision: 2,
  );
  @override
  Future<void> remove(String id) async => removed.add(id);
  @override
  Future<Garment> attachImage(String id, Uint8List bytes, String type) async {
    if (failAttach) throw const ClosetException('NETWORK');
    return piece(id, name: created?.name);
  }

  @override
  Future<String?> imageUrl(String id) async {
    urlCalls++;
    return serveUrls ? 'https://example.com/$id?n=$urlCalls' : null;
  }

  @override
  void close() {}
}

class FakeTryOn implements TryOnRepository {
  FakeTryOn(this.states, {this.startError, this.jobError});
  final List<TryOnState> states;
  final Object? startError;
  final String? jobError; // the code a failed job reports
  int polls = 0;
  List<String>? startedWith;
  Uint8List? photoSent;
  @override
  Future<TryOnJob> start(List<String> ids, Uint8List? photo) async {
    if (startError != null) throw startError!;
    startedWith = ids;
    photoSent = photo;
    return _job('job-1', states.first);
  }

  TryOnJob _job(String id, TryOnState state) =>
      TryOnJob(id, state, state == TryOnState.failed ? jobError : null);

  @override
  Future<TryOnJob> status(String id) async =>
      _job(id, states[(++polls).clamp(0, states.length - 1)]);
  @override
  Future<Uint8List> image(String id) async => tinyPng;
  @override
  void close() {}
}
