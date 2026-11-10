import 'package:miragemobile/iam/domain/account.dart';
import 'package:miragemobile/iam/domain/google_identity.dart';

class FakeGoogleIdentity implements GoogleIdentity {
  @override
  bool supported = true;
  String? token = 'fake-google-id-token';
  AuthFailure? failure;
  @override
  Future<String?> authenticateIdToken() async {
    if (failure != null) throw failure!;
    return token;
  }
}
