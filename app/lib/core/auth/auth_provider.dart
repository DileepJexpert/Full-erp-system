import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';
import 'token_storage.dart';
import '../api/api_client.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class UserInfo {
  final String id;
  final String name;
  final String phone;
  final String role;
  final String businessId;
  final String businessName;
  final String businessType;

  const UserInfo({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.businessId,
    required this.businessName,
    required this.businessType,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      businessId: json['businessId'] ?? '',
      businessName: json['businessName'] ?? '',
      businessType: json['businessType'] ?? '',
    );
  }

  bool get isOwner => role == 'OWNER';
  bool get isManager => role == 'MANAGER';
  bool get isStaff => role == 'STAFF';
  bool get isOwnerOrManager => isOwner || isManager;
}

class AuthState {
  final AuthStatus status;
  final UserInfo? user;
  final String? token;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.token,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, UserInfo? user, String? token, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      token: token ?? this.token,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState());

  String get currentToken => state.token ?? '';

  Future<void> checkAuth() async {
    state = state.copyWith(status: AuthStatus.loading);
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final userData = await _authService.getMe();
      final user = UserInfo(
        id: userData['id'] ?? '',
        name: userData['name'] ?? '',
        phone: userData['phone'] ?? '',
        role: userData['role'] ?? '',
        businessId: userData['businessId'] ?? '',
        businessName: userData['business']?['name'] ?? '',
        businessType: userData['business']?['type'] ?? '',
      );
      state = AuthState(status: AuthStatus.authenticated, user: user, token: token);
    } catch (_) {
      await TokenStorage.deleteToken();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> sendOtp(String phone) async {
    await _authService.sendOtp(phone);
  }

  Future<void> verifyOtp(String phone, String otp) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final result = await _authService.verifyOtp(phone, otp);
      final token = result['token'] as String;
      await TokenStorage.saveToken(token);
      final userJson = result['user'] as Map<String, dynamic>;
      final user = UserInfo.fromJson(userJson);
      state = AuthState(status: AuthStatus.authenticated, user: user, token: token);
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString());
    }
  }

  Future<void> logout() async {
    await TokenStorage.deleteToken();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

// Providers
final apiClientProvider = Provider<ApiClient>((ref) {
  final authNotifier = ref.read(authProvider.notifier);
  return ApiClient(getToken: () => authNotifier.currentToken);
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(apiClientProvider));
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});
