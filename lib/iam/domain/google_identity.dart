abstract interface class GoogleIdentity {
  bool get supported;

  /// Null means the user closed the account picker.
  Future<String?> authenticateIdToken();
}
