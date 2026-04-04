import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';

final userProvider = Provider<UserInfo?>((ref) {
  return ref.watch(authProvider).user;
});

final isOwnerProvider = Provider<bool>((ref) {
  return ref.watch(userProvider)?.isOwner ?? false;
});

final isOwnerOrManagerProvider = Provider<bool>((ref) {
  return ref.watch(userProvider)?.isOwnerOrManager ?? false;
});
