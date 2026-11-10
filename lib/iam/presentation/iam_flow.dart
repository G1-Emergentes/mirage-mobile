import 'package:flutter/material.dart';
import '../application/iam_controller.dart';
import 'screens/access_screen.dart';
import '../../app/authenticated_shell.dart';
import 'screens/onboarding_screen.dart';
import '../../shared/widgets/mirage_components.dart';

class IamFlow extends StatefulWidget {
  const IamFlow({super.key, required this.controller});
  final IamController controller;
  @override
  State<IamFlow> createState() => _IamFlowState();
}

class _IamFlowState extends State<IamFlow> with WidgetsBindingObserver {
  int _introduction = 0;
  AccessMode _mode = AccessMode.signIn;
  String _email = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.controller.signedIn &&
        !widget.controller.busy) {
      widget.controller.queryCurrentAccount();
    }
  }

  void _navigate(AccessMode mode, String email) {
    widget.controller.clearError();
    setState(() {
      _mode = mode;
      _email = email;
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      if (widget.controller.restoring) {
        return const MirageScreen(
          child: Column(
            children: [
              MirageHeader(),
              SizedBox(height: 60),
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text('Restoring your session…'),
            ],
          ),
        );
      }
      if (widget.controller.hasSavedSignIn) _introduction = 2;
      if (widget.controller.signedIn) {
        _introduction = 2;
        _mode = AccessMode.signIn;
        _email = widget.controller.account!.email;
        return AuthenticatedShell(
          key: ValueKey(widget.controller.account!.id),
          controller: widget.controller,
        );
      }
      if (_introduction == 0) {
        return SplashScreen(
          onComplete: () {
            if (mounted) setState(() => _introduction = 1);
          },
        );
      }
      if (_introduction == 1) {
        return OnboardingScreen(
          onComplete: () => setState(() => _introduction = 2),
        );
      }
      return AccessScreen(
        key: ValueKey(_mode),
        mode: _mode,
        controller: widget.controller,
        initialEmail: _email,
        onNavigate: _navigate,
      );
    },
  );
}
