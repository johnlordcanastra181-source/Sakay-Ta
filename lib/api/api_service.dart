import 'api_client.dart';
import 'api_endpoints.dart';

class ApiService {
  ApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    return _client.postJson(
      ApiEndpoints.login,
      body: {
        'email': email,
        'password': password,
      },
    );
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return _client.postJson(
      ApiEndpoints.register,
      body: {
        'name': name,
        'email': email,
        'password': password,
      },
    );
  }

  Future<Map<String, dynamic>> fetchTrips() async {
    return _client.getJson(ApiEndpoints.trips);
  }

  Future<Map<String, dynamic>> fetchHealth() async {
    return _client.getJson(ApiEndpoints.health);
  }
}
