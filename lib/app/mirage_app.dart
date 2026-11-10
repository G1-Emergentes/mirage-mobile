import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../iam/application/iam_controller.dart';
import '../iam/infrastructure/dio_auth_repository.dart';
import '../iam/infrastructure/device_session_store.dart';
import '../iam/infrastructure/native_google_identity.dart';
import '../iam/presentation/iam_flow.dart';
import '../shared/config/app_environment.dart';
import '../shared/network/api_client.dart';
import '../shared/theme/mirage_theme.dart';

class MirageApp extends StatefulWidget {
  const MirageApp({super.key, this.controller});
  final IamController? controller;
  @override
  State<MirageApp> createState() => _MirageAppState();
}

class _MirageAppState extends State<MirageApp> {
  ApiClient? _client;
  late final IamController _controller;
  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _client = ApiClient(AppEnvironment.local().apiBaseUrl);
      _controller = IamController(
        DioAuthRepository(_client!),
        sessionStore: DeviceSessionStore(),
        googleIdentity: NativeGoogleIdentity(),
      );
      _controller.restoreSession();
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: MirageColors.paper,
    ),
    child: MaterialApp(
      title: 'Mirage',
      debugShowCheckedModeBanner: false,
      theme: mirageTheme(),
      home: IamFlow(controller: _controller),
    ),
  );
}
