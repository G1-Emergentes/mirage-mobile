import 'application/closet_controller.dart';
import 'application/outfit_tray.dart';
import 'application/try_on_controller.dart';
import 'domain/closet_repository.dart';
import 'infrastructure/dio_closet_repository.dart';
import 'infrastructure/dio_try_on_repository.dart';
import 'infrastructure/accessory_model_api.dart';

/// Composition root of the closet: the three controllers its screens share.
class ClosetModule {
  ClosetModule({
    required Future<String> Function() accessToken,
    ClosetRepository? closetRepository,
    TryOnRepository? tryOnRepository,
  }) : closet = ClosetController(
         closetRepository ?? DioClosetRepository(accessToken: accessToken),
       ),
       tryOn = TryOnController(
         tryOnRepository ?? DioTryOnRepository(accessToken: accessToken),
       ),
       tray = OutfitTray(),
       accessoryModels = AccessoryModelApi(accessToken: accessToken);
  final ClosetController closet;
  final TryOnController tryOn;
  final OutfitTray tray;
  final AccessoryModelApi accessoryModels;

  void dispose() {
    closet.dispose();
    tryOn.dispose();
    tray.dispose();
    accessoryModels.close();
  }
}
