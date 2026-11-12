import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:miragemobile/recommendation/recommendation_repository.dart';

// Opt-in only: uses the existing private local session, never commits its values.
void main() {
  test(
    'Flutter repository -> real IAM, Closet, NVIDIA and production Neon',
    () async {
      final env =
          jsonDecode(
                await File(
                  '../recommendation-service/out/postman/Mirage-Local.private.postman_environment.json',
                ).readAsString(),
              )
              as Map;
      final token =
          (env['values'] as List).firstWhere(
                (v) => v['key'] == 'access_token',
              )['value']
              as String;
      final repo = HttpRecommendationRepository(
        accessToken: () async => token,
        baseUrl: 'http://127.0.0.1:8085/api/v1',
      );
      try {
        final id = await repo.create();
        final turn = await repo.send(
          id,
          'Proponme un outfit casual oscuro sin blanco usando mi clóset.',
          'f7169fc0-f99e-45e7-91bf-${DateTime.now().microsecondsSinceEpoch.toRadixString(16).padLeft(12, '0').substring(0, 12)}',
        );
        expect(turn['assistant_message'], isNotEmpty);
        final recommendation = turn['recommendation'] as Map;
        final garments = {
          for (final g in recommendation['garments'] as List) g['id']: g,
        };
        expect(recommendation['outfits'], isNotEmpty);
        for (final outfit in recommendation['outfits'] as List) {
          for (final id in outfit['garment_ids'] as List) {
            expect(garments.containsKey(id), isTrue);
            expect(garments[id]['colors'], isNot(contains('WHITE')));
          }
        }
        expect(recommendation['outfit_examples'], isNotEmpty);
        expect((await repo.conversation(id))['turns'], hasLength(1));
        expect((await repo.conversations()).any((c) => c['id'] == id), isTrue);
      } finally {
        repo.close();
      }
    },
    skip: Platform.environment['MIRAGE_LIVE'] != '1',
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
