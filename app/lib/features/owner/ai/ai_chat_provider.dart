import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';

class ChatMessage {
  final String role; // 'user' or 'ai'
  final String content;
  final DateTime timestamp;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });
}

class AiChatNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref _ref;

  AiChatNotifier(this._ref) : super([]);

  bool _loading = false;
  bool get loading => _loading;

  Future<void> sendQuery(String text) async {
    if (text.trim().isEmpty) return;

    state = [
      ...state,
      ChatMessage(role: 'user', content: text.trim(), timestamp: DateTime.now()),
    ];

    _loading = true;
    state = [...state]; // trigger rebuild

    try {
      final api = _ref.read(apiClientProvider);
      final response = await api.post('/ai/query', data: {'query': text.trim()});
      final data = response.data as Map<String, dynamic>;
      final answer = data['answer'] ?? data['response'] ?? 'No response';

      state = [
        ...state,
        ChatMessage(role: 'ai', content: answer.toString(), timestamp: DateTime.now()),
      ];
    } catch (e) {
      state = [
        ...state,
        ChatMessage(
          role: 'ai',
          content: 'Error: ${e.toString()}',
          timestamp: DateTime.now(),
        ),
      ];
    } finally {
      _loading = false;
    }
  }
}

final aiChatProvider =
    StateNotifierProvider.autoDispose<AiChatNotifier, List<ChatMessage>>(
  (ref) => AiChatNotifier(ref),
);

final aiInsightsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/ai/insights');
  final data = response.data;
  if (data is List) return data.cast<Map<String, dynamic>>();
  if (data is Map && data['data'] != null) {
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});
