import 'package:flutter/material.dart';
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
      );
    }
    return Scaffold(
      body: const SizedBox.expand(key: ValueKey('home-placeholder')),
      bottomNavigationBar: navigation,
    );
  }
}
