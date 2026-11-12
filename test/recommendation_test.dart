import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miragemobile/app/authenticated_shell.dart';
import 'package:miragemobile/closet/closet_module.dart';
import 'package:miragemobile/closet/domain/closet_repository.dart';
import 'package:miragemobile/iam/application/iam_controller.dart';
import 'package:miragemobile/iam/domain/account.dart';
import 'package:miragemobile/recommendation/chat_controller.dart';
import 'package:miragemobile/recommendation/recommendation_repository.dart';
import 'package:miragemobile/shared/theme/mirage_theme.dart';
import 'closet_fakes.dart';
import 'support/fake_auth_repository.dart';

Json garmentJson(String id, String name, String category) => {
  'id': id,
  'name': name,
  'category': category,
  'colors': ['BLACK'],
  'styles': ['CASUAL'],
  'description': name,
  'availability': 'AVAILABLE',
  'image': {'image_id': 'photo', 'version': 1},
  'revision': 1,
};

class FakeChat implements RecommendationRepository {
  int creates = 0;
  bool fail = false, closed = false;
  Completer<void>? gate;
  final calls = <(String, String)>[];
  List<Json> saved = [];
  @override
  Future<List<Json>> conversations() async => saved.isEmpty
      ? []
      : [
          {'id': 'chat', 'title': 'Mi estilo'},
        ];
  @override
  Future<Json> conversation(String id) async => {'id': id, 'turns': saved};
  @override
  Future<String> create() async {
    creates++;
    return 'chat';
  }

  @override
  Future<Json> send(String id, String text, String messageId) async {
    calls.add((text, messageId));
    await gate?.future;
    if (fail) throw const ChatFailure('Sin conexión');
    final turn = <String, dynamic>{
      'message': text,
      'assistant_message': 'Un look oscuro con tus prendas.',
      'recommendation': {
        'garments': [
          garmentJson('top', 'Polo negro', 'TOP'),
          garmentJson('pants', 'Jean negro', 'BOTTOM'),
        ],
        'outfits': [
          {
            'garment_ids': ['top', 'pants'],
            'explanation': 'Negro sobre negro, con textura.',
          },
        ],
        'outfit_examples': [
          {
            'title': 'Monochrome',
            'source_outfit_id': '123',
            'content': 'Two-piece projection',
            'source_url': 'https://github.com/xthan/polyvore-dataset',
            'license': 'Apache-2.0',
            'attribution': 'Polyvore metadata',
          },
        ],
        'web_references': [
          {
            'title': 'FashionStylist · Male · b1',
            'content': 'Quiet luxury with knit layers',
            'source_url': 'https://github.com/recsys-benchmark/FashionStylist',
            'dataset_release': '2026-04-08',
            'license': 'CC-BY-NC-4.0',
            'license_url': 'https://creativecommons.org/licenses/by-nc/4.0/',
            'attribution': 'FashionStylist Authors (2026)',
          },
        ],
      },
    };
    saved = [...saved, turn];
    return turn;
  }

  @override
  void close() {
    closed = true;
  }
}

class PausedAuth extends FakeAuthRepository {
  final gate = Completer<Account>();
  int queries = 0;
  @override
  Future<Account> currentAccount(String token) {
    queries++;
    return gate.future;
  }
}

class AuthenticatedImages extends FakeCloset {
  AuthenticatedImages(this.accessToken);
  final Future<String> Function() accessToken;
  @override
  Future<String?> imageUrl(String id) async {
    await accessToken();
    return super.imageUrl(id);
  }
}

void main() {
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final family in {
      'Lora': ['Lora-Regular.ttf', 'Lora-Italic.ttf'],
      'Inter': ['Inter.ttf'],
    }.entries) {
      final loader = FontLoader(family.key);
      for (final file in family.value) {
        loader.addFont(rootBundle.load('assets/fonts/$file'));
      }
      await loader.load();
    }
  });
  test(
    'retry retains message ID and body; duplicate send is blocked',
    () async {
      final repo = FakeChat()..fail = true;
      final chat = ChatController(repo);
      await chat.initialize();
      await chat.send('sin blanco');
      await chat.send('otra opción');
      expect(repo.calls.length, 1);
      repo.fail = false;
      await chat.retry();
      expect(repo.calls[1], repo.calls[0]);
      expect(repo.creates, 1);
      expect(chat.turns.length, 1);
      expect(chat.pendingMessage, isNull);
      chat.dispose();
      expect(repo.closed, isTrue);
    },
  );
  test('UTF8 limit, in-flight duplicate, disposed completion', () async {
    final repo = FakeChat()..gate = Completer<void>();
    final chat = ChatController(repo);
    await chat.initialize();
    await chat.send('ñ' * 1001);
    expect(repo.creates, 0);
    final sent = chat.send('un outfit');
    await Future<void>.delayed(Duration.zero);
    await chat.send('duplicado');
    expect(repo.calls.length, 1);
    chat.dispose();
    repo.gate!.complete();
    await sent;
    expect(chat.turns, isEmpty);
  });
  test('restores latest server conversation', () async {
    final repo = FakeChat()
      ..saved = [
        {
          'message': 'Hola',
          'assistant_message': 'Hola',
          'recommendation': null,
        },
      ];
    final chat = ChatController(repo);
    await chat.initialize();
    expect(chat.conversationId, 'chat');
    expect(chat.turns.single['message'], 'Hola');
    chat.newChat();
    await chat.initialize();
    expect(chat.turns, isEmpty);
    chat.dispose();
  });

  test(
    'resume, image and chat share the same pending session validation',
    () async {
      final repo = PausedAuth();
      final iam = IamController(repo);
      await iam.signIn('mia@example.com', 'example-password');
      final resumed = iam.queryCurrentAccount();
      final chatToken = iam.avatarAccessToken();
      final imageToken = iam.avatarAccessToken();
      expect(repo.queries, 1);
      repo.gate.complete(FakeAuthRepository.user);
      expect(await resumed, isTrue);
      expect(await chatToken, 'test-access');
      expect(await imageToken, 'test-access');
      iam.dispose();
    },
  );

  for (final stale in [false, true]) {
    testWidgets('chat handoff validates current closet, stale=$stale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final iam = IamController(FakeAuthRepository());
      await iam.signIn('mia@example.com', 'example-password');
      final repository = AuthenticatedImages(iam.avatarAccessToken)
        ..serveUrls = false
        ..items = [
          piece('top', name: 'Polo negro'),
          piece('pants', name: 'Jean negro', category: 'BOTTOM'),
        ];
      final worker = FakeTryOn([TryOnState.ready]);
      final module = ClosetModule(
        accessToken: () async => 'test',
        closetRepository: repository,
        tryOnRepository: worker,
        outfitRepository: FakeOutfits(),
      );
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: mirageTheme(),
          home: ListenableBuilder(
            listenable: iam,
            builder: (context, _) => RepaintBoundary(
              key: boundary,
              child: AuthenticatedShell(
                controller: iam,
                closetModule: module,
                recommendationRepository: FakeChat(),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open-assistant')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('chat-input')),
        'Un look oscuro',
      );
      await tester.tap(find.byTooltip('Enviar mensaje'));
      await tester.pumpAndSettle();
      expect(find.text('Probar en mi clóset'), findsOneWidget);
      expect(iam.busy, isFalse);
      if (!stale) {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('output/design/assistant-mobile.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      if (stale) {
        repository.items = [piece('top')];
      }
      await tester.ensureVisible(find.text('Probar en mi clóset'));
      await tester.tap(find.text('Probar en mi clóset'));
      await tester.pumpAndSettle();
      if (stale) {
        expect(module.tray.isEmpty, isTrue);
        expect(
          find.textContaining('No pudimos preparar este look'),
          findsOneWidget,
        );
        expect(find.text('Ready to Try'), findsNothing);
      } else {
        expect(find.text('Ready to Try'), findsOneWidget);
        expect(module.tray.items.map((g) => g.id), ['top', 'pants']);
        expect(worker.startedWith, isNull); // Consent remains explicit.
        expect(find.byKey(const ValueKey('open-assistant')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('open-assistant')));
        await tester.pumpAndSettle();
        expect(find.text('Un look oscuro'), findsOneWidget);
        await tester.tap(find.text('Referencias consultadas'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Polyvore · Monochrome'), findsOneWidget);
        expect(
          find.textContaining('FashionStylist · Male · b1'),
          findsOneWidget,
        );
        expect(find.textContaining('CC-BY-NC-4.0'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Ready to Try'), findsOneWidget);
        expect(find.byKey(const ValueKey('open-assistant')), findsOneWidget);
        tester.view.physicalSize = const Size(1200, 800);
        await tester.tap(find.byKey(const ValueKey('open-assistant')));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'output/design/assistant-desktop.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      iam.dispose();
    });
  }
}
