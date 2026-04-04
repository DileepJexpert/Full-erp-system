import '../api/api_client.dart';

class AuthService {
  final ApiClient _api;
  AuthService(this._api);

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final response = await _api.post('/auth/send-otp', data: {'phone': phone});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp, {String? businessId}) async {
    final response = await _api.post('/auth/verify-otp', data: {
      'phone': phone,
      'otp': otp,
      if (businessId != null) 'businessId': businessId,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register({
    required String businessName,
    required String businessType,
    required String ownerName,
    required String phone,
    String? email,
  }) async {
    final response = await _api.post('/auth/register', data: {
      'businessName': businessName,
      'businessType': businessType,
      'ownerName': ownerName,
      'phone': phone,
      if (email != null) 'email': email,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _api.get('/auth/me');
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getUsers() async {
    final response = await _api.get('/auth/users');
    return response.data as List<dynamic>;
  }
}
