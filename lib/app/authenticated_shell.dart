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
import '../recommendation/chat_controller.dart';
import '../recommendation/chat_panel.dart';
import '../recommendation/recommendation_repository.dart';
import '../shared/theme/mirage_theme.dart';
import '../iam/application/iam_controller.dart';
import '../iam/presentation/screens/account_screen.dart';
import '../outfit/presentation/screens/outfit_screen.dart';
import '../outfit/presentation/screens/recommendations_screen.dart';
import '../shared/widgets/mirage_bottom_navigation.dart';

class AuthenticatedShell extends StatefulWidget {
  const AuthenticatedShell({
    super.key,
    required this.controller,
    this.closetModule,
    this.recommendationRepository,
  });
  final IamController controller;
  final ClosetModule? closetModule;
  final RecommendationRepository? recommendationRepository;
  @override
  State<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<AuthenticatedShell> {
  final selected = ValueNotifier(0);
  final navigator = GlobalKey<NavigatorState>();
  ChatController? _chat;
  bool chatOpen = false;

  void _closeChat() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => chatOpen = false);
  }

  // Created on first use and kept while the user is signed in, so the closet, the outfit
  // being built and its photo links survive switching tabs.
  ClosetModule? _closet;
  ClosetModule get closet => _closet ??=
      widget.closetModule ??
      ClosetModule(accessToken: widget.controller.avatarAccessToken);

  @override
  void dispose() {
    _chat?.dispose();
    selected.dispose();
    _closet?.dispose();
    super.dispose();
  }

  // Screens open inside the shell's own Navigator, so the stylist chat stays on top.
  void _open(Widget screen) => navigator.currentState?.push<void>(
    MaterialPageRoute(builder: (_) => screen),
  );

  void _openCategory(ClosetGroup group) {
    if (!closet.closet.loaded) unawaited(closet.closet.load());
    _open(CategoryScreen(module: closet, group: group));
  }

  void _openChat() {
    _chat ??= ChatController(
      widget.recommendationRepository ??
          HttpRecommendationRepository(
            accessToken: widget.controller.avatarAccessToken,
          ),
    );
    setState(() => chatOpen = true);
    _chat!.initialize();
  }

  // Every tab has its screen (Home, Closet, Outfit, Explore, Profile): switching tabs
  // returns to the tab's root.
  void _select(int index) {
    selected.value = index;
    navigator.currentState?.popUntil((route) => route.isFirst);
  }

  Future<void> _tryOutfit(List<Garment> proposed) async {
    // History is a snapshot. Re-read the user's authenticated Closet before staging.
    final current = {
      for (final g in await closet.closet.repository.list()) g.id: g,
    };
    if (!mounted) return;
    final pieces = <Garment>[];
    for (final old in proposed) {
      final g = current[old.id];
      if (g == null ||
          g.revision != old.revision ||
          !g.available ||
          !g.hasImage) {
        throw const ChatFailure('The recommendation is no longer current.');
      }
      pieces.add(g);
    }
    if (pieces.isEmpty ||
        pieces.length > 3 ||
        pieces.map((g) => g.id).toSet().length != pieces.length) {
      throw const ChatFailure('Invalid outfit.');
    }
    final oldIds = closet.tray.items.map((g) => g.id).toSet();
    if (oldIds.isNotEmpty &&
        (oldIds.length != pieces.length ||
            pieces.any((g) => !oldIds.contains(g.id)))) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Usar esta combinación?'),
          content: const Text(
            'Reemplazará las prendas de tu look actual. Tu imagen todavía no se generará.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Conservar mi look'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Usar combinación'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    if (!closet.tray.replace(pieces)) {
      throw const ChatFailure('Invalid outfit.');
    }
    closet.activeOutfitId = null;
    _closeChat();
    _select(1);
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => ReadyToTryScreen(module: closet)),
    );
  }

  Widget _page() => ValueListenableBuilder<int>(
    valueListenable: selected,
    builder: (context, index, _) {
      final navigation = MirageBottomNavigation(
        selectedIndex: index,
        onSelected: _select,
      );
      return switch (index) {
        1 => ClosetScreen(module: closet, bottomNavigationBar: navigation),
        2 => ListenableBuilder(
          listenable: closet.tray,
          builder: (context, _) => OutfitScreen(
            navigation: navigation,
            pieces: closet.tray.items,
            closet: closet.closet,
            onSelect: _openCategory,
            onReset: closet.tray.clear,
            onHome: () => _select(0),
            onAdd: () => _select(1),
            onTryOn: () => _open(ReadyToTryScreen(module: closet)),
          ),
        ),
        3 => ExploreScreen(navigation: navigation, onHome: () => _select(0)),
        4 => AccountScreen(
          controller: widget.controller,
          bottomNavigationBar: navigation,
          onContinueHome: () => _select(0),
          onOpenCloset: () => _select(1),
        ),
        _ => ListenableBuilder(
          listenable: closet.closet,
          builder: (context, _) => HomeScreen(
            navigation: navigation,
            closet: closet.closet,
            displayName: widget.controller.account?.displayName,
            onCloset: () => _select(1),
            onCategory: _openCategory,
            onExplore: () => _select(3),
            onRecommendations: () => _open(const RecommendationsScreen()),
            onTryOnGlasses: () => _open(GlassesTryOnScreen.forCloset(closet)),
          ),
        ),
      };
    },
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !chatOpen,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && chatOpen) _closeChat();
    },
    child: Stack(
      children: [
        // All authenticated routes stay below the assistant and disappear on logout.
        NavigatorPopHandler(
          enabled: !chatOpen,
          onPopWithResult: chatOpen
              ? null
              : (_) => navigator.currentState?.maybePop(),
          child: Navigator(
            key: navigator,
            onGenerateRoute: (_) =>
                MaterialPageRoute<void>(builder: (_) => _page()),
          ),
        ),
        if (chatOpen)
          Positioned.fill(
            child: ModalBarrier(color: Colors.black12, onDismiss: _closeChat),
          ),
        if (!chatOpen)
          Positioned(
            right: 20,
            bottom: 108 + MediaQuery.paddingOf(context).bottom,
            child: FloatingActionButton(
              key: const ValueKey('open-assistant'),
              heroTag: 'mirage-assistant',
              onPressed: _openChat,
              tooltip: 'Hablar con mi estilista',
              backgroundColor: MirageColors.pink,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              child: const Icon(Icons.auto_awesome_outlined),
            ),
          ),
        if (_chat != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            right: 12,
            bottom:
                MediaQuery.viewInsetsOf(context).bottom +
                MediaQuery.paddingOf(context).bottom +
                16,
            width: (MediaQuery.sizeOf(context).width - 24).clamp(0, 420),
            child: Offstage(
              offstage: !chatOpen,
              child: Align(
                alignment: Alignment.bottomRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 700),
                  child: ChatPanel(
                    controller: _chat!,
                    closet: closet,
                    onClose: _closeChat,
                    onCloset: () {
                      _closeChat();
                      _select(1);
                    },
                    onTryOutfit: _tryOutfit,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
