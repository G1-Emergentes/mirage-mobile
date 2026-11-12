import 'package:dio/dio.dart';
import '../closet/infrastructure/dio_closet_repository.dart';

typedef Json = Map<String, dynamic>;

class ChatFailure implements Exception {
  const ChatFailure(this.message);
  final String message;
}

abstract interface class RecommendationRepository {
  Future<List<Json>> conversations();
  Future<Json> conversation(String id);
  Future<String> create();
  Future<Json> send(String conversationId, String message, String messageId);
  void close();
}

class HttpRecommendationRepository implements RecommendationRepository {
  HttpRecommendationRepository({
    required this.accessToken,
    Dio? dio,
    String? baseUrl,
  }) : _dio = dio ?? Dio() {
    final url =
        baseUrl ??
        serviceUrl(
          const String.fromEnvironment('RECOMMENDATION_BASE_URL'),
          8085,
        );
    final uri = Uri.parse(url);
    if (!uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.hasQuery ||
        uri.hasFragment ||
        (const bool.fromEnvironment('dart.vm.product') &&
            uri.scheme != 'https')) {
      throw ArgumentError('Use a valid HTTPS Recommendation URL in release.');
    }
    _dio.options = BaseOptions(
      baseUrl: url,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 180),
    );
  }
  final Dio _dio;
  final Future<String> Function() accessToken;

  Future<Json> _request(String path, {Json? body}) async {
    try {
      final token = await accessToken();
      final result = await _dio.request<Json>(
        path,
        data: body,
        options: Options(
          method: body == null ? 'GET' : 'POST',
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return result.data!;
    } on DioException catch (e) {
      final data = e.response?.data;
      final error = data is Map ? data['error'] : null;
      final code = error is Map ? error['code'] : null;
      throw ChatFailure(switch (code) {
        'CONVERSATION_FULL' =>
          'Este chat llegó a 20 mensajes. Abre uno nuevo para continuar.',
        'WARDROBE_CHANGED' =>
          'Tu clóset cambió durante la respuesta. Reintenta para actualizarla.',
        'UNAUTHENTICATED' => 'Tu sesión terminó. Inicia sesión de nuevo.',
        _ when e.response?.statusCode == 401 =>
          'Tu sesión terminó. Inicia sesión de nuevo.',
        _ when e.response?.statusCode == 409 =>
          'El chat cambió en otra ventana. Vuelve a abrirlo para actualizarlo.',
        _ =>
          'No pudimos obtener la respuesta. Comprueba los servicios y reintenta; tu envío conserva su identificador.',
      });
    } on ChatFailure {
      rethrow;
    } catch (_) {
      throw const ChatFailure(
        'No pudimos acceder al asistente. Comprueba tu sesión y vuelve a intentarlo.',
      );
    }
  }

  @override
  Future<List<Json>> conversations() async => List<Json>.from(
    (await _request('/conversations?limit=20'))['items'] as List,
  );
  @override
  Future<Json> conversation(String id) =>
      _request('/conversations/${Uri.encodeComponent(id)}');
  @override
  Future<String> create() async =>
      (await _request(
            '/conversations',
            body: {'title': 'Mi estilo con Mirage'},
          ))['id']
          as String;
  @override
  Future<Json> send(String conversationId, String message, String messageId) =>
      _request(
        '/conversations/${Uri.encodeComponent(conversationId)}/messages',
        body: {'message': message, 'client_message_id': messageId},
      );
  @override
  void close() => _dio.close(force: true);
}
