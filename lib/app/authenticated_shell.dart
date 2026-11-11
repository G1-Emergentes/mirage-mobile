import 'package:flutter/material.dart';
import '../closet/closet_module.dart';
import '../closet/presentation/closet_screen.dart';
import '../iam/application/iam_controller.dart';
import '../iam/presentation/screens/account_screen.dart';
import '../shared/widgets/mirage_bottom_navigation.dart';

class AuthenticatedShell extends StatefulWidget {
  const AuthenticatedShell({super.key, required this.controller});
  final IamController controller;
  @override
  State<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<AuthenticatedShell> {
  int selected = 0;
  // Created on first use and kept while the user is signed in, so the closet, the outfit
  // being built and its photo links survive switching tabs.
  ClosetModule? _closet;
  ClosetModule get closet => _closet ??= ClosetModule(
    accessToken: widget.controller.avatarAccessToken,
  );

  @override
  void dispose() {
    _closet?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navigation = MirageBottomNavigation(
      selectedIndex: selected,
      onSelected: (index) => setState(() => selected = index),
    );
    if (selected == 4) {
      return AccountScreen(
        controller: widget.controller,
        bottomNavigationBar: navigation,
        onContinueHome: () => setState(() => selected = 0),
        onOpenCloset: () => setState(() => selected = 1),
      );
    }
    if (selected == 1) {
      return ClosetScreen(module: closet, bottomNavigationBar: navigation);
    }
    return Scaffold(
      body: const SizedBox.expand(key: ValueKey('home-placeholder')),
      bottomNavigationBar: navigation,
    );
  }
}
