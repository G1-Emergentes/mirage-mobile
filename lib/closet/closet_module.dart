import 'application/accessory_models_controller.dart';
import 'application/closet_controller.dart';
import 'application/outfit_tray.dart';
import 'application/outfits_controller.dart';
import 'application/try_on_controller.dart';
import 'domain/closet_repository.dart';
import 'domain/outfit.dart';
import 'infrastructure/dio_closet_repository.dart';
import 'infrastructure/dio_outfit_repository.dart';
import 'infrastructure/dio_try_on_repository.dart';
import 'infrastructure/accessory_model_api.dart';

/// Composition root of the closet: the controllers its screens share.
class ClosetModule {
  ClosetModule({
    required Future<String> Function() accessToken,
    ClosetRepository? closetRepository,
    TryOnRepository? tryOnRepository,
    OutfitRepository? outfitRepository,
    AccessoryModelApi? accessoryModelApi,
  }) : closet = ClosetController(
         closetRepository ?? DioClosetRepository(accessToken: accessToken),
       ),
       tryOn = TryOnController(
         tryOnRepository ?? DioTryOnRepository(accessToken: accessToken),
       ),
       outfits = OutfitsController(
         outfitRepository ?? DioOutfitRepository(accessToken: accessToken),
       ),
       tray = OutfitTray(),
       accessoryModels =
           accessoryModelApi ?? AccessoryModelApi(accessToken: accessToken) {
    models3d = AccessoryModelsController(accessoryModels);
  }
  final ClosetController closet;
  final TryOnController tryOn;
  final OutfitsController outfits;
  final OutfitTray tray;

  /// Saved outfit the current try-on belongs to, so its look can be saved back to it.
  String? activeOutfitId;

  /// Client of virtual-try-on-service (generate, download, calibrate).
  final AccessoryModelApi accessoryModels;

  /// Cached 3D state of the accessories (badges, thumbnails, viewer model).
  late final AccessoryModelsController models3d;

  void dispose() {
    closet.dispose();
    tryOn.dispose();
    outfits.dispose();
    tray.dispose();
    models3d.dispose();
    accessoryModels.close();
  }
}
