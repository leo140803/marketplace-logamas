// services/chat_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/model/chat.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Enhanced ChatService with better debugging
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  IO.Socket? _socket;
  String? _userId;
  String? _userType;

  // Stream controllers untuk real-time events
  final _messageController = StreamController<Message>.broadcast();
  final _conversationUpdateController = StreamController<Message>.broadcast();
  Stream<Message> get conversationUpdateStream =>
      _conversationUpdateController.stream;

  // Getters untuk streams
  Stream<Message> get messageStream => _messageController.stream;

  bool get isConnected => _socket?.connected ?? false;

  void initialize({
    required String userId,
    required String userType,
  }) {
    print(
        '🚀 Initializing ChatService with userId: $userId, userType: $userType');
    _userId = userId;
    _userType = userType;
    _connectSocket();
  }

  void _connectSocket() {
    _socket = IO.io('${dotenv.env['API_URL_2']}/chat', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'query': {
        'userId': _userId,
        'userType': _userType,
      },
    });

    _socket!.connect();

    // Enhanced event listeners with debugging
    _socket!.on('connect', (_) {
      print('✅ Connected to chat server');
      print('Socket ID: ${_socket?.id}');
      print('User ID: $_userId, Type: $_userType');
    });

    _socket!.on('disconnect', (_) {
      print('❌ Disconnected from chat server');
    });

    // ✅ CRITICAL: Listen for new_message (this should update UI)
    _socket!.on('new_message', (data) {
      print('📩 RECEIVED NEW MESSAGE (should update UI): $data');
      try {
        if (data['sender_type'] != 'user') {
          final message = Message.fromJson(data);
          print('📩 Parsed message successfully: $message');
          _messageController.add(message);
          print('📩 Added to message stream');
        }
      } catch (e) {
        print('❌ Error parsing new message: $e');
        print('❌ Raw message data: $data');
      }
    });

    // ✅ Listen for join confirmation
    _socket!.on('joined_chat', (data) {
      print('✅ SUCCESSFULLY JOINED CHAT ROOM: $data');
    });

    _socket!.on('conversation_updated', (_) {
      print('🔄 Conversation updated');
    });

    _socket!.on('error', (data) {
      print('❌ Socket error: $data');
    });
  }

  // ✅ Enhanced joinChat with debugging
  void joinChat(String userId, String storeId) {
    print('🚪 ATTEMPTING TO JOIN CHAT:');
    print('   - userId: $userId');
    print('   - storeId: $storeId');
    print('   - Socket connected: $isConnected');
    print('   - Current socket user: $_userId');

    if (!isConnected) {
      print('❌ Socket not connected, retrying in 1 second...');
      Future.delayed(Duration(seconds: 3), () {
        if (isConnected) {
          joinChat(userId, storeId);
        } else {
          print('❌ Socket still not connected after retry');
        }
      });
      return;
    }

    // Generate expected room name for debugging
    final expectedRoom = 'chat_${userId}_${storeId}';
    print('🚪 Expected room name: $expectedRoom');

    _socket?.emit('join_chat', {
      'userId': userId,
      'storeId': storeId,
    });

    print('🚪 Emitted join_chat event');
  }

  void leaveChat(String userId, String storeId) {
    print('👋 LEAVING CHAT: userId=$userId, storeId=$storeId');
    _socket?.emit('leave_chat', {
      'userId': userId,
      'storeId': storeId,
    });
  }

  // ... rest of your existing methods remain the same

  Future<List<Conversation>> getUserConversations(String userId) async {
    try {
      String token = await getAccessToken();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/chat/conversations/user/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('Conversations API Response Status: ${response.statusCode}');
      print('Conversations API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        // Debug: print the structure
        print('API Result structure: ${result.runtimeType}');
        print('API Result data: ${result['data']}');

        if (result['data'] != null) {
          final conversationsData = result['data'] as List;
          final conversations = conversationsData
              .map((json) {
                try {
                  return Conversation.fromJson(json);
                } catch (e) {
                  print('Error parsing individual conversation: $e');
                  print('Conversation JSON: $json');
                  return null;
                }
              })
              .where((conv) => conv != null)
              .cast<Conversation>()
              .toList();

          return conversations;
        } else {
          print('No conversations data in response');
          return [];
        }
      } else {
        print('Failed to get conversations. Status: ${response.statusCode}');
        print('Error response: ${response.body}');
        throw Exception('Failed to get conversations: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting conversations: $e');
      return [];
    }
  }

  Future<List<Message>> getMessages(String userId, String storeId,
      {int page = 1}) async {
    try {
      String token = await getAccessToken();
      final response = await http.get(
        Uri.parse(
            '$apiBaseUrl/chat/conversations/$userId/$storeId/messages?page=$page'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('Messages API Response Status: ${response.statusCode}');
      print('Messages API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['data'] != null && result['data']['messages'] != null) {
          final messagesData = result['data']['messages'] as List;
          final messages = messagesData
              .map((json) {
                try {
                  return Message.fromJson(
                    json,
                    fallbackConversationId:
                        '${userId}_${storeId}', // Fallback conversation ID
                    fallbackSenderId: userId, // Default to current user
                  );
                } catch (e) {
                  print('Error parsing individual message: $e');
                  print('Message JSON: $json');
                  return null;
                }
              })
              .where((msg) => msg != null)
              .cast<Message>()
              .toList();

          return messages;
        } else {
          print('No messages data in response');
          return [];
        }
      } else {
        print('Failed to get messages. Status: ${response.statusCode}');
        print('Error response: ${response.body}');
        throw Exception('Failed to get messages: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting messages: $e');
      return [];
    }
  }

  Future<Message?> sendMessage({
    required String userId,
    required String storeId,
    required String senderId,
    required String senderType,
    required String content,
  }) async {
    try {
      String token = await getAccessToken();
      final response = await http.post(
        Uri.parse('$apiBaseUrl/chat/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': userId,
          'store_id': storeId,
          'sender_id': senderId,
          'sender_type': senderType,
          'content': content,
        }),
      );

      print('Send Message API Response Status: ${response.statusCode}');
      print('Send Message API Response Body: ${response.body}');

      if (response.statusCode == 201) {
        final result = jsonDecode(response.body);

        if (result['data'] != null) {
          try {
            return Message.fromJson(
              result['data'],
              fallbackConversationId: '${userId}_${storeId}',
              fallbackSenderId: senderId,
            );
          } catch (e) {
            print('Error parsing sent message: $e');
            print('Message data: ${result['data']}');
            return null;
          }
        } else {
          print('No message data in send response');
          return null;
        }
      } else {
        print('Failed to send message. Status: ${response.statusCode}');
        print('Error response: ${response.body}');
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending message: $e');
      return null;
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _messageController.close();
    _conversationUpdateController.close();
  }
}
