import 'dart:typed_data';

/// Full-body photo the user chose when no saved avatar could be opened.
///
/// Outfit previews send it with the request (`person_photo`) instead of the saved avatar
/// photo. It lives only in memory while the app is open: nothing is stored on a server and
/// the user must pick it again after restarting the app.
class PersonPhoto {
  PersonPhoto._();
  static Uint8List? bytes;
}
