import '../../shared/network/api_client.dart';

enum ProfileSection {
  identity(''),
  measurements('/measurements'),
  preferences('/preferences');

  const ProfileSection(this.path);
  final String path;
}

class DioProfileRepository {
  const DioProfileRepository(this.client, this.accessToken);

  final ApiClient client;
  final Future<String> Function() accessToken;

  String _path(String userId) =>
      '/api/v1/profiles/${Uri.encodeComponent(userId)}';

  Future<Map<String, dynamic>> load(String userId) async =>
      client.request(_path(userId), method: 'GET', bearer: await accessToken());

  Future<Map<String, dynamic>> save(
    String userId,
    ProfileSection section,
    Map<String, dynamic> data,
  ) async => client.request(
    '${_path(userId)}${section.path}',
    method: 'PUT',
    data: data,
    bearer: await accessToken(),
  );
}
