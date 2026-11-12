import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'recommendation_repository.dart';

String messageUuid() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Lives for one authenticated session. The backend owns durable chat history.
class ChatController extends ChangeNotifier {
  ChatController(this.repository);
  final RecommendationRepository repository;
  final turns = <Json>[];
  List<Json> history = [];
  String? conversationId, error, pendingMessage, _pendingId;
  bool busy = false, initialized = false, _closed = false;

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _closed) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } on ChatFailure catch (e) {
      error = e.message;
    } catch (_) {
      error = 'No se pudo abrir el chat. Vuelve a intentarlo.';
    } finally {
      busy = false;
      if (!_closed) notifyListeners();
    }
  }

  Future<void> initialize() => _run(() async {
    history = await repository.conversations();
    if (_closed) return;
    if (!initialized && history.isNotEmpty) {
      final chat = await repository.conversation(history.first['id'] as String);
      if (_closed) return;
      conversationId = chat['id'] as String;
      turns
        ..clear()
        ..addAll(List<Json>.from(chat['turns'] as List));
    }
    initialized = true;
  });

  Future<void> open(String id) => _run(() async {
    final chat = await repository.conversation(id);
    if (_closed) return;
    conversationId = id;
    pendingMessage = _pendingId = null;
    turns
      ..clear()
      ..addAll(List<Json>.from(chat['turns'] as List));
  });

  void newChat() {
    if (busy) return;
    conversationId = pendingMessage = _pendingId = error = null;
    initialized = true;
    turns.clear();
    notifyListeners();
  }

  Future<void> send(String text) async {
    if (busy || pendingMessage != null || _closed) return;
    text = text.trim();
    if (text.isEmpty) return;
    if (utf8.encode(text).length > 2000) {
      error =
          'Escribe un mensaje de hasta 2000 bytes (aprox. 1000–2000 caracteres).';
      notifyListeners();
      return;
    }
    pendingMessage = text;
    _pendingId = messageUuid();
    await retry();
  }

  Future<void> retry() => _run(() async {
    if (pendingMessage == null) return;
    conversationId ??= await repository.create();
    if (_closed) return;
    final turn = await repository.send(
      conversationId!,
      pendingMessage!,
      _pendingId!,
    );
    if (_closed) return;
    turns.add(turn);
    pendingMessage = _pendingId = null;
  });

  @override
  void dispose() {
    _closed = true;
    repository.close();
    super.dispose();
  }
}
