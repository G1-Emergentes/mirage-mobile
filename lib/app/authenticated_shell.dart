import 'dart:async';

import 'package:flutter/material.dart';

import '../closet/closet_module.dart';
import '../closet/domain/garment.dart';
import '../closet/presentation/category_screen.dart';
import '../closet/presentation/closet_screen.dart';
import '../closet/presentation/try_on_screens.dart';
import '../explore/presentation/screens/explore_screen.dart';
import '../face_try_on/presentation/glasses_try_on_screen.dart';
import '../home/presentation/screens/home_screen.dart';
import '../iam/application/iam_controller.dart';
import '../iam/presentation/screens/account_screen.dart';
import '../outfit/presentation/screens/outfit_screen.dart';
import '../outfit/presentation/screens/recommendations_screen.dart';
import '../shared/widgets/mirage_bottom_navigation.dart';

class AuthenticatedShell extends StatefulWidget {
  const AuthenticatedShell({
    super.key,
    required this.controller,
    this.createCloset,
  });

  final IamController controller;
  final ClosetModule Function()? createCloset;

  @override
  State<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<AuthenticatedShell> {
  int selected = 0;
  ClosetModule? _closet;
  ClosetModule get closet => _closet ??=
      widget.createCloset?.call() ??
      ClosetModule(accessToken: widget.controller.avatarAccessToken);

  @override
  void dispose() {
    _closet?.dispose();
    super.dispose();
  }

  void _navigate(int index) => setState(() => selected = index);

  void _open(Widget screen) => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => screen));

  void _openCategory(ClosetGroup group) {
    if (!closet.closet.loaded) unawaited(closet.closet.load());
    _open(CategoryScreen(module: closet, group: group));
  }

  @override
  Widget build(BuildContext context) {
    final navigation = MirageBottomNavigation(
      selectedIndex: selected,
      onSelected: _navigate,
    );
    return switch (selected) {
      1 => ClosetScreen(module: closet, bottomNavigationBar: navigation),
      2 => ListenableBuilder(
        listenable: closet.tray,
        builder: (context, _) => OutfitScreen(
          navigation: navigation,
          pieces: closet.tray.items,
          closet: closet.closet,
          onSelect: _openCategory,
          onReset: closet.tray.clear,
          onHome: () => _navigate(0),
          onAdd: () => _navigate(1),
          onTryOn: () => _open(ReadyToTryScreen(module: closet)),
        ),
      ),
      3 => ExploreScreen(navigation: navigation, onHome: () => _navigate(0)),
      4 => AccountScreen(
        controller: widget.controller,
        bottomNavigationBar: navigation,
        onContinueHome: () => _navigate(0),
        onOpenCloset: () => _navigate(1),
      ),
      _ => ListenableBuilder(
        listenable: closet.closet,
        builder: (context, _) => HomeScreen(
          navigation: navigation,
          closet: closet.closet,
          displayName: widget.controller.account?.displayName,
          onCloset: () => _navigate(1),
          onCategory: _openCategory,
          onExplore: () => _navigate(3),
          onRecommendations: () => _open(const RecommendationsScreen()),
          onTryOnGlasses: () => _open(GlassesTryOnScreen.forCloset(closet)),
        ),
      ),
    };
  }
}
