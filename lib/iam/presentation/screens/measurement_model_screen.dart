import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../shared/config/app_environment.dart';
import '../../../shared/widgets/mirage_components.dart';

// Ranges supported by IAM's generic body generator.
const measurementModelLimits = {
  'height': (130, 220),
  'shoulderWidth': (25, 65),
  'chest': (50, 180),
  'waist': (45, 180),
  'hip': (55, 190),
};

class MeasurementModelScreen extends StatefulWidget {
  const MeasurementModelScreen({super.key, required this.measurements});

  final Map<String, double> measurements;

  @override
  State<MeasurementModelScreen> createState() => _MeasurementModelScreenState();
}

class _MeasurementModelScreenState extends State<MeasurementModelScreen> {
  final _client = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  final _cancel = CancelToken();
  String? _jobPath;
  String? _model;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  String? _origin() {
    const configured = String.fromEnvironment('MEASUREMENT_MODEL_BASE_URL');
    if (configured.isEmpty) {
      if (kReleaseMode) return null;
      return Uri.parse(
        AppEnvironment.local().apiBaseUrl,
      ).replace(port: 8091, path: '').origin;
    }
    final uri = Uri.tryParse(configured);
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        !(uri.scheme == 'https' || (!kReleaseMode && uri.scheme == 'http'))) {
      return null;
    }
    return uri.origin;
  }

  Future<void> _generate() async {
    setState(() => _error = null);
    try {
      final origin = _origin();
      if (origin == null) {
        throw const FormatException('Configura el servicio IAM de modelos 3D.');
      }
      if (_jobPath == null) {
        final created = await _client.post<Map<String, dynamic>>(
          '$origin/api/jobs',
          data: widget.measurements,
          cancelToken: _cancel,
        );
        final id = created.data?['id'];
        if (id is! String || !RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(id)) {
          throw const FormatException('IAM no devolvió un trabajo válido.');
        }
        _jobPath = '$origin/api/jobs/$id';
      }
      final job = _jobPath!;
      final elapsed = Stopwatch()..start();
      while (mounted && elapsed.elapsed < const Duration(minutes: 2)) {
        final result = await _client.get<Map<String, dynamic>>(
          job,
          cancelToken: _cancel,
        );
        switch (result.data?['status']) {
          case 'succeeded':
            final response = await _client.get<List<int>>(
              '$job/model.glb',
              options: Options(responseType: ResponseType.bytes),
              cancelToken: _cancel,
            );
            final bytes = response.data;
            if (bytes == null ||
                bytes.length < 12 ||
                !listEquals(bytes.take(4).toList(), const [103, 108, 84, 70])) {
              throw const FormatException(
                'IAM devolvió un archivo 3D inválido.',
              );
            }
            if (mounted) {
              setState(
                () => _model = Uri.dataFromBytes(
                  bytes,
                  mimeType: 'model/gltf-binary',
                ).toString(),
              );
            }
            return;
          case 'failed':
            _jobPath = null;
            throw const FormatException('IAM no pudo generar el modelo 3D.');
          case 'pending':
          case 'running':
            await Future<void>.delayed(const Duration(seconds: 1));
          default:
            throw const FormatException('IAM devolvió un estado desconocido.');
        }
      }
      if (mounted) {
        throw const FormatException(
          'El modelo sigue en proceso. Pulsa Reintentar para consultar su estado.',
        );
      }
    } on DioException catch (error) {
      if (!mounted) return;
      if (error.response?.statusCode == 404) _jobPath = null;
      final message = switch (error.response?.statusCode) {
        422 => 'IAM no admite esas medidas. Revisa los valores del perfil.',
        429 => 'El generador está ocupado. Inténtalo de nuevo en un momento.',
        404 => 'El trabajo ya no está disponible. Pulsa Reintentar.',
        _ =>
          'No se pudo conectar con el generador 3D de IAM. Comprueba que esté activo.',
      };
      setState(() => _error = message);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  void dispose() {
    _cancel.cancel();
    _client.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Modelo 3D')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _model != null
            ? Column(
                children: [
                  Expanded(
                    child: ModelViewer(
                      src: _model!,
                      alt: 'Modelo corporal 3D generado con tus medidas',
                      cameraControls: true,
                    ),
                  ),
                  const Text('Arrastra para girar y pellizca para ampliar.'),
                ],
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error case final error?) ...[
                      MirageNotice(error, error: true),
                      const SizedBox(height: 12),
                      MirageButton(label: 'Reintentar', onPressed: _generate),
                    ] else ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text('Generando modelo 3D con tus medidas…'),
                    ],
                  ],
                ),
              ),
      ),
    ),
  );
}
