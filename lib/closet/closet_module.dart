import 'application/closet_controller.dart';
import 'application/outfit_tray.dart';
import 'application/outfits_controller.dart';
import 'application/try_on_controller.dart';
import 'domain/closet_repository.dart';
import 'domain/outfit.dart';
import 'infrastructure/dio_closet_repository.dart';
import 'infrastructure/dio_outfit_repository.dart';
import 'infrastructure/dio_try_on_repository.dart';

/// Composition root of the closet: the controllers its screens share.
class ClosetModule {
  ClosetModule({
    required Future<String> Function() accessToken,
    ClosetRepository? closetRepository,
    TryOnRepository? tryOnRepository,
    OutfitRepository? outfitRepository,
  }) : closet = ClosetController(
         closetRepository ?? DioClosetRepository(accessToken: accessToken),
       ),
       tryOn = TryOnController(
         tryOnRepository ?? DioTryOnRepository(accessToken: accessToken),
       ),
       outfits = OutfitsController(
         outfitRepository ?? DioOutfitRepository(accessToken: accessToken),
       ),
       tray = OutfitTray();
  final ClosetController closet;
  final TryOnController tryOn;
  final OutfitsController outfits;
  final OutfitTray tray;

  void dispose() {
    closet.dispose();
    tryOn.dispose();
    outfits.dispose();
    tray.dispose();
  }
}
